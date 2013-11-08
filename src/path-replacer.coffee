_ = require 'underscore'
fs = require 'fs'
temp = require 'temp'
{EventEmitter} = require 'events'
{Transform} = require 'stream'
{EOL} = require 'os'

ChunkedLineReader = require './read-file'

class ReplaceTransformer extends Transform
  constructor: (@regex, @replacementText) ->
    @matches = []
    super()

  _transform: (chunk, encoding, done) ->
    data = chunk.toString()
    @matches = @matches.concat(data.match(@regex))
    data = data.replace(@regex, @replacementText)
    @push(data, 'utf8')
    done()

module.exports =
class PathReplacer extends EventEmitter

  constructor: ->

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
    replacer = new ReplaceTransformer(regex, replacementText)
    output = temp.createWriteStream()

    output.on 'finish', =>
      replacements = replacer.matches.length
      result = {filePath, replacements}
      @emit('path-replaced', result)

      fs.renameSync(output.path, filePath)

      doneCallback(result)

    reader.pipe(replacer).pipe(output)
