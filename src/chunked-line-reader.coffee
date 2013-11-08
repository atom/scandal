fs = require("fs")
isBinaryFile = require("isbinaryfile")
{Readable} = require 'stream'

lastIndexOf = (buffer, length, char) ->
  i = length
  while i--
    return i if buffer[i] == char
  -1

module.exports =
class ChunkedLineReader extends Readable

  @CHUNK_SIZE: 10240
  @chunkedBuffer: null
  @headerBuffer: new Buffer(256)

  constructor: (@filePath) ->
    super()

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

      while bytesRead
        # Scary looking. Uses very few new objects
        index = lastIndexOf(chunkedBuffer, bytesRead, 10)
        if index < 0
          # no newlines here, the whole thing is a remainder
          newRemainder = chunkedBuffer.toString("utf8", 0, bytesRead)
          str = null
        else if index > -1 and index == bytesRead - 1
          # the last char is a newline
          newRemainder = ''
          str = chunkedBuffer.toString("utf8", 0, bytesRead)
        else
          newRemainder = chunkedBuffer.toString("utf8", index+1, bytesRead)
          str = chunkedBuffer.toString("utf8", 0, index+1)

        if str
          str = remainder + str if remainder
          @push(str)
          remainder = newRemainder
        else
          remainder = remainder + newRemainder

        offset += bytesRead
        bytesRead = fs.readSync(fd, chunkedBuffer, 0, chunkSize, offset)

      @push(remainder) if remainder

    finally
      fs.closeSync(fd)
      @push(null)
