fs = require 'fs'
os = require 'os'
path = require 'path'
PathReplacer = require '../src/path-replacer'

describe "PathReplacer", ->
  [replacer, rootPath] = []

  beforeEach ->
    replacer = new PathReplacer()
    rootPath = fs.realpathSync(path.join("spec", "fixtures", "many-files"))

  describe "replacePath()", ->
    describe "when a file doesnt exist", ->
      it "returns error in the doneCallback and emits an 'error' event when the path does not exist", ->
        replacer.on('file-error', errorHandler = jasmine.createSpy())
        replacer.on('path-replaced', replacedHandler = jasmine.createSpy())
        replacer.replacePath(/nope/gi, 'replacement', '/this-does-not-exist.js', finishedHandler = jasmine.createSpy())

        waitsFor ->
          finishedHandler.callCount > 0

        runs ->
          expect(replacedHandler).not.toHaveBeenCalled()
          expect(finishedHandler).toHaveBeenCalled()
          expect(finishedHandler.mostRecentCall.args[1].code).toBe 'ENOENT'

          expect(errorHandler).toHaveBeenCalled()
          expect(errorHandler.mostRecentCall.args[0].path).toBe '/this-does-not-exist.js'
          expect(errorHandler.mostRecentCall.args[0].code).toBe 'ENOENT'

  describe "replacePaths()", ->
    [filePath, sampleContent] = []

    beforeEach ->
      filePath = path.join(rootPath, 'sample.js')
      sampleContent = fs.readFileSync(filePath).toString()

    afterEach ->
      fs.writeFileSync(filePath, sampleContent)

    it "can make a replacement", ->
      replacer.on('file-error', errorHandler = jasmine.createSpy())
      replacer.on('path-replaced', resultsHandler = jasmine.createSpy())
      replacer.replacePaths(/items/gi, 'omgwow', [filePath], finishedHandler = jasmine.createSpy())

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(errorHandler).not.toHaveBeenCalled()
        expect(resultsHandler).toHaveBeenCalled()
        expect(resultsHandler.mostRecentCall.args[0]).toEqual
          filePath: filePath
          replacements: 6

        replacedFile = fs.readFileSync(filePath).toString()

        replacedContent = '''
          var quicksort = function () {
            var sort = function(omgwow) {  # followed by a pretty long comment which is used to check the maxLineLength feature
              if (omgwow.length <= 1) return omgwow;
              var pivot = omgwow.shift(), current, left = [], right = [];
              while(omgwow.length > 0) {
                current = omgwow.shift();
                current < pivot ? left.push(current) : right.push(current);
              }
              return sort(left).concat(pivot).concat(sort(right));
            };

            return sort(Array.apply(this, arguments));
          };
        '''.replace(/\n/g, os.EOL)
        expect(replacedFile).toEqual replacedContent
        expect(finishedHandler.mostRecentCall.args[1]).toEqual null

    it "makes no replacement when nothing to replace", ->
      replacer.on('path-replaced', resultsHandler = jasmine.createSpy())
      replacer.replacePaths(/nopenothere/gi, 'omgwow', [filePath], finishedHandler = jasmine.createSpy())

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(resultsHandler).not.toHaveBeenCalled()
        replacedFile = fs.readFileSync(filePath).toString()
        expect(replacedFile).toEqual sampleContent

    describe "when the file has different permissions than temp files", ->
      [stat, replaceFilePath] = []
      beforeEach ->
        replaceFilePath = path.join(rootPath, 'replaceme.js')
        fs.writeFileSync(replaceFilePath, 'Some file with content to replace')
        fs.chmodSync(replaceFilePath, '777')
        stat = fs.statSync(replaceFilePath)

      afterEach ->
        fs.unlinkSync(replaceFilePath)

      it "replaces and keeps the same file modes", ->
        replacer.replacePaths(/content/gi, 'omgwow', [replaceFilePath], finishedHandler = jasmine.createSpy())

        waitsFor ->
          finishedHandler.callCount > 0

        runs ->
          replacedFile = fs.readFileSync(replaceFilePath).toString()
          expect(replacedFile).toEqual 'Some file with omgwow to replace'

          newStat = fs.statSync(replaceFilePath)
          expect(newStat.mode).toBe stat.mode

    describe "when a file doesnt exist", ->
      it "calls the done callback with a list of errors", ->
        replacer.on('path-replaced', resultsHandler = jasmine.createSpy())
        replacer.replacePaths(/content/gi, 'omgwow', ['/doesnt-exist.js', '/nope.js'], finishedHandler = jasmine.createSpy())

        waitsFor ->
          finishedHandler.callCount > 0

        runs ->
          expect(resultsHandler).not.toHaveBeenCalled()
          errors = finishedHandler.mostRecentCall.args[1]
          expect(errors.length).toBe 2
          expect(errors[0].code).toBe 'ENOENT'
