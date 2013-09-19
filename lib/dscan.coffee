_ = require 'underscore'
{ArgumentParser} = require 'argparse'
PathSearcher = require './path-searcher'
PathScanner = require './path-scanner'
path = require "path"

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
multiprocess!
###

multiProcessScan = ->
  require("coffee-script");
  PathScanner = require './path-scanner.coffee'

  PATHS_TO_SEARCH = 50

  emit = (event, arg) ->
    process.send({event, arg})

  options =
    pathToScan: process.env.pathToScan
    showHidden: process.env.showHidden == 'true'
    excludeVcsIgnores: process.env.excludeVcsIgnores == 'true'

  scanner = new PathScanner(options.pathToScan, options)

  paths = []
  scanner.on 'path-found', (path) ->
    paths.push(path)
    if paths.length == PATHS_TO_SEARCH
      emit('paths-found', paths)
      paths = []

  scanner.on 'finished-scanning', ->
    emit('paths-found', paths) if paths.length
    emit('finished')

  scanner.scan()

multiProcessSearch = ->
  require("coffee-script");
  PathSearcher = require './path-searcher.coffee'

  emit = (event, arg, id) ->
    process.send({event, arg, id})

  options = process.env
  searcher = new PathSearcher()
  regex = new RegExp(options.search, 'gi')

  process.on 'message', ({event, arg, id}) ->
    if event == 'search'
      console.log "#{id} SPROCESS: searching #{arg.length}"
      searcher.searchPaths regex, arg, (results) ->
        console.log "#{id} SPROCESS: finished"
        emit('finished-search', results, id)

flush = (childProcess) ->
  childProcess.stdio.forEach (stream, fd, stdio) ->
    return if !stream || !stream.readable || stream._consuming || stream._readableState.flowing
    stream.resume()

fork = (task, env) ->
  child_process = require 'child_process'
  args = [task, '--harmony_collections']
  child_process.fork '--eval', args, {env, cwd: __dirname}

kill = (childProcess) ->
  childProcess.removeAllListeners()
  childProcess.kill()

multiProcessSearchMain = (options) ->
  options.pathToScan = path.resolve(options.pathToScan)
  env = _.extend({}, process.env, options)

  makeTask = (fn) ->
    "(#{fn.toString()})();"

  scanTask = makeTask(multiProcessScan)
  searchTask = makeTask(multiProcessSearch)

  console.time 'Multi Process Scan'

  ids = 0
  scanFinished = false
  searches = 0

  scanProcess = fork(scanTask, env)
  searchProcess = fork(searchTask, env)

  search = (paths) ->
    searches++
    id = ids++
    console.log "#{id} searching #{paths.length} paths"
    searchProcess.send({event: 'search', arg: paths, id})
    flush(searchProcess)

  scanProcess.on 'message', ({event, arg}) ->
    if event == 'paths-found'
      search(arg)

    else if event == 'finished'
      kill(scanProcess)
      console.log 'Scan done'
      scanFinished = true

      console.log searches
      if searches == 0
        console.log searches
        kill(searchProcess)
        console.timeEnd 'Multi Process Scan'
        console.log 'done, prolly'

  searchProcess.on 'drain', ->
    console.log 'drain!', arguments
  searchProcess.on 'error', ->
    console.log 'ERROR', arguments
  searchProcess.on 'message', ({event, arg, id}) ->
    if event == 'finished-search'
      console.log "#{id} searching done"
      searches--

      # if arg
      #   for result in arg
      #     console.log "#{result.results.length} in #{result.path}"

      if scanFinished and searches == 0
        kill(searchProcess)
        console.timeEnd 'Multi Process Scan'
        console.log 'done?'


buildRegex = (pattern) ->
  new RegExp(pattern, 'gi')

main = ->
  argParser = new ArgumentParser
    version: '0.0.1'
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

module.exports = {main, singleProcessSearch, PathSearcher, PathScanner}
