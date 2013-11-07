fs = require 'fs'
path = require 'path'
wrench = require 'wrench'
PathScanner = require '../src/path-scanner'

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

      it "explicit inclusions override exclusions", ->
        scanner = new PathScanner(rootPath, inclusions: ['dir'], exclusions: ['dir'])
        scanner.on('path-found', pathHandler = createPathCollector())
        scanner.on('finished-scanning', finishedHandler = jasmine.createSpy())

        runs ->
          scanner.scan()

        waitsFor ->
          finishedHandler.callCount > 0

        runs ->
          expect(paths).toContain path.join(rootPath, 'dir', 'file7_ignorable.rb')

      it "lists only paths specified by a deep dir", ->
        scanner = new PathScanner(rootPath, inclusions: [path.join('.root', 'subdir')+'/'], includeHidden: true)
        scanner.on('path-found', pathHandler = createPathCollector())
        scanner.on('finished-scanning', finishedHandler = jasmine.createSpy())

        runs ->
          scanner.scan()

        waitsFor ->
          finishedHandler.callCount > 0

        runs ->
          expect(paths).toContain path.join(rootPath, '.root', 'subdir', 'file1.txt')
          expect(paths).not.toContain path.join(rootPath, '.root', 'file3.txt')

      dirs = ['dir', 'dir/', 'dir/*', 'dir/**']
      for dir in dirs
        ((dir) ->
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
        )(dir)

  describe "with a git repo", ->
    beforeEach ->
      rootPath = fs.realpathSync("spec/fixtures/git")
      wrench.copyDirSyncRecursive(path.join(rootPath, 'git.git'), path.join(rootPath, '.git'))
      wrench.rmdirSyncRecursive(path.join(rootPath, 'git.git'))
      fs.writeFileSync(path.join(rootPath, 'ignored.txt'), "This must be added in the spec because the file can't be checked in!")

    afterEach ->
      wrench.copyDirSyncRecursive(path.join(rootPath, '.git'), path.join(rootPath, 'git.git'))
      wrench.rmdirSyncRecursive(path.join(rootPath, '.git'))

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
        expect(paths.length).toBe 4
        expect(paths).toContain path.join(rootPath, 'ignored.txt')

    it "includes files deep in an included dir", ->
      scanner = new PathScanner(rootPath, excludeVcsIgnores: false, inclusions: ['node_modules'])
      scanner.on('path-found', pathHandler = createPathCollector())
      scanner.on('finished-scanning', finishedHandler = jasmine.createSpy())

      runs ->
        scanner.scan()

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(paths.length).toBe 1
        expect(paths).toContain path.join(rootPath, 'node_modules', 'pkg', 'sample.js')

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

    it "treats hidden file patterns as directories and wont search in hidden directories", ->
      scanner = new PathScanner(rootPath, exclusions: ['.git'], excludeVcsIgnores: false, includeHidden: true)
      scanner.on('path-found', pathHandler = createPathCollector())
      scanner.on('finished-scanning', finishedHandler = jasmine.createSpy())

      runs ->
        scanner.scan()

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(paths).not.toContain path.join(rootPath, '.git/HEAD')

    it "can ignore hidden files even though it is treated as a directory", ->
      scanner = new PathScanner(rootPath, exclusions: ['.gitignore'], excludeVcsIgnores: false, includeHidden: true)
      scanner.on('path-found', pathHandler = createPathCollector())
      scanner.on('finished-scanning', finishedHandler = jasmine.createSpy())

      runs ->
        scanner.scan()

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(paths).not.toContain path.join(rootPath, '.gitignore')
