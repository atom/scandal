fs = require("fs")
isBinaryFile = require("isbinaryfile")
{Readable} = require 'stream'
{StringDecoder} = require 'string_decoder'

lastIndexOf = (buffer, length, char) ->
  i = length
  while i--
    return i if buffer[i] == char
  -1

# Will ensure data will be read on a line boundary. So this will always do the
# right thing:
#
#   lines = []
#   reader = new ChunkedLineReader('some/file.txt')
#   reader.on 'data', (chunk) ->
#     line = chunk.toString().replace(/\r?\n?$/, '')
#     lines = lines.concat(line.split(/\r\n|\n|\r/))
#
# This will collect all the lines in the file, or you can process each line in
# the data handler for more efficiency.
module.exports =
class ChunkedLineReader extends Readable

  @CHUNK_SIZE: 10240
  @chunkedBuffer: null
  @headerBuffer: new Buffer(256)

  constructor: (@filePath, options) ->
    @encoding = options?.encoding ? "utf8"
    super()

  isBinaryFile: ->
    fd = fs.openSync(@filePath, "r")
    isBin = isBinaryFile(@constructor.headerBuffer, fs.readSync(fd, @constructor.headerBuffer, 0, 256))
    fs.closeSync(fd)
    isBin

  _read: ->
    try
      fd = fs.openSync(@filePath, "r")
      line = 0
      offset = 0
      remainder = ''
      chunkSize = @constructor.CHUNK_SIZE
      return if isBinaryFile(@constructor.headerBuffer, fs.readSync(fd, @constructor.headerBuffer, 0, 256))

      @constructor.chunkedBuffer ?= new Buffer(chunkSize)
      chunkedBuffer = @constructor.chunkedBuffer
      bytesRead = fs.readSync(fd, chunkedBuffer, 0, chunkSize, 0)
      decoder = new StringDecoder(@encoding)

      while bytesRead
        # Scary looking. Uses very few new objects
        char = 10
        index = lastIndexOf(chunkedBuffer, bytesRead, char)

        if index < 0
          # no newlines here, the whole thing is a remainder
          newRemainder = decoder.write(chunkedBuffer.slice(0, bytesRead))
          str = null
        else if index > -1 and index == bytesRead - 1
          # the last char is a newline
          newRemainder = ''
          str = decoder.write(chunkedBuffer.slice(0, bytesRead))
        else
          str = decoder.write(chunkedBuffer.slice(0, index+1))
          newRemainder = decoder.write(chunkedBuffer.slice(index+1, bytesRead))

        if str
          str = remainder + str if remainder
          @push(str)
          remainder = newRemainder
        else
          remainder = remainder + newRemainder

        offset += bytesRead
        bytesRead = fs.readSync(fd, chunkedBuffer, 0, chunkSize, offset)

      @push(remainder) if remainder

    catch error
      @emit('error', error)

    finally
      fs.closeSync(fd) if fd?
      @push(null)
