fs = require 'fs'
path = require 'path'
PathScanner = require '../lib/path-scanner'

describe "PathScanner", ->
  describe "a non-git directory with many files", ->
    rootPath = fs.realpathSync("spec/fixtures/many-files")
    
    it 'lists all non-hidden files', ->
      scanner = new PathScanner(rootPath)
      scanner.on('path-found', (pathHandler = jasmine.createSpy()))
      scanner.on('finished-scanning', (finishedHandler = jasmine.createSpy()))
      
      runs ->
        scanner.scan()
        
      waitsFor ->
        pathHandler.callCount > 0
        
      waitsFor ->
        finishedHandler.callCount > 0
      
      runs ->
        expect(scanner.paths.length).toBe 13
        expect(scanner.paths).toContain path.join(rootPath, 'file1.txt')
        expect(scanner.paths).toContain path.join(rootPath, 'dir', 'file7_ignorable.rb')
    
    describe "including file paths", ->
      it "lists only paths specified by file pattern", ->
        scanner = new PathScanner(rootPath, inclusions: ['*.js'])
        scanner.on('finished-scanning', (finishedHandler = jasmine.createSpy()))
        
        runs ->
          scanner.scan()
          
        waitsFor ->
          finishedHandler.callCount > 0
        
        runs ->
          expect(scanner.paths.length).toBe 2
          expect(scanner.paths).toContain path.join(rootPath, 'newdir', 'deep_dir.js')
          expect(scanner.paths).toContain path.join(rootPath, 'sample.js')

      dirs = ['dir', 'dir/', 'dir/*']
      for dir in dirs
        it "lists only paths specified in #{dir}", ->
          scanner = new PathScanner(rootPath, inclusions: [dir])
          scanner.on('finished-scanning', (finishedHandler = jasmine.createSpy()))
          
          runs ->
            scanner.scan()
            
          waitsFor ->
            finishedHandler.callCount > 0
          
          runs ->
            expect(scanner.paths.length).toBe 1
            expect(scanner.paths).toContain path.join(rootPath, 'dir', 'file7_ignorable.rb')
