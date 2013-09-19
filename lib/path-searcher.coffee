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

  searchPath: (regex, path, stats, doneCallback) ->
    results = null

    readFile path, (lines, lineNumber) =>
      for line in lines
        matches = @searchLine(regex, line, lineNumber)

        if matches?
          results ?= []
          results.push(match) for match in matches

        lineNumber++

    if results?.length
      output = {path, results}
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

  searchWithScanner: (regex, pathScanner, doneCallback) ->
    finishedScanning = false
    pathsToSearch = 0

    scanPath = (filePath) =>
      pathsToSearch++
      @searchPath regex, filePath, ->
        pathsToSearch--
        checkIfFinished()

    onFinishedScanning = ->
      finishedScanning = true
      checkIfFinished()

    checkIfFinished = ->
      finish() if finishedScanning and pathsToSearch == 0

    finish = ->
      pathScanner.removeListener 'path-found', scanPath
      pathScanner.removeListener 'finished-scanning', onFinishedScanning
      doneCallback()

    pathScanner.on 'path-found', scanPath
    pathScanner.on 'finished-scanning', onFinishedScanning
    pathScanner.scan()
