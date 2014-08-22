_ = require("underscore")
fs = require("fs")
os = require("os")
{EventEmitter} = require("events")
ChunkedExecutor = require("./chunked-executor")
ChunkedLineReader = require("./chunked-line-reader")

MAX_LINE_LENGTH = 100
WORD_BREAK_REGEX = /[ \r\n\t;:?=&\/]/
LINE_END_REGEX = /\r\n|\n|\r/
TRAILING_LINE_END_REGEX = /\r?\n?$/

# Public: Will search through paths specified for a regex.
#
# Like the {PathScanner} the {PathSearcher} keeps no state. You need to consume
# results via the done callbacks or events.
#
# File reading is fast and memory efficient. It reads in 10k chunks and writes
# over each previous chunk. Small object creation is kept to a minimum during
# the read to make light use of the GC.
#
# ## Examples
#
# ```coffee
# {PathSearcher} = require 'scandal'
# searcher = new PathSearcher()
#
# # You can subscribe to a `results-found` event
# searcher.on 'results-found', (result) ->
#   # result will contain all the matches for a single path
#   console.log("Single Path's Results", result)
#
# # Search a list of paths
# searcher.searchPaths /text/gi, ['/Some/path', ...], (results) ->
#   console.log('Done Searching', results)
#
# # Search a single path
# searcher.searchPath /text/gi, '/Some/path', (result) ->
#   console.log('Done Searching', result)
# ```
#
# A results from line 10 (1 based) are in the following format:
#
# ```js
# {
#   "path": "/Some/path",
#   "matches": [{
#     "matchText": "Text",
#     "lineText": "Text in this file!",
#     "lineTextOffset": 0,
#     "range": [[9, 0], [9, 4]]
#   }]
# }
# ```
#
# ## Events
#
# ### results-found
#
# Fired when searching for a each path has been completed and matches were found.
#
# * `results` {Object} in the result format:
#   ```js
#   {
#     "path": "/Some/path.txt",
#     "matches": [{
#       "matchText": "Text",
#       "lineText": "Text in this file!",
#       "lineTextOffset": 0,
#       "range": [[9, 0], [9, 4]]
#     }]
#   }
#   ```
#
# ### results-not-found
#
# Fired when searching for a path has finished and _no_ matches were found.
#
# * `filePath` path to the file nothing was found in `"/Some/path.txt"`
#
# ### file-error
#
# Fired when an error occurred when searching a file. Happens for example when a file cannot be opened.
#
# * `error` {Error} object
#
module.exports =
class PathSearcher extends EventEmitter

  # Public: Construct a {PathSearcher} object.
  #
  # * `options` {Object}
  #   * `maxLineLength` {Number} default `100`; The max length of the `lineText`
  #      component in a results object. `lineText` is the context around the matched text.
  #   * `wordBreakRegex` {RegExp} default `/[ \r\n\t;:?=&\/]/`;
  #      Used to break on a word when finding the context for a match.
  constructor: ({@maxLineLength, @wordBreakRegex}={}) ->
    @maxLineLength ?= MAX_LINE_LENGTH
    @wordBreakRegex ?= WORD_BREAK_REGEX

  ###
  Section: Searching
  ###

  # Public: Search an array of paths.
  #
  # Will search with a {ChunkedExecutor} so as not to immediately exhaust all
  # the available file descriptors. The {ChunkedExecutor} will execute 20 paths
  # concurrently.
  #
  # * `regex` {RegExp} search pattern
  # * `paths` {Array} of {String} file paths to search
  # * `doneCallback` called when searching the entire array of paths has finished
  #   * `results` {Array} of Result objects in the format specified above;
  #      null when there are no results
  #   * `errors` {Array} of errors; null when there are no errors. Errors will
  #      be js Error objects with `message`, `stack`, etc.
  searchPaths: (regex, paths, doneCallback) ->
    errors = null
    results = null

    searchPath = (filePath, pathCallback) =>
      @searchPath regex, filePath, (pathResult, error) ->
        if pathResult
          results ?= []
          results.push(pathResult)

        if error
          errors ?= []
          errors.push(error)

        pathCallback()

    new ChunkedExecutor(paths, searchPath).execute -> doneCallback(results, errors)

  # Public: Search a file path for a regex
  #
  # * `regex` {RegExp} search pattern
  # * `filePath` {String} file path to search
  # * `doneCallback` called when searching the entire array of paths has finished
  #   * `results` {Array} of Result objects in the format specified above;
  #      null when there are no results
  #   * `error` {Error}; null when there is no error
  searchPath: (regex, filePath, doneCallback) ->
    matches = null
    lineNumber = 0
    reader = new ChunkedLineReader(filePath)
    error = null

    reader.on 'end', =>
      if matches?.length
        output = {filePath, matches}
        @emit('results-found', output)
      else
        @emit('results-not-found', filePath)
      doneCallback(output, error)

    try
      reader.on 'data', (chunk) =>
        lines = chunk.toString().replace(TRAILING_LINE_END_REGEX, '').split(LINE_END_REGEX)
        for line in lines
          lineMatches = @searchLine(regex, line, lineNumber++)

          if lineMatches?
            matches ?= []
            matches.push(match) for match in lineMatches
    catch e
      error = e
      @emit('file-error', e)

    return

  searchLine: (regex, line, lineNumber) ->
    matches = null
    lineTextOffset = 0

    while regex.test(line)
      lineTextOffset = 0
      lineTextLength = line.length
      matchText = RegExp.lastMatch
      matchLength = matchText.length
      matchIndex = regex.lastIndex - matchLength
      matchEndIndex = regex.lastIndex

      if lineTextLength < @maxLineLength
        # The line is already short enough, we dont need to do any trimming
        lineText = line
      else
        # TODO: I want to break this into a function, but it needs to return the
        # new text and an offset, or an offset and a length. I am worried about
        # speed and creating a bunch of arrays just for returning from said
        # function.

        # Find the initial context around the match. This will likely break on
        # words or be too short. We will fix in the subsequent lines.
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

        # Trim the text and give the contexualized line to the user
        lineTextLength = lineTextEndOffset - lineTextOffset
        lineText = line.substr(lineTextOffset, lineTextLength)

      range = [[lineNumber, matchIndex], [lineNumber, matchEndIndex]]
      matches ?= []
      matches.push {matchText, lineText, lineTextOffset, range}

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
