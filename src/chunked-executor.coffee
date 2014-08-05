MAX_CONCURRENT_CHUNK = 20

# Public: {ChunkedExecutor} will execute on an {Array} paths in a pathQueue only
# running a max of 20 of them concurrently.
#
# ## Examples
#
#   ```coffee
#   paths = ['/path/to/somefile.coffee', '/path/to/someotherfile.coffee']
#
#   searchPath = (filePath, callback) =>
#     # Do something with the path here...
#     callback()
#
#   executor = new ChunkedExecutor(paths, searchPath).execute ->
#     console.log 'done!'
#
#   # Now you can push more on the queue
#   executor.push '/path/to/lastone.coffee'
#   ```
module.exports =
class ChunkedExecutor

  # Construct a {ChunkedExecutor}
  #
  # * `pathQueue` {Array} of paths
  # * `execPathFn` {Function} that will execute on each path
  #   * `filePath` {String} path to a file from the `pathQueue`
  #   * `callback` {Function} callback your `execPathFn` must call when finished
  #      executing on a path
  constructor: (pathQueue, @execPathFn) ->
    @pathQueue = (p for p in pathQueue) # copy the original
    @pathCount = pathQueue.length
    @pathsRunning = 0

  ###
  Section: Execution
  ###

  # Public: Begin execution of the `pathQueue`
  #
  # * `doneCallback` {Function} callback that will be called when execution is finished.
  execute: (@doneCallback) ->
    for i in [0..MAX_CONCURRENT_CHUNK]
      @executeNextPathIfPossible()
    return

  # Public: Push a new path on the queue
  #
  # May or may not execute immediately.
  #
  # * `filePath` {String} path to a file
  push: (filePath) =>
    @pathCount++
    if @pathsRunning < MAX_CONCURRENT_CHUNK
      @executePath(filePath)
    else
      @pathQueue.push(filePath)

  ###
  Section: Lifecycle Methods
  ###

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
