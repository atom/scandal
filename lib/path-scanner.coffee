_ = require("underscore")
fs = require("fs")
path = require("path")
{EventEmitter} = require("events")
PathFilter = require("./path-filter")

DIR_SEP = path.sep

module.exports =
class PathScanner extends EventEmitter

  constructor: (@rootPath, @options={}) ->
    @paths = []
    @stats = {}
    @structure = {}
    @asyncCallsInProgress = 0
    @pathFilter = new PathFilter(@options.inclusions, @options.exclusions, @options.hidden)

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

  processFile: (filePath) ->
    stat = @stat(filePath)
    return unless stat

    if stat.isFile() and @pathFilter.isFileAccepted(path.relative(@rootPath, filePath))
      @stats[filePath] = stat
      @paths.push(filePath) unless _.contains(@paths, filePath)
      @emit('path-found', filePath)
    else if stat.isDirectory() and @pathFilter.isDirectoryAccepted(path.relative(@rootPath, filePath))
      @readDir(filePath)

  stat: (filePath) ->
    return @stats[filePath] if @stats[filePath]?

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
