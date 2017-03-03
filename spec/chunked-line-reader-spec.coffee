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

  it "emits an error when the file does not exist", ->
    dataHandler = jasmine.createSpy('data handler')

    reader = new ChunkedLineReader('/this-does-not-exist.js')
    reader.on 'end', endHandler = jasmine.createSpy('end handler')
    reader.on 'error', errorHandler = jasmine.createSpy('error handler')

    reader.on 'data', dataHandler

    waitsFor ->
      errorHandler.callCount > 0

    runs ->
      expect(errorHandler).toHaveBeenCalled()
      expect(endHandler).toHaveBeenCalled()
      expect(dataHandler).not.toHaveBeenCalled()

  it "works with no newline at the end", ->
    rootPath = fs.realpathSync(path.join("spec", "fixtures", "many-files", "sample.js"))
    reader = new ChunkedLineReader(rootPath)
    reader.on 'end', endHandler = jasmine.createSpy('end handler')

    allLines = []
    reader.on 'data', (chunk) ->
      line = chunk.toString().replace(/\r?\n?$/, '')
      allLines = allLines.concat(line.split(os.EOL))

    waitsFor ->
      endHandler.callCount > 0

    runs ->
      sample = [
        'var quicksort = function () {'
        '  var sort = function(items) {  # followed by a pretty long comment which is used to check the maxLineLength feature'
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
    rootPath = fs.realpathSync(path.join("spec", "fixtures", "many-files", "sample-end-newline.js"))
    reader = new ChunkedLineReader(rootPath)
    reader.on 'end', endHandler = jasmine.createSpy('end handler')

    allLines = []
    reader.on 'data', (chunk) ->
      line = chunk.toString().replace(/\r?\n?$/, '')
      allLines = allLines.concat(line.split(os.EOL))

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

  it "works with windows newlines at the end", ->
    rootPath = fs.realpathSync(path.join("spec", "fixtures", "many-files", "sample-with-windows-line-endings.js"))

    reader = new ChunkedLineReader(rootPath)
    reader.on 'end', endHandler = jasmine.createSpy('end handler')

    allLines = []
    reader.on 'data', (chunk) ->
      line = chunk.toString().replace(/\r?\n?$/, '')
      allLines = allLines.concat(line.split('\r\n'))

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

  it "works with multibyte characters in utf8", ->
    rootPath = fs.realpathSync(path.join("spec", "fixtures", "many-files", "file7_multibyte.txt"))
    reader = new ChunkedLineReader(rootPath)
    reader.on 'end', endHandler = jasmine.createSpy('end handler')

    allLines = []
    reader.on 'data', (chunk) ->
      line = chunk.toString().replace(/\r?\n?$/, '')
      allLines = allLines.concat(line.split(os.EOL))

    waitsFor ->
      endHandler.callCount > 0

    runs ->
      sampleText = fs.readFileSync(rootPath, encoding: 'utf8')
      sampleLines = sampleText.trim().split("\n")

      expect(reader.encoding).toBe 'utf8'
      expect(allLines.length).toEqual sampleLines.length
      for line, i in allLines
        expect(line).toEqual sampleLines[i]
