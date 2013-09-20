_ = require 'underscore'
{ArgumentParser} = require 'argparse'
PathSearcher = require './path-searcher'
PathScanner = require './path-scanner'
path = require "path"
split = require "split"

MAX_CONCURRENT_SEARCH = 20

###
Single Process
###

singleProcessSearch = (regex, scanner, searcher, doneCallback) ->
  finishedScanning = false
  pathCount = 0
  pathsSearching = 0
  pathsToSearch = []

  searchPath = (filePath) ->
    pathsSearching++
    searcher.searchPath regex, filePath, ->
      pathCount--
      pathsSearching--
      checkIfFinished()

  searchNextPath = ->
    if pathsSearching < MAX_CONCURRENT_SEARCH and pathsToSearch.length
      searchPath(pathsToSearch.pop())

  maybeSearchPath = (filePath) =>
    pathCount++
    if pathsSearching < MAX_CONCURRENT_SEARCH
      searchPath(filePath)
    else
      pathsToSearch.push(filePath)

  onFinishedScanning = ->
    finishedScanning = true
    checkIfFinished()

  checkIfFinished = ->
    searchNextPath()
    finish() if finishedScanning and pathCount == 0

  finish = ->
    scanner.removeListener 'path-found', maybeSearchPath
    scanner.removeListener 'finished-scanning', onFinishedScanning
    doneCallback()

  scanner.on 'path-found', maybeSearchPath
  scanner.on 'finished-scanning', onFinishedScanning
  scanner.scan()

singleProcessSearchMain = (options) ->
  searcher = new PathSearcher()
  scanner = new PathScanner(options.pathToScan, options)
  console.time 'Single Process Search'

  count = 0
  resultCount = 0
  pathCount = 0

  scanner.on 'path-found', (path) ->
    pathCount++

  searcher.on 'results-found', (results) ->
    count++
    console.log results.path if options.verbose

    for result in results.results
      resultCount++
      if options.verbose
        console.log '  ', result.lineNumber + ":", result.matchText, 'at', result.range

  singleProcessSearch buildRegex(options.search), scanner, searcher, ->
    console.timeEnd 'Single Process Search'
    console.log "#{resultCount} matches in #{count} files. Searched #{pathCount} files"

singleProcessScanMain = (options) ->
  scanner = new PathScanner(options.pathToScan, options)
  console.time 'Single Process Scan'

  count = 0
  scanner.on 'path-found', (path) ->
    count++
    console.log path if options.verbose

  scanner.on 'finished-scanning', ->
    console.timeEnd 'Single Process Scan'
    console.log "Found #{count} paths"

  scanner.scan()


###
Multiprocess. Really broken
###

makeTask = (fn) ->
  "(#{fn.toString()})();"

fork = (task, env) ->
  child_process = require 'child_process'
  args = [task, '--harmony_collections']
  child_process.fork '--eval', args, {env, cwd: __dirname, silent: true}

kill = (childProcess) ->
  childProcess.removeAllListeners()
  childProcess.kill()
  null

multiProcessScan = ->
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

multiProcessSearch = ->
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

multiProcessSearchMain = (options) ->
  options.pathToScan = path.resolve(options.pathToScan)
  env = _.extend({}, process.env, options)

  START_CHAR = String.fromCharCode(1)
  END_CHAR = String.fromCharCode(4)
  STOP_CHAR = String.fromCharCode(0)

  scanTask = makeTask(multiProcessScan)
  searchTask = makeTask(multiProcessSearch)

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
        resultCount += results.results.length
        console.log "#{results.results.length} matches in #{results.path}" if options.verbose

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

buildRegex = (pattern) ->
  new RegExp(pattern, 'gi')

main = ->
  argParser = new ArgumentParser
    version: require('../package.json').version
    addHelp: true
    description: 'Search a directory for something'

  argParser.addArgument([ '-m', '--multiprocess' ], action: 'storeTrue')
  argParser.addArgument([ '-e', '--excludeVcsIgnores' ], action: 'storeTrue')
  argParser.addArgument([ '-o', '--verbose' ], action: 'storeTrue')
  argParser.addArgument([ '-s', '--search' ])
  argParser.addArgument(['pathToScan'])

  options = argParser.parseArgs()

  if options.search
    if options.multiprocess
      multiProcessSearchMain(options)
    else
      singleProcessSearchMain(options)
  else
    singleProcessScanMain(options)

module.exports = {main, singleProcessSearch, PathSearcher, PathScanner, multiProcessSearchMain}
