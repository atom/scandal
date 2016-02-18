# scandal - Scandalous directory scanning and searching

[![Build Status](https://travis-ci.org/atom/scandal.svg?branch=master)](https://travis-ci.org/atom/scandal)
[![Deps](https://david-dm.org/atom/scandal.svg)](https://david-dm.org/atom/scandal)

`scandal` provides two utilities:

* Scanning a directory for paths matching a set of glob inclusions or exclusions. For example, you want to find a list of paths to search that match a certain pattern, but are not ignored by the `.gitignore`.

* Searching a list of paths for a regex. For example, you have a list of paths, you want to find all instances of `/text/gi`.

Unsurprisingly, these two things can be combined to scan and search a directory.

## Goals

It is written to be simple, flexible and efficient. Scandal does the minimum.

We want to provide modules to combine in any way you'd like. Want to scan in one process and search in another? You can do that.

To be clear, scandal is not a CLI. It can be used from the terminal, but in practice the CLI only used for benchmarking.

## Objects

`scandal` provides two main modules: `PathScanner` and `PathSearcher`.

### PathScanner

Usage is simple:

```coffeescript
{PathScanner} = require 'scandal'
scanner = new PathScanner('/Users/me/myDopeProject', options)

scanner.on 'path-found', (path) ->
  console.log(path)

scanner.on 'finished-scanning', ->
  console.log('All done!')

scanner.scan()
```

`PathScanner` keeps no state. You must consume paths via the `path-found` event.

#### options

* _excludeVcsIgnores_ - bool; default false; true to exclude paths defined in a .gitignore. Uses [git-utils](http://atom.github.io/git-utils/) to check ignored files.
* _inclusions_ - list of patterns to include. Uses [minimatch](https://github.com/isaacs/minimatch) with a couple additions: `['dirname']` and `['dirname/']` will match all paths in direcotry `dirname`
* _exclusions_ - list of patterns to exclude. Same matcher as `inclusions`.
* _includeHidden_ - bool; default false; true includes hidden files.

### PathSearcher

```coffeescript
{PathSearcher} = require 'scandal'
searcher = new PathSearcher()

# You can subscribe to a `results-found` event
searcher.on 'results-found', (result) ->
  # result will contain all the matches for a single path
  console.log("Single Path's Results", result)

# Search a list of paths
searcher.searchPaths /text/gi, ['/Some/path', ...], (results) ->
  console.log('Done Searching', results)

# Search a single path
searcher.searchPath /text/gi, '/Some/path', (result) ->
  console.log('Done Searching', result)
```

Results from line 10 (1 based) are in the following format.

```json
{
  "path": "/Some/path",
  "matches": {
    "matchText": "Text",
    "lineText": "Text in this file!",
    "lineTextOffset": 0,
    "range": [[9, 0], [9, 4]]
  }
}
```

Like the `PathScanner` the searcher keeps no state. You need to consume results via the done callbacks or event.

File reading is fast and memory efficient. It reads in 10k chunks and writes over each previous chunk. Small object creation is kept to a minimum during the read to make light use of the GC.

### PathFilter

A third object, `PathFilter` is available, but intended for use by the `PathScanner`.

## Using the scanner and searcher together

If you dont want to think about combining the `PathScanner` and `PathSearcher` in your own way, a `search` function is provided.

```coffeescript
{search, PathScanner, PathSearcher} = require 'scandal'

path = '/path/to/search'
scanner = new PathScanner(path, excludeVcsIgnores: true)
searcher = new PathSearcher()

searcher.on 'results-found' (result) ->
  # do something rad with the result!

name = "Search #{path}"
console.time name
console.log name
search /text/ig, scanner, searcher, ->
  console.timeEnd name
```
