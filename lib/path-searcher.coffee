_ = require("underscore")
fs = require("fs")
{EventEmitter} = require("events")
byline = require("byline")

module.exports =
class PathSearcher extends EventEmitter

  constructor: ->

  searchPaths: (regex, paths, doneCallback) ->
    searches = 0
    for filePath in paths
      @searchPath regex, filePath, ->
        doneCallback() if ++searches == paths.length

  searchPath: (regex, path, doneCallback) ->
    results = []
    lineNumber = 1

    stream = byline(fs.createReadStream(path))

    stream.on 'data', (line) =>
      matches = @searchLine(regex, line.toString(), lineNumber)

      if matches?
        results.push(match) for match in matches

      lineNumber++

    stream.on 'end', =>
      if results.length
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
