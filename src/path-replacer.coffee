fs = require 'fs'
temp = require('temp').track()
{EventEmitter} = require 'events'
{Transform} = require 'stream'
{EOL} = require 'os'

ChunkedExecutor = require './chunked-executor'
ChunkedLineReader = require './chunked-line-reader'

class ReplaceTransformer extends Transform
  constructor: (@regex, @replacementText, {@dryReplace}) ->
    @replacements = 0
    super()

  _transform: (chunk, encoding, done) ->
    data = chunk.toString()

    matches = data.match(@regex)
    @replacements += matches.length if matches

    data = data.replace(@regex, @replacementText) if matches and not @dryReplace

    @push(data, 'utf8')
    done()

module.exports =
class PathReplacer extends EventEmitter
  constructor: ({@dryReplace}={}) ->

  replacePaths: (regex, replacementText, paths, doneCallback) ->
    errors = null
    results = null

    replacePath = (filePath, pathCallback) =>
      @replacePath regex, replacementText, filePath, (result, error) ->
        if result
          results ?= []
          results.push(result)

        if error
          errors ?= []
          errors.push error

        pathCallback()

    new ChunkedExecutor(paths, replacePath).execute -> doneCallback(results, errors)

  replacePath: (regex, replacementText, filePath, doneCallback) ->
    reader = new ChunkedLineReader(filePath)
    try
      return doneCallback(null) if reader.isBinaryFile()
    catch error
      @emit('file-error', error)
      return doneCallback(null, error)

    replacer = new ReplaceTransformer(regex, replacementText, {@dryReplace})
    output = temp.createWriteStream()

    output.on 'finish', =>
      result = null
      if replacements = replacer.replacements
        result = {filePath, replacements}
        @emit('path-replaced', result)

      readStream = fs.createReadStream output.path
      writeStream = fs.createWriteStream filePath
      writeStream.on 'finish', ->
        doneCallback(result)

      try
        readStream.pipe(writeStream)
      catch error
        @emit('file-error', error)
        doneCallback(null, error)

    reader.on 'error', (error) =>
      @emit('file-error', error)
      doneCallback(null, error)

    reader.pipe(replacer).pipe(output)
