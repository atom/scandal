fs = require 'fs'
path = require 'path'
readFile = require '../lib/read-file'

describe "readFile", ->
  [rootPath, chunkSize] = []

  beforeEach ->
    chunkSize = readFile.CHUNK_SIZE
    readFile.CHUNK_SIZE = 10
    rootPath = fs.realpathSync("spec/fixtures/many-files/sample.js")

  afterEach ->
    readFile.CHUNK_SIZE = chunkSize

  it "works", ->
    allLines = []
    readFile rootPath, (lines, lineNumber) ->
      allLines = allLines.concat(lines)
      console.log lines, lineNumber

    sample = [
      'var quicksort = function () {'
      '  var sort = function(items) {'
      '    if (items.length <= 1) return items;'
      '    var pivot = items.shift(), current, left = [], right = [];'
      '    while(items.length > 0) {'
      '      current = items.shift();'
      '      current < pivot ? left.push(current) : right.push(current);'
      '    }'
      '    return sort(left).concat(pivot).concat(sort(right));'
      '  };'
      ''
      '  return sort(Array.apply(this, arguments));'
      '};'
    ]

    expect(allLines.length).toEqual sample.length
    for line, i in allLines
      expect(line).toEqual sample[i]
