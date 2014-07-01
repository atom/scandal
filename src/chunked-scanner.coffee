ChunkedExecutor = require './chunked-executor'

module.exports =
class ChunkedScanner extends ChunkedExecutor
  constructor: (@scanner, execPathFn) ->
    @finishedScanning = false
    super([], execPathFn)

  execute: (doneCallback) ->
    super(doneCallback)

    @scanner.on 'path-found', @push
    @scanner.on 'finished-scanning', @onFinishedScanning
    @scanner.scan()

  onFinishedScanning: =>
    @finishedScanning = true
    @checkIfFinished()

  checkIfFinished: ->
    return false unless @finishedScanning
    isFinished = super()

    if isFinished
      @scanner.removeListener 'path-found', @path
      @scanner.removeListener 'finished-scanning', @onFinishedScanning

    isFinished
