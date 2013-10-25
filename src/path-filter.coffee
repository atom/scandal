{Minimatch} = require 'minimatch'
GitUtils = require 'git-utils'

module.exports =
class PathFilter
  @MINIMATCH_OPTIONS: { matchBase: true, dot: true, flipNegate: true }

  @escapeRegExp: (str) ->
    str.replace(/([\/'*+?|()\[\]{}.\^$])/g, '\\$1')

  constructor: (rootPath, {inclusions, exclusions, includeHidden, excludeVcsIgnores}={}) ->
    @inclusions = @createMatchers(inclusions)
    @exclusions = @createMatchers(exclusions)

    @repo = GitUtils.open(rootPath) if excludeVcsIgnores

    @excludeHidden() if includeHidden != true

  isFileAccepted: (filepath) ->
    @isPathAccepted('directory', filepath) and @isPathAccepted('file', filepath)

  isDirectoryAccepted: (filepath) ->
    @isPathAccepted('directory', filepath)

  isPathAccepted: (fileOrDirectory, filepath) ->
    !@isPathIgnored(fileOrDirectory, filepath) && @isPathIncluded(fileOrDirectory, filepath)

  isPathIgnored: (fileOrDirectory, filepath) ->
    return true if @repo?.isIgnored(@repo.relativize(filepath))

    exclusions = @exclusions[fileOrDirectory]
    r = exclusions.length
    while r--
      return true if (exclusions[r].match(filepath))
    return false

  isPathIncluded: (fileOrDirectory, filepath) ->
    inclusions = @inclusions[fileOrDirectory]
    r = inclusions.length

    return true unless r

    while r--
      return true if inclusions[r].match(filepath)
    return false

  excludeHidden: ->
    matcher = new Minimatch(".*", PathFilter.MINIMATCH_OPTIONS)
    @exclusions.file.push(matcher)
    @exclusions.directory.push(matcher)

  createMatchers: (patterns=[]) ->
    addFileMatcher = (matchers, pattern) ->
      matchers.file.push(new Minimatch(pattern, PathFilter.MINIMATCH_OPTIONS))

    addDirectoryMatcher = (matchers, pattern) ->
      # It is important that we keep two permutations of directory patterns:
      #
      # * 'directory/anotherdir'
      # * 'directory/anotherdir/*'
      #
      # Minimatch will return false if we were to match 'directory/anotherdir'
      # against pattern 'directory/anotherdir/*'. And it will return false
      # matching 'directory/anotherdir/file.txt' against pattern
      # 'directory/anotherdir'.
      if pattern[pattern.length-1] == '/'
        pattern += '*'

      if /\/\*$/.test(pattern)
        addDirectoryMatcher(matchers, pattern.slice(0, pattern.length-2))

      matchers.directory.push(new Minimatch(pattern, PathFilter.MINIMATCH_OPTIONS))

    pattern = null
    matchers =
      file: [],
      directory: []

    r = patterns.length
    while (r--)
      pattern = patterns[r].trim()
      continue if (pattern.length == 0 || pattern[0] == '#')

      if (/\/$|\/\*$/.test(pattern))
        # Is a dir if it ends in a '/' or '/*'
        addDirectoryMatcher(matchers, pattern)
      else if (pattern.indexOf('.') < 1 && pattern.indexOf('*') < 0)
        # If no extension and no '*', assume it's a dir.
        # Also assumes hidden patterns like '.git' are directories.
        addDirectoryMatcher(matchers, pattern + '/*')
      else
        addFileMatcher(matchers, pattern)

    matchers
