fs = require("fs")
isBinaryFile = require("isbinaryfile")

lastIndexOf = (buffer, length, char) ->
  i = length
  while i--
    return i if buffer[i] == char
  -1

headerBuffer = new Buffer(256)
chunkedBuffer = null

readFile = (path, callback) ->
  chunkSize = readFile.CHUNK_SIZE
  line = 1
  fd = fs.openSync(path, "r")
  try
    offset = 0
    remainder = ''
    return if isBinaryFile(headerBuffer, fs.readSync(fd, headerBuffer, 0, 256))

    chunkedBuffer ?= new Buffer(chunkSize)
    bytesRead = fs.readSync(fd, chunkedBuffer, 0, chunkSize, 0)

    while bytesRead
      # Scary looking. Uses very few new objects
      index = lastIndexOf(chunkedBuffer, bytesRead, 10)
      if index < 0
        # no newlines here, the whole thing is a remainder
        newRemainder = chunkedBuffer.toString("utf8", 0, bytesRead)
        str = null
        lines = null
      else if index > -1 and index == bytesRead - 1
        # the last char is a newline
        newRemainder = ''
        str = chunkedBuffer.toString("utf8", 0, bytesRead - 1)
        lines = str.split('\n')
      else
        newRemainder = chunkedBuffer.toString("utf8", index+1, bytesRead)
        str = chunkedBuffer.toString("utf8", 0, index)
        lines = str.split('\n')

      if not lines? or lines.length == 0
        remainder = remainder + newRemainder
      else
        lines[0] = remainder + lines[0] if remainder
        callback(lines, line)
        remainder = newRemainder

      line += lines.length if lines?
      offset += bytesRead
      bytesRead = fs.readSync(fd, chunkedBuffer, 0, chunkSize, offset)

    callback(remainder.split('\n'), line) if remainder

  finally
    fs.closeSync(fd)

readFile.CHUNK_SIZE = 10240

module.exports = readFile
