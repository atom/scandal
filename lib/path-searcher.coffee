_ = require("underscore")
fs = require("fs")
{EventEmitter} = require("events")
readFile = require("./read-file")

module.exports =
class PathSearcher extends EventEmitter

  constructor: ->

  searchPaths: (regex, paths, doneCallback) ->
    results = null
    searches = 0

    for filePath in paths
      @searchPath regex, filePath, (pathResult) ->
        if pathResult
          results ?= []
          results.push(pathResult)

        doneCallback(results) if ++searches == paths.length

  searchPath: (regex, path, doneCallback) ->
    matches = null

    readFile path, (lines, lineNumber) =>
      for line in lines
        lineMatches = @searchLine(regex, line, lineNumber)

        if lineMatches?
          matches ?= []
          matches.push(match) for match in lineMatches

        lineNumber++

    if matches?.length
      output = {path, matches}
      @emit('results-found', output)

    doneCallback(output)

  searchLine: (regex, line, lineNumber) ->
    matches = null

    while(regex.test(line))
      matches ?= []
      matches.push
        matchText: RegExp.lastMatch
        lineText: line
        lineNumber: lineNumber
        range: [regex.lastIndex - RegExp.lastMatch.length, regex.lastIndex]

    regex.lastIndex = 0
    matches
