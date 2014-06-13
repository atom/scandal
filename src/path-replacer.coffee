_ = require 'underscore'
fs = require 'fs'
temp = require 'temp'
{EventEmitter} = require 'events'
{Transform} = require 'stream'
{EOL} = require 'os'

ChunkedLineReader = require './chunked-line-reader'

class ReplaceTransformer extends Transform
  constructor: (@regex, @replacementText, {@dryReplace}) ->
    @replacements = 0
    super()

  _transform: (chunk, encoding, done) ->
    data = chunk.toString()

    matches = data.match(@regex)
    @replacements += matches.length if matches

    data = data.replace(@regex, @replacementText) unless @dryReplace

    @push(data, 'utf8')
    done()

module.exports =
class PathReplacer extends EventEmitter

  constructor: ({@dryReplace}={}) ->

  replacePaths: (regex, replacementText, paths, doneCallback) ->
    results = null
    pathsReplaced = 0

    for filePath in paths
      @replacePath regex, replacementText, filePath, (result) ->
        if result
          results ?= []
          results.push(result)

        doneCallback(results) if ++pathsReplaced == paths.length

  replacePath: (regex, replacementText, filePath, doneCallback) ->
    reader = new ChunkedLineReader(filePath)
    return doneCallback(null) if reader.isBinaryFile()

    replacer = new ReplaceTransformer(regex, replacementText, {@dryReplace})
    output = temp.createWriteStream()

    output.on 'finish', =>
      result = null
      if replacements = replacer.replacements
        result = {filePath, replacements}
        @emit('path-replaced', result)

      tempStat = fs.statSync(output.path)
      origStat = fs.statSync(filePath)
      fs.chmodSync(output.path, origStat.mode) if origStat.mode != tempStat.mode
      try
        fs.renameSync output.path, filePath
      catch e
        if e.code is 'EXDEV'
          readStream = fs.createReadStream output.path
          writeStream = fs.createWriteStream filePath
          readStream.pipe writeStream

      doneCallback(result)

    reader.pipe(replacer).pipe(output)
