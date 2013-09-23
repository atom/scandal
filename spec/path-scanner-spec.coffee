fs = require 'fs'
path = require 'path'
PathScanner = require '../lib/path-scanner'

describe "PathScanner", ->
  rootPath = null
  paths = null

  createPathCollector = ->
    paths = []
    pathHandler = jasmine.createSpy()
    pathHandler.andCallFake (p) ->
      paths.push(p)
    pathHandler

  describe "a non-git directory with many files", ->
    beforeEach ->
      rootPath = fs.realpathSync("spec/fixtures/many-files")

    it 'lists all non-hidden files', ->
      scanner = new PathScanner(rootPath)
      scanner.on('path-found', pathHandler = createPathCollector())
      scanner.on('finished-scanning', finishedHandler = jasmine.createSpy())

      runs ->
        scanner.scan()

      waitsFor ->
        pathHandler.callCount > 0

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(paths.length).toBe 13
        expect(paths).toContain path.join(rootPath, 'file1.txt')
        expect(paths).toContain path.join(rootPath, 'dir', 'file7_ignorable.rb')

    describe "including file paths", ->
      it "lists only paths specified by file pattern", ->
        scanner = new PathScanner(rootPath, inclusions: ['*.js'])
        scanner.on('path-found', pathHandler = createPathCollector())
        scanner.on('finished-scanning', finishedHandler = jasmine.createSpy())

        runs ->
          scanner.scan()

        waitsFor ->
          finishedHandler.callCount > 0

        runs ->
          expect(paths.length).toBe 2
          expect(paths).toContain path.join(rootPath, 'newdir', 'deep_dir.js')
          expect(paths).toContain path.join(rootPath, 'sample.js')

      dirs = ['dir', 'dir/', 'dir/*']
      for dir in dirs
        it "lists only paths specified in #{dir}", ->
          scanner = new PathScanner(rootPath, inclusions: [dir])
          scanner.on('path-found', pathHandler = createPathCollector())
          scanner.on('finished-scanning', finishedHandler = jasmine.createSpy())

          runs ->
            scanner.scan()

          waitsFor ->
            finishedHandler.callCount > 0

          runs ->
            expect(paths.length).toBe 1
            expect(paths).toContain path.join(rootPath, 'dir', 'file7_ignorable.rb')

  describe "with a git repo", ->
    beforeEach ->
      rootPath = fs.realpathSync("spec/fixtures/git")
      fs.rename(path.join(rootPath, 'git.git'), path.join(rootPath, '.git'))
      fs.writeFileSync(path.join(rootPath, 'ignored.txt'), "This must be added in the spec because the file can't be checked in!")

    afterEach ->
      fs.rename(path.join(rootPath, '.git'), path.join(rootPath, 'git.git'))

    it "excludes files specified with .gitignore", ->
      scanner = new PathScanner(rootPath, excludeVcsIgnores: true)
      scanner.on('path-found', pathHandler = createPathCollector())
      scanner.on('finished-scanning', finishedHandler = jasmine.createSpy())

      runs ->
        scanner.scan()

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(paths.length).toBe 2
        expect(paths).not.toContain path.join(rootPath, 'ignored.txt')

    it "includes files matching .gitignore patterns when excludeVcsIgnores == false", ->
      scanner = new PathScanner(rootPath, excludeVcsIgnores: false)
      scanner.on('path-found', pathHandler = createPathCollector())
      scanner.on('finished-scanning', finishedHandler = jasmine.createSpy())

      runs ->
        scanner.scan()

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(paths.length).toBe 3
        expect(paths).toContain path.join(rootPath, 'ignored.txt')

    it "lists hidden files with showHidden == true", ->
      scanner = new PathScanner(rootPath, excludeVcsIgnores: true, includeHidden: true)
      scanner.on('path-found', pathHandler = createPathCollector())
      scanner.on('finished-scanning', finishedHandler = jasmine.createSpy())

      runs ->
        scanner.scan()

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(paths.length).toBe 3
        expect(paths).toContain path.join(rootPath, '.gitignore')
