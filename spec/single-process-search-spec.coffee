fs = require 'fs'
path = require 'path'
PathScanner = require '../src/path-scanner'
PathSearcher = require '../src/path-searcher'
PathReplacer = require '../src/path-replacer'

{search, replace, replacePaths} = require '../src/single-process-search'

describe "search", ->
  [scanner, searcher, rootPath] = []

  beforeEach ->
    rootPath = fs.realpathSync(path.join("spec", "fixtures", "many-files"))
    scanner = new PathScanner(rootPath)
    searcher = new PathSearcher()

  describe "when there is no error", ->
    it "finds matches in a file", ->
      searcher.on('results-found', resultsHandler = jasmine.createSpy())
      search(/items/gi, scanner, searcher, finishedHandler = jasmine.createSpy())

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(resultsHandler.callCount).toBe 3

        regex = /many-files\/sample(-)?.*\.js/g
        expect(resultsHandler.argsForCall[0][0].filePath).toMatch regex
        expect(resultsHandler.argsForCall[1][0].filePath).toMatch regex
        expect(resultsHandler.argsForCall[2][0].filePath).toMatch regex

  describe "when there is an error", ->
    it "finishes searching and properly emits the error event", ->
      scanSpy = spyOn(scanner, 'scan')

      searcher.on('file-error', errorHandler = jasmine.createSpy())
      searcher.on('results-found', resultsHandler = jasmine.createSpy())
      search(/items/gi, scanner, searcher, finishedHandler = jasmine.createSpy())

      scanner.emit('path-found', '/this-doesnt-exist.js')
      scanner.emit('path-found', '/nope-not-this-either.js')
      scanner.emit('finished-scanning')

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(errorHandler.callCount).toBe 2
        expect(resultsHandler).not.toHaveBeenCalled()

describe "replace", ->
  [scanner, replacer, rootPath] = []

  beforeEach ->
    rootPath = fs.realpathSync(path.join("spec", "fixtures", "many-files"))
    scanner = new PathScanner(rootPath)
    replacer = new PathReplacer()

  describe "when a replacement is made", ->
    [filePath, sampleContent] = []

    beforeEach ->
      filePath = path.join(rootPath, 'sample.txt')
      sampleContent = fs.readFileSync(filePath).toString()

    afterEach ->
      fs.writeFileSync(filePath, sampleContent)

    it "finds matches and replaces said matches", ->
      replacer.on('path-replaced', resultsHandler = jasmine.createSpy())
      replace(/Some text/gi, 'kittens', scanner, replacer, finishedHandler = jasmine.createSpy())

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(resultsHandler.callCount).toBe 1
        expect(resultsHandler.argsForCall[0][0].filePath).toContain 'sample.txt'

  describe "when there is an error", ->
    it "emits proper error events", ->
      scanSpy = spyOn(scanner, 'scan')

      replacer.on('file-error', errorHandler = jasmine.createSpy())
      replacer.on('path-replaced', resultsHandler = jasmine.createSpy())
      replace(/items/gi, 'kittens', scanner, replacer, finishedHandler = jasmine.createSpy())

      scanner.emit('path-found', '/this-doesnt-exist.js')
      scanner.emit('path-found', '/nope-not-this-either.js')
      scanner.emit('finished-scanning')

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(errorHandler.callCount).toBe 2
        expect(resultsHandler).not.toHaveBeenCalled()
