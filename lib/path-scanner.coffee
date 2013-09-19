_ = require("underscore")
fs = require("fs")
path = require("path")
{EventEmitter} = require("events")
PathFilter = require("./path-filter")

DIR_SEP = path.sep

module.exports =
class PathScanner extends EventEmitter

  constructor: (@rootPath, @options={}) ->
    @asyncCallsInProgress = 0
    @rootPath = path.resolve(@rootPath)
    @rootPathLength = @rootPath.length
    @pathFilter = new PathFilter(@rootPath, @options)

  scan: ->
    @readDir(@rootPath)

  readDir: (filePath) ->
    @asyncCallStarting()
    fs.readdir filePath, (err, files) =>
      return @asyncCallDone() unless files

      fileCount = files.length
      prefix = filePath + DIR_SEP
      while fileCount--
        file = files.shift()
        filename = prefix + file
        @processFile(filename)

      @asyncCallDone()

  relativize: (filePath) ->
    len = filePath.length
    i = @rootPathLength
    while i < len
      break unless filePath[i] == DIR_SEP
      i++

    filePath.slice(i)

  processFile: (filePath) ->
    relPath = @relativize(filePath)
    stat = @stat(filePath)
    return unless stat

    if stat.isFile() and @pathFilter.isFileAccepted(relPath)
      @emit('path-found', filePath)
    else if stat.isDirectory() and @pathFilter.isDirectoryAccepted(relPath)
      @readDir(filePath)

  stat: (filePath) ->

    # lstat is SLOW, but what other way to determine if something is a directory or file ?
    # also, sync is about 200ms faster than async...
    stat = fs.lstatSync(filePath)

    if @options.follow and stat.isSymbolicLink()
      try
        stat = fs.statSync(filePath)
      catch e
        return null

    stat

  asyncCallStarting: ->
    @asyncCallsInProgress++

  asyncCallDone: ->
    if --@asyncCallsInProgress is 0
      @emit('finished-scanning', this)
