{ArgumentParser} = require 'argparse'
PathSearcher = require './path-searcher'
PathScanner = require './path-scanner'
PathReplacer = require './path-replacer'
path = require "path"

SingleProcess = require('./single-process-search')
{search, replace} = SingleProcess
singleProcessScanMain = SingleProcess.scanMain
singleProcessSearchMain = SingleProcess.searchMain
singleProcessReplaceMain = SingleProcess.replaceMain

###
This CLI is mainly for benchmarking. While there may be useful data output to
the console, it will probably change. The options will probably change as
well.
###
main = ->
  argParser = new ArgumentParser
    version: require('../package.json').version
    addHelp: true
    description: 'List paths, search, and replace in a directory'

  argParser.addArgument([ '-e', '--excludeVcsIgnores' ], action: 'storeTrue')
  argParser.addArgument([ '-o', '--verbose' ], action: 'storeTrue')
  argParser.addArgument([ '-d', '--dryReplace' ], action: 'storeTrue')
  argParser.addArgument([ '-s', '--search' ])
  argParser.addArgument([ '-r', '--replace' ])
  argParser.addArgument(['pathToScan'])

  options = argParser.parseArgs()

  if options.search and options.replace
    singleProcessReplaceMain(options)
  else if options.search
    singleProcessSearchMain(options)
  else
    singleProcessScanMain(options)

module.exports = {main, search, replace, PathSearcher, PathScanner, PathReplacer}
