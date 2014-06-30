MAX_CONCURRENT_CHUNK = 20

module.exports =
class ChunkedExecutor
  constructor: (pathQueue, @execPathFn) ->
    @pathQueue = (p for p in pathQueue) # copy the original
    @pathCount = pathQueue.length
    @pathsRunning = 0

  execute: (@doneCallback) ->
    for i in [0..MAX_CONCURRENT_CHUNK]
      @executeNextPathIfPossible()
    return

  push: (filePath) =>
    @pathCount++
    if @pathsRunning < MAX_CONCURRENT_CHUNK
      @executePath(filePath)
    else
      @pathQueue.push(filePath)

  executeNextPathIfPossible: ->
    @executePath(@pathQueue.shift()) if @pathsRunning < MAX_CONCURRENT_CHUNK and @pathQueue.length

  executePath: (filePath) ->
    @pathsRunning++
    @execPathFn filePath, =>
      @pathCount--
      @pathsRunning--
      @checkIfFinished()

  checkIfFinished: ->
    @executeNextPathIfPossible()
    @doneCallback() if @pathCount == 0
