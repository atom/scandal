PathSearcher = require './path-searcher'
PathScanner = require './path-scanner'
PathReplacer = require './path-replacer'
ChunkedScanner = require './chunked-scanner'

###
Single Process
###

globalizeRegex = (regex) ->
  if not regex.global
    flags = "g"
    flags += "i" if regex.ignoreCase
    flags += "m" if regex.multiline
    regex = new RegExp(regex.source, flags)
  regex


## Searching

search = (regex, scanner, searcher, doneCallback) ->
  regex = globalizeRegex(regex)
  execPathFn = (filePath, callback) ->
    searcher.searchPath(regex, filePath, callback)

  new ChunkedScanner(scanner, execPathFn).execute(doneCallback)

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


## Replacing

replace = (regex, replacement, scanner, replacer, doneCallback) ->
  regex = globalizeRegex(regex)
  execPathFn = (filePath, callback) ->
    replacer.replacePath(regex, replacement, filePath, callback)

  new ChunkedScanner(scanner, execPathFn).execute(doneCallback)

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

  replace regex, options.replace, scanner, replacer, ->
    console.timeEnd 'Single Process Search + Replace'
    console.log "Replaced #{totalReplacements} matches in #{totalFiles} files"


## Scanning

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

module.exports = {scanMain, searchMain, replaceMain, search, replace}
