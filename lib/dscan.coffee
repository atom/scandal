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
  done = ->
    process.stdout.write(STOP_CHAR+'\n')
    process.send(event: 'finished')

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
    done()

  scanner.scan()

multiProcessSearch = ->
  require("coffee-script");
  PathSearcher = require './path-searcher.coffee'

  searches = 0

  START_CHAR = String.fromCharCode(1)
  END_CHAR = String.fromCharCode(4)

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

  offset = 0
  # This is terrible and unreliable and sometimes infinite loops. From:
  # https://github.com/substack/stream-handbook#consuming-a-readable-stream
  readLine = (stdin) ->
    buf = stdin.read()
    return null unless buf

    while offset < buf.length
      if buf[offset] == 0x0a
        data = buf.slice(0, offset).toString()
        buf = buf.slice(offset + 1)
        offset = 0
        stdin.unshift(buf)
        return data
      offset++

    stdin.unshift(buf);
    null

  process.stdin.on 'readable', ->
    data = readLine(process.stdin)
    return unless data

    paths = JSON.parse(data)

    emitStart()
    searcher.searchPaths regex, paths, (results) ->
      emitResults(results)

multiProcessSearchMain = (options) ->
  options.pathToScan = path.resolve(options.pathToScan)
  env = _.extend({}, process.env, options)

  START_CHAR = String.fromCharCode(1)
  END_CHAR = String.fromCharCode(4)

  scanTask = makeTask(multiProcessScan)
  searchTask = makeTask(multiProcessSearch)

  console.time 'Multi Process Scan'

  searches = 0
  finished = false
  scanFinished = false

  resultCount = 0
  pathCount = 0

  scanProcess = fork(scanTask, env)
  searchProcess = fork(searchTask, env)

  searchProcess.stdin.setEncoding = 'utf-8';
  scanProcess.stdout.on 'data', (data) ->
    searchProcess.stdin.write(data)

  searchProcess.stderr.pipe(process.stderr)

  searchProcess.stdout.pipe(split()).on 'data', (line) ->
    if line[0] == START_CHAR
      console.log "search start"
      searches++
    else if line[0] == END_CHAR
      searches--
      console.log "search end #{searches}"
    else if line and line.length
      results = JSON.parse(line)
      if results
        pathCount++
        resultCount += results.results.length
        console.log "#{results.results.length} matches in #{results.path}"

    maybeEnd()

  scanProcess.on 'message', ({event, arg}) ->
    # This is a race condition with scanProcess.stdout 'data'. The finished message should be a
    # null char in stdout or something. Sometimes this happens before the last
    # stdout event
    if event == 'finished'
      scanFinished = true
      console.log 'Scan done'

      maybeEnd()

  maybeEnd = ->
    return if finished
    setTimeout ->
      if scanFinished and searches == 0
        kill(scanProcess)
        kill(searchProcess)
        end()
    , 10

  end = ->
    finished = true
    console.timeEnd 'Multi Process Scan'
    console.log "#{resultCount} matches in #{pathCount} files"

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

module.exports = {main, singleProcessSearch, PathSearcher, PathScanner, multiProcessSearchMain}
