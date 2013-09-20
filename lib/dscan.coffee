_ = require 'underscore'
{ArgumentParser} = require 'argparse'
PathSearcher = require './path-searcher'
PathScanner = require './path-scanner'
path = require "path"

singleProcessSearch = require('./single-process-search').search
singleProcessScanMain = require('./single-process-search').scanMain
singleProcessSearchMain = require('./single-process-search').searchMain

###
This CLI is mainly for benchmarking. While there may be useful data output to
the console, it will probably change. The options will probably change as
well.
###
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
      require('./multi-process-search').searchMain(options)
    else
      singleProcessSearchMain(options)
  else
    singleProcessScanMain(options)

module.exports = {main, singleProcessSearch, PathSearcher, PathScanner}
