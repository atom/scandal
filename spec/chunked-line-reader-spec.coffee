fs = require 'fs'
os = require 'os'
path = require 'path'
ChunkedLineReader = require '../src/chunked-line-reader'

describe "ChunkedLineReader", ->
  [rootPath, chunkSize] = []

  beforeEach ->
    chunkSize = ChunkedLineReader.CHUNK_SIZE
    ChunkedLineReader.CHUNK_SIZE = 10

  afterEach ->
    ChunkedLineReader.CHUNK_SIZE = chunkSize
    ChunkedLineReader.chunkedBuffer = null

  it "works with no newline at the end", ->
    rootPath = fs.realpathSync("spec/fixtures/many-files/sample.js")
    reader = new ChunkedLineReader(rootPath)
    reader.on 'end', endHandler = jasmine.createSpy('end handler')

    allLines = []
    reader.on 'data', (chunk) ->
      allLines = allLines.concat(chunk.toString().split(os.EOL))

    waitsFor ->
      endHandler.callCount > 0

    runs ->
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

  it "works with newline at the end", ->
    rootPath = fs.realpathSync("spec/fixtures/many-files/sample-end-newline.js")
    reader = new ChunkedLineReader(rootPath)
    reader.on 'end', endHandler = jasmine.createSpy('end handler')

    allLines = []
    reader.on 'data', (chunk) ->
      allLines = allLines.concat(chunk.toString().split(os.EOL))

    waitsFor ->
      endHandler.callCount > 0

    runs ->
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
        ''
      ]

      expect(allLines.length).toEqual sample.length
      for line, i in allLines
        expect(line).toEqual sample[i]

  it "works with windows newlines at the end", ->
    rootPath = fs.realpathSync("spec/fixtures/many-files/sample-with-windows-line-endings.js")

    reader = new ChunkedLineReader(rootPath)
    reader.on 'end', endHandler = jasmine.createSpy('end handler')

    allLines = []
    reader.on 'data', (chunk) ->
      allLines = allLines.concat(chunk.toString().split('\r\n'))

    waitsFor ->
      endHandler.callCount > 0

    runs ->
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
