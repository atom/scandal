fs = require("fs")
path = require("path")
{EventEmitter} = require("events")
PathFilter = require("./path-filter")

DIR_SEP = path.sep

# Public: Scans a directory and emits events when paths matching input options
# have been found.
#
# Note: `PathScanner` keeps no state. You must consume paths via the {::path-found} event.
#
# ## Examples
#
# ```coffee
# {PathScanner} = require 'scandal'
# scanner = new PathScanner('/Users/me/myDopeProject', includeHidden: false)
#
# scanner.on 'path-found', (path) ->
#   console.log(path)
#
# scanner.on 'finished-scanning', ->
#   console.log('All done!')
#
# scanner.scan()
# ```
#
# ## Events
#
# * `path-found` Emit when a path has been found
#   * `pathName` {String} name of the path
# * `finished-scanning` Emit when the scanner is finished
#
module.exports =
class PathScanner extends EventEmitter

  # Public: Create a {PathScanner} object.
  #
  # * `rootPath` {String} top level directory to scan. eg. `/Users/ben/somedir`
  # * `options` {Object} options hash
  #   * `excludeVcsIgnores` {Boolean}; default false; true to exclude paths
  #      defined in a .gitignore. Uses git-utils to check ignred files.
  #   * `inclusions` {Array} of patterns to include. Uses minimatch with a couple
  #      additions: `['dirname']` and `['dirname/']` will match all paths in
  #      directory dirname.
  #   * `exclusions` {Array} of patterns to exclude. Same matcher as inclusions.
  #   * `includeHidden` {Boolean} default false; true includes hidden files
  constructor: (@rootPath, @options={}) ->
    @asyncCallsInProgress = 0
    @realPathCache = {}
    @rootPath = path.resolve(@rootPath)
    @rootPathLength = @rootPath.length
    @pathFilter = new PathFilter(@rootPath, @options)

  ###
  Section: Scanning
  ###

  # Public: Begin the scan
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
      if @isInternalSymlink(filePath)
        return null
      try
        stat = fs.statSync(filePath)
      catch e
        return null

    stat

  isInternalSymlink: (filePath) ->
    realPath = null
    try
      realPath = fs.realpathSync(filePath, @realPathCache)
    catch error
      ; # ignore
    realPath?.search(@rootPath) is 0

  asyncCallStarting: ->
    @asyncCallsInProgress++

  asyncCallDone: ->
    if --@asyncCallsInProgress is 0
      @emit('finished-scanning', this)
