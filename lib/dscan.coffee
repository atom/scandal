{ArgumentParser} = require 'argparse'
PathSearcher = require './path-searcher'
PathScanner = require './path-scanner'

MAX_CONCURRENT_SEARCH = 20

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
    singleProcessSearchMain(options)
  else
    singleProcessScanMain(options)

module.exports = main
