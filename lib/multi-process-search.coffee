_ = require 'underscore'
PathSearcher = require './path-searcher'
PathScanner = require './path-scanner'
path = require "path"
split = require "split"

###
Multiprocess.

This is an experiment. The hope was that it would be faster than the single
process search. However, it tuned out to be way more complicated, unreliable,
AND slower. Not good.

NOTES:

  * This uses stdin/out to communicate between processes. I tried
    process.send, but it often the child process would not receive the messages!

  * Knowing when to kill the processes is hard. There is a lot of complication
    in the main process to keep track of the state of each child process so we
    know when to halt.

  * Sometimes on large files (right now, minified less.js) on large searches
    (16k files) seem to make it not complete.
###


makeTask = (fn) ->
  "(#{fn.toString()})();"

fork = (task, env) ->
  child_process = require 'child_process'
  args = [task, '--harmony_collections']
  # silent: true is important so we can access stdin/out
  child_process.fork '--eval', args, {env, cwd: __dirname, silent: true}

kill = (childProcess) ->
  childProcess.removeAllListeners()
  childProcess.kill()
  null

# Scan and emit jsonified list of paths on stdout. Each line is a list.
# \0\n inidicates that it's done.
scan = ->
  require("coffee-script");
  PathScanner = require './path-scanner.coffee'

  PATHS_TO_SEARCH = 50
  STOP_CHAR = String.fromCharCode(0)

  emitPaths = (paths) ->
    process.stdout.write(JSON.stringify(paths)+'\n')
  emitEnd = ->
    process.stdout.write(STOP_CHAR+'\n')

  options =
    pathToScan: process.env.pathToScan
    showHidden: process.env.showHidden == 'true'
    excludeVcsIgnores: process.env.excludeVcsIgnores == 'true'

  scanner = new PathScanner(options.pathToScan, options)

  paths = []
  scanner.on 'path-found', (path) ->
    paths.push(path)
    if paths.length == PATHS_TO_SEARCH
      emitPaths(paths)
      paths = []

  scanner.on 'finished-scanning', ->
    emitPaths(paths) if paths.length
    emitEnd()

  scanner.scan()

# Search and emit jsonified results objects. Each line is a object for a
# single path's results.
# \1\n - indicates start of search
# {...}\n - indicates results
# \4\n - indicates end of search
#
# This thing never knows when it is completely done. You can just keep sending
# it lists of paths to search.
search = ->
  require("coffee-script");
  PathSearcher = require './path-searcher.coffee'

  searches = 0

  START_CHAR = String.fromCharCode(1)
  END_CHAR = String.fromCharCode(4)
  STOP_CHAR = String.fromCharCode(0)

  emitStart = ->
    process.stdout.write(START_CHAR+'\n')
  emitResults = (results) ->
    if results
      results = (JSON.stringify(res) for res in results).join('\n')
      process.stdout.write(results+'\n')
    emitEnd()
  emitEnd = ->
    process.stdout.write(END_CHAR+'\n')

  options = process.env
  searcher = new PathSearcher()
  regex = new RegExp(options.search, 'gi')

  soFar = ''
  readLines = (stdin) ->
    buf = stdin.read()
    return null unless buf

    # Lifted from https://github.com/dominictarr/split/blob/master/index.js
    pieces = (soFar + buf).split('\n')
    soFar = pieces.pop()
    pieces

  process.stdin.on 'readable', ->
    lines = readLines(process.stdin)
    return unless lines

    for line in lines
      emitStart()
      if !line or line[0] == STOP_CHAR
        emitEnd()
      else
        paths = JSON.parse(line)
        searcher.searchPaths regex, paths, (results) ->
          emitResults(results)

searchMain = (options) ->
  options.pathToScan = path.resolve(options.pathToScan)
  env = _.extend({}, process.env, options)

  START_CHAR = String.fromCharCode(1)
  END_CHAR = String.fromCharCode(4)
  STOP_CHAR = String.fromCharCode(0)

  scanTask = makeTask(scan)
  searchTask = makeTask(search)

  console.time 'Multi Process Search'

  searches = 0
  finished = false
  scanFinished = false

  resultCount = 0
  pathCount = 0

  scanProcess = fork(scanTask, env)
  searchProcess = fork(searchTask, env)

  searchProcess.stdin.setEncoding = 'utf-8';
  scanProcess.stdout.pipe(split()).on 'data', (data) ->
    if data[0] == STOP_CHAR
      scanFinished = true
      maybeEnd()
    else
      searches++
      searchProcess.stdin.write(data+'\n')

  searchProcess.stderr.pipe(process.stderr)

  searchProcess.stdout.pipe(split()).on 'data', (line) ->
    if line[0] == START_CHAR
      console.log "search start" if options.verbose
    else if line[0] == END_CHAR
      searches--
      console.log "search end #{searches}" if options.verbose
    else if line and line.length
      results = JSON.parse(line)
      if results
        pathCount++
        resultCount += results.matches.length
        console.log "#{results.matches.length} matches in #{results.path}" if options.verbose

    maybeEnd()

  scanProcess.on 'message', ({event, arg}) ->
    console.log event, arg
  searchProcess.on 'message', ({event, arg}) ->
    console.log event, arg

  maybeEnd = ->
    return if finished
    if scanFinished and searches == 0
      kill(scanProcess)
      kill(searchProcess)
      end()

  end = ->
    finished = true
    console.timeEnd 'Multi Process Search'
    console.log "#{resultCount} matches in #{pathCount} files"

module.exports = {searchMain}
