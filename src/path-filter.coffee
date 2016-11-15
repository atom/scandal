{Minimatch} = require 'minimatch'
GitUtils = require 'git-utils'
path = require 'path'
fs = require 'fs'

# Public: {PathFilter} makes testing for path inclusion easy.
module.exports =
class PathFilter
  @MINIMATCH_OPTIONS: { matchBase: true, dot: true }

  @escapeRegExp: (str) ->
    str.replace(/([\/'*+?|()\[\]{}.\^$])/g, '\\$1')

  # Public: Construct a {PathFilter}
  #
  # * `rootPath` {String} top level directory to scan. eg. `/Users/ben/somedir`
  # * `options` {Object} options hash
  #   * `excludeVcsIgnores` {Boolean}; default false; true to exclude paths
  #      defined in a .gitignore. Uses git-utils to check ignred files.
  #   * `inclusions` {Array} of patterns to include. Uses minimatch with a couple
  #      additions: `['dirname']` and `['dirname/']` will match all paths in
  #      directory dirname.
  #   * `exclusions` {Array} of patterns to exclude. Same matcher as inclusions.
  #   * `globalExclusions` {Array} of patterns to exclude. These patterns can be
  #      overridden by `inclusions` if the inclusion is a duplicate or a
  #      subdirectory of the exclusion. Same matcher as inclusions.
  #   * `includeHidden` {Boolean} default false; true includes hidden files
  constructor: (@rootPath, options={}) ->
    {includeHidden, excludeVcsIgnores} = options
    {inclusions, exclusions, globalExclusions} = @sanitizePaths(options)

    @inclusions = @createMatchers(inclusions, {deepMatch: true})
    @exclusions = @createMatchers(exclusions, {deepMatch: false})
    @globalExclusions = @createMatchers(globalExclusions, {deepMatch: false, disallowDuplicatesFrom: @inclusions})

    @repo = GitUtils.open(@rootPath) if excludeVcsIgnores

    @excludeHidden() if includeHidden != true

  ###
  Section: Testing For Acceptance
  ###

  # Public: Test if the `filepath` is accepted as a file based on the
  # constructing options.
  #
  # * `filepath` {String} path to a file. File should be a file and should exist
  #
  # Returns {Boolean} true if the file is accepted
  isFileAccepted: (filepath) ->
    @isDirectoryAccepted(filepath) and
      !@isPathExcluded('file', filepath) and
      @isPathIncluded('file', filepath) and
      !@isPathGloballyExcluded('file', filepath)

  # Public: Test if the `filepath` is accepted as a directory based on the
  # constructing options.
  #
  # * `filepath` {String} path to a directory. File should be a file or directory
  #   and should exist
  #
  # Returns {Boolean} true if the directory is accepted
  isDirectoryAccepted: (filepath) ->
    return false if @isPathExcluded('directory', filepath) is true

    matchingInclusions = @getMatchingItems(@inclusions['directory'], filepath)

    # Matching global exclusions will be overriden if there is a matching
    # inclusion for a subdirectory of the exclusion.
    # For example: if node_modules is globally excluded but mode_modules/foo is
    # explicitly included, then the global exclusion is overridden for
    # node_modules/foo
    matchingGlobalExclusions = @overrideGlobalExclusions(
      @getMatchingItems(@globalExclusions['directory'], filepath), matchingInclusions)

    # Don't accept if there's a matching global exclusion
    return false if matchingGlobalExclusions.length

    # A matching explicit local inclusion will override any Git exclusions
    return true if matchingInclusions.length

    # Don't accept if there Were inclusions specified that didn't match
    return false if @inclusions['directory']?.length

    # Finally, check for Git exclusions
    !@isPathExcludedByGit(filepath)


  ###
  Section: Private Methods
  ###

  isPathIncluded: (fileOrDirectory, filepath) ->
    return true unless @inclusions[fileOrDirectory]?.length
    return @getMatchingItems(@inclusions[fileOrDirectory], filepath,
                             stopAfterFirst=true)?.length > 0

  isPathExcluded: (fileOrDirectory, filepath) ->
    return @getMatchingItems(@exclusions[fileOrDirectory], filepath,
                             stopAfterFirst=true)?.length > 0

  isPathGloballyExcluded: (fileOrDirectory, filepath) ->
    return @getMatchingItems(@globalExclusions[fileOrDirectory], filepath,
                             stopAfterFirst=true)?.length > 0

  # Given an array of `matchers`, return an array containing only those that
  # match `filepath`.
  getMatchingItems: (matchers, filepath, stopAfterFirst=false) ->
    index = matchers.length
    result = []
    while index--
      if matchers[index].match(filepath)
        result.push(matchers[index])
        return result if stopAfterFirst
    return result

  isPathExcludedByGit: (filepath) ->
    @repo?.isIgnored(@repo.relativize(path.join(@rootPath, filepath)))

  # Given an array of `globalExclusions`, filter out any which have an
  # `inclusion` defined for a subdirectory
  overrideGlobalExclusions: (globalExclusions, inclusions) ->
    result = []
    exclusionIndex = globalExclusions.length
    while exclusionIndex--
      inclusionIndex = inclusions.length
      requiresOverride = false

      # Check if an inclusion is specified for a subdirectory of this globalExclusion
      while inclusionIndex--
        if @isSubpathMatcher(globalExclusions[exclusionIndex], inclusions[inclusionIndex])
          requiresOverride = true

      result.push(globalExclusions[exclusionIndex]) if !requiresOverride
    return result

  # Returns true if the `child` matcher is a subdirectory of the `parent` matcher
  isSubpathMatcher: (parent, child) ->
    # Strip off trailing wildcards from the parent pattern
    parentPattern = parent.pattern
    directoryPattern = ///
      #{'\\'+path.sep}\*$|   # Matcher ends with a separator followed by *
      #{'\\'+path.sep}\*\*$  # Matcher ends with a separator followed by **
    ///
    matchIndex = parentPattern.search(directoryPattern)
    parentPattern = parentPattern.slice(0, matchIndex) if matchIndex > -1

    return child.pattern.substr(0, parentPattern.length) == parentPattern

  sanitizePaths: (options) ->
    return options unless options.inclusions?.length
    inclusions = []
    for includedPath in options.inclusions
      if includedPath and includedPath[0] is '!'
        options.exclusions ?= []
        options.exclusions.push(includedPath.slice(1))
      else if includedPath
        inclusions.push(includedPath)
    options.inclusions = inclusions
    options

  excludeHidden: ->
    matcher = new Minimatch(".*", PathFilter.MINIMATCH_OPTIONS)
    @exclusions.file.push(matcher)
    @exclusions.directory.push(matcher)

  createMatchers: (patterns=[], {deepMatch, disallowDuplicatesFrom}={}) ->
    addFileMatcher = (matchers, pattern) =>
      return if disallowDuplicatesFrom? and @containsPattern(disallowDuplicatesFrom, 'file', pattern)
      matchers.file.push(new Minimatch(pattern, PathFilter.MINIMATCH_OPTIONS))

    addDirectoryMatcher = (matchers, pattern, deepMatch) =>
      # It is important that we keep two permutations of directory patterns:
      #
      # * 'directory/anotherdir'
      # * 'directory/anotherdir/**'
      #
      # Minimatch will return false if we were to match 'directory/anotherdir'
      # against pattern 'directory/anotherdir/*'. And it will return false
      # matching 'directory/anotherdir/file.txt' against pattern
      # 'directory/anotherdir'.

      if pattern[pattern.length - 1] == path.sep
        pattern += '**'

      # When the user specifies to include a nested directory, we need to
      # specify matchers up to the nested directory
      #
      # * User specifies 'some/directory/anotherdir/**'
      # * We need to break it up into multiple matchers
      #   * 'some'
      #   * 'some/directory'
      #
      # Otherwise, we'll hit the 'some' directory, and if there is no matcher,
      # it'll fail and have no chance at hitting the
      # 'some/directory/anotherdir/**' matcher the user originally specified.
      if deepMatch
        paths = pattern.split(path.sep)
        lastIndex = paths.length - 2
        lastIndex-- if paths[paths.length - 1] in ['*', '**']

        if lastIndex >= 0
          deepPath = ''
          for i in [0..lastIndex]
            deepPath = path.join(deepPath, paths[i])
            addDirectoryMatcher(matchers, deepPath)

      directoryPattern = ///
        #{'\\'+path.sep}\*$|   # Matcher ends with a separator followed by *
        #{'\\'+path.sep}\*\*$  # Matcher ends with a separator followed by **
      ///
      matchIndex = pattern.search(directoryPattern)
      addDirectoryMatcher(matchers, pattern.slice(0, matchIndex)) if matchIndex > -1

      return if disallowDuplicatesFrom? and @containsPattern(disallowDuplicatesFrom, 'directory', pattern)
      matchers.directory.push(new Minimatch(pattern, PathFilter.MINIMATCH_OPTIONS))

    pattern = null
    matchers =
      file: [],
      directory: []

    r = patterns.length
    while (r--)
      pattern = patterns[r].trim()
      continue if (pattern.length == 0 || pattern[0] == '#')

      endsWithSeparatorOrStar = ///
        #{'\\'+path.sep}$|   # Pattern ends in a separator
        #{'\\'+path.sep}\**$ # Pattern ends with a seperator followed by a *
      ///
      if endsWithSeparatorOrStar.test(pattern)
        # Is a dir if it ends in a '/' or '/*'
        addDirectoryMatcher(matchers, pattern, deepMatch)
      else if pattern.indexOf('*') < 0

        try
          # Try our best to check if it's a directory
          stat = fs.statSync(path.join(@rootPath, pattern))
        catch e
          stat = null

        if stat?.isFile()
          addFileMatcher(matchers, pattern)
        else
          addDirectoryMatcher(matchers, pattern + path.sep + '**', deepMatch)
      else
        addFileMatcher(matchers, pattern)

    matchers

  containsPattern: (matchers, fileOrDirectory, pattern) ->
    for matcher in matchers[fileOrDirectory]
      return true if matcher.pattern is pattern
    false
