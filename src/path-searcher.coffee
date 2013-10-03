_ = require("underscore")
fs = require("fs")
{EventEmitter} = require("events")
readFile = require("./read-file")

MAX_LINE_LENGTH = 100
WORD_BREAK_REGEX = /[ \n\t;:?=&\/]/

module.exports =
class PathSearcher extends EventEmitter

  constructor: ({@maxLineLength, @wordBreakRegex}={}) ->
    @maxLineLength ?= MAX_LINE_LENGTH
    @wordBreakRegex ?= WORD_BREAK_REGEX

  searchPaths: (regex, paths, doneCallback) ->
    results = null
    searches = 0

    for filePath in paths
      @searchPath regex, filePath, (pathResult) ->
        if pathResult
          results ?= []
          results.push(pathResult)

        doneCallback(results) if ++searches == paths.length

  searchPath: (regex, filePath, doneCallback) ->
    matches = null

    readFile filePath, (lines, lineNumber) =>
      for line in lines
        lineMatches = @searchLine(regex, line, lineNumber)

        if lineMatches?
          matches ?= []
          matches.push(match) for match in lineMatches

        lineNumber++

    if matches?.length
      output = {filePath, matches}
      @emit('results-found', output)

    doneCallback(output)

  searchLine: (regex, line, lineNumber) ->
    matches = null
    lineTextOffset = 0

    while(regex.test(line))
      lineTextOffset = 0
      lineTextLength = line.length
      matchText = RegExp.lastMatch
      matchLength = matchText.length
      matchIndex = regex.lastIndex - matchLength
      matchEndIndex = regex.lastIndex

      if lineTextLength < @maxLineLength
        lineText = line
      else
        # TODO: I want to break this into a function, but it needs to return the
        # new text and an offset, or an offset and a length. I am worried about
        # speed and creating a bunch of arrays just for returning from the
        # proposed function.

        # Find the line context around the match
        lineTextOffset = Math.round(matchIndex - (@maxLineLength - matchLength) / 2)
        lineTextEndOffset = lineTextOffset + @maxLineLength

        if lineTextOffset <= 0
          # The match is near the beginning of the line, so we expand the right
          lineTextOffset = 0
          lineTextEndOffset = @maxLineLength
        else if lineTextEndOffset > lineTextLength - 2
          # The match is near the end of the line, so we expand to the left
          lineTextEndOffset = lineTextLength - 1
          lineTextOffset = lineTextEndOffset - @maxLineLength

        # We dont want the line to break a word, so expand to the word boundaries
        lineTextOffset = @findWordBreak(line, lineTextOffset, -1)
        lineTextEndOffset = @findWordBreak(line, lineTextEndOffset, 1) + 1

        lineTextLength = lineTextEndOffset - lineTextOffset
        lineText = line.substr(lineTextOffset, lineTextLength)

      matches ?= []
      matches.push
        matchText: matchText
        lineText: lineText
        lineTextOffset: lineTextOffset
        range: [[lineNumber, matchIndex], [lineNumber, matchEndIndex]]

    regex.lastIndex = 0
    matches

  findWordBreak: (line, offset, increment) ->
    i = offset
    len = line.length
    maxIndex = len - 1

    while i < len and i >= 0
      checkIndex = i + increment
      return i if @wordBreakRegex.test(line[checkIndex])
      i = checkIndex

    return 0 if i < 0
    return maxIndex if i > maxIndex
    i
