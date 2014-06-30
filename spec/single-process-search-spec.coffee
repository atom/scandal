fs = require 'fs'
path = require 'path'
PathScanner = require '../src/path-scanner'
PathSearcher = require '../src/path-searcher'
PathReplacer = require '../src/path-replacer'

{search, replace} = require '../src/single-process-search'

describe "search", ->
  [scanner, searcher, rootPath] = []

  beforeEach ->
    rootPath = fs.realpathSync("spec/fixtures/many-files")
    scanner = new PathScanner(rootPath)
    searcher = new PathSearcher()

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

describe "replace", ->
  [scanner, replacer, rootPath] = []

  beforeEach ->
    rootPath = fs.realpathSync("spec/fixtures/many-files")
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
