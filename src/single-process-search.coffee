PathSearcher = require './path-searcher'
PathScanner = require './path-scanner'
PathReplacer = require './path-replacer'

MAX_CONCURRENT_SEARCH = 20

###
Single Process
###

search = (regex, scanner, searcher, doneCallback) ->
  finishedScanning = false
  pathCount = 0
  pathsSearching = 0
  pathQueue = []

  globalizeRegex = (regex) ->
    if not regex.global
      flags = "g"
      flags += "i" if regex.ignoreCase
      flags += "m" if regex.multiline
      regex = new RegExp(regex.source, flags)
    regex

  searchPath = (filePath) ->
    pathsSearching++
    searcher.searchPath regex, filePath, ->
      pathCount--
      pathsSearching--
      checkIfFinished()

  searchNextPath = ->
    if pathsSearching < MAX_CONCURRENT_SEARCH and pathQueue.length
      searchPath(pathQueue.shift())

  maybeSearchPath = (filePath) =>
    pathCount++
    if pathsSearching < MAX_CONCURRENT_SEARCH
      searchPath(filePath)
    else
      pathQueue.push(filePath)

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

  regex = globalizeRegex(regex)
  scanner.on 'path-found', maybeSearchPath
  scanner.on 'finished-scanning', onFinishedScanning
  scanner.scan()

searchMain = (options) ->
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
    console.log results.filePath if options.verbose

    for match in results.matches
      resultCount++
      if options.verbose
        console.log '  ', match.range[0][0] + ":", match.matchText, 'at', match.range

  search new RegExp(options.search, 'gi'), scanner, searcher, ->
    console.timeEnd 'Single Process Search'
    console.log "#{resultCount} matches in #{count} files. Searched #{pathCount} files"

replaceMain = (options) ->
  scanner = new PathScanner(options.pathToScan, options)
  replacer = new PathReplacer({dryReplace: options.dryReplace})
  regex = new RegExp(options.search, 'gi')

  console.time 'Single Process Search + Replace'

  paths = []
  scanner.on 'path-found', (p) ->
    paths.push p

  totalReplacements = 0
  totalFiles = 0
  replacer.on 'path-replaced', ({filePath, replacements}) ->
    totalFiles++
    totalReplacements += replacements
    console.log('Replaced', replacements, 'in', filePath) if options.verbose

  scanner.on 'finished-scanning', ->
    replacer.replacePaths regex, options.replace, paths, ->
      console.timeEnd 'Single Process Search + Replace'
      console.log "Replaced #{totalReplacements} matches in #{totalFiles} files"

  scanner.scan()

scanMain = (options) ->
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

module.exports = {scanMain, searchMain, replaceMain, search}
