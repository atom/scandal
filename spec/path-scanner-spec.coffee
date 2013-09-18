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
