fs = require 'fs'
path = require 'path'
PathSearcher = require '../lib/path-searcher'

describe "PathSearcher", ->
  [searcher, rootPath] = []

  beforeEach ->
    searcher = new PathSearcher()
    rootPath = fs.realpathSync("spec/fixtures/many-files")

  describe "searchLine()", ->
    regex = null
    beforeEach ->
      regex = /ite[m]+s/gi

    it "returns null when no results", ->
      expect(searcher.searchLine(regex, 'nope')).toBe null

    it "returns matches when more than one", ->
      line = 'this thing has items and itemmmms as well!'
      matches = searcher.searchLine(regex, line, 10)

      expect(matches.length).toBe 2

      expect(matches[0].lineText).toBe line
      expect(matches[0].lineNumber).toBe 10
      expect(matches[0].matchText).toBe 'items'
      expect(matches[0].range).toEqual [15, 20]

      expect(matches[1].lineText).toBe line
      expect(matches[1].lineNumber).toBe 10
      expect(matches[1].matchText).toBe 'itemmmms'
      expect(matches[1].range).toEqual [25, 33]

    it "resets the regex between lines", ->
      matches = searcher.searchLine(regex, 'has items and items!')
      expect(matches.length).toBe 2
      expect(matches[0].range).toEqual [4, 9]
      expect(matches[1].range).toEqual [14, 19]

      matches = searcher.searchLine(regex, 'another with itemmms!')
      expect(matches.length).toBe 1
      expect(matches[0].range).toEqual [13, 20]

      matches = searcher.searchLine(regex, 'nothing here')
      expect(matches).toBe null

  describe "searchPath()", ->
    filePath = null

    beforeEach ->
      filePath = path.join(rootPath, 'sample.js')

    it "does not call results-found when there are no results found", ->
      searcher.on('results-found', resultsHandler = jasmine.createSpy())
      searcher.searchPath(/nounicorns/gi, filePath, finishedHandler = jasmine.createSpy())

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(resultsHandler).not.toHaveBeenCalled()

    it "finds matches in a file", ->
      searcher.on('results-found', resultsHandler = jasmine.createSpy())
      searcher.searchPath(/items/gi, filePath, finishedHandler = jasmine.createSpy())

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(resultsHandler.callCount).toBe 1

        results = resultsHandler.mostRecentCall.args[0]
        expect(results.path).toBe filePath
        expect(results.results.length).toBe 6

        expect(results.results[0].lineText).toBe '  var sort = function(items) {'
        expect(results.results[0].lineNumber).toBe 2
        expect(results.results[0].matchText).toBe 'items'
        expect(results.results[0].range).toEqual [22, 27]

  describe "searchPaths()", ->
    filePaths = null

    beforeEach ->
      rootPath = fs.realpathSync("spec/fixtures/git")
      filePaths = [
        path.join(rootPath, 'file.txt')
        path.join(rootPath, 'other.txt')
      ]

    it "does not call results-found when there are no results found", ->
      searcher.on('results-found', resultsHandler = jasmine.createSpy())
      searcher.searchPaths(/nounicorns/gi, filePaths, finishedHandler = jasmine.createSpy())

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(resultsHandler).not.toHaveBeenCalled()

    it "emits results-found event for multiple paths when there are results found", ->
      searcher.on('results-found', resultsHandler = jasmine.createSpy())
      searcher.searchPaths(/text/gi, filePaths, finishedHandler = jasmine.createSpy())

      waitsFor ->
        finishedHandler.callCount > 0

      runs ->
        expect(resultsHandler.callCount).toBe 2
        expect(resultsHandler.argsForCall[0][0].path).toBe filePaths[0]
        expect(resultsHandler.argsForCall[1][0].path).toBe filePaths[1]
