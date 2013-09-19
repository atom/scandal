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

singleProcessMain = (options) ->
  searcher = new PathSearcher()
  scanner = new PathScanner(options.pathToSearch, options)
  console.time 'Single Process Search'

  count = 0

  if options.verbose
    searcher.on 'results-found', (results) ->
      console.log results.path
      count++
      #for result in results.results
      #  console.log '  ', result.lineNumber + ":", result.matchText, 'at', result.range

  singleProcessSearch buildRegex(options.regex), scanner, searcher, ->
    console.timeEnd 'Single Process Search'
    console.log 'Searched', scanner.paths.length, '; found in', count

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
  argParser.addArgument(['regex'])
  argParser.addArgument(['pathToSearch'])

  options = argParser.parseArgs()

  singleProcessMain(options)

module.exports = main
