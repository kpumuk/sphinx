# = client.rb - Sphinx Client API
#
# Author::    Dmytro Shteflyuk <mailto:kpumuk@kpumuk.info>.
# Copyright:: Copyright (c) 2006 — 2009 Dmytro Shteflyuk
# License::   Distributes under the same terms as Ruby
# Version::   0.9.10-r2043
# Website::   http://kpumuk.info/projects/ror-plugins/sphinx
#
# This library is distributed under the terms of the Ruby license.
# You can freely distribute/modify this library.

# ==Sphinx Client API
#
# The Sphinx Client API is used to communicate with <tt>searchd</tt>
# daemon and get search results from Sphinx.
#
# ===Usage
#
#   sphinx = Sphinx::Client.new
#   result = sphinx.Query('test')
#   ids = result['matches'].map { |match| match['id'] }.join(',')
#   posts = Post.find :all, :conditions => "id IN (#{ids})"
#
#   docs = posts.map(&:body)
#   excerpts = sphinx.BuildExcerpts(docs, 'index', 'test')

module Sphinx
  # :stopdoc:

  class SphinxError < StandardError; end
  class SphinxConnectError < SphinxError; end
  class SphinxResponseError < SphinxError; end
  class SphinxInternalError < SphinxError; end
  class SphinxTemporaryError < SphinxError; end
  class SphinxUnknownError < SphinxError; end

  # :startdoc:

  class Client
    # :stopdoc:

    # Known searchd commands

    # search command
    SEARCHD_COMMAND_SEARCH     = 0
    # excerpt command
    SEARCHD_COMMAND_EXCERPT    = 1
    # update command
    SEARCHD_COMMAND_UPDATE     = 2
    # keywords command
    SEARCHD_COMMAND_KEYWORDS   = 3
    # persist command
    SEARCHD_COMMAND_PERSIST    = 4
    # status command
    SEARCHD_COMMAND_STATUS     = 5
    # query command
    SEARCHD_COMMAND_QUERY      = 6
    # flushattrs command
    SEARCHD_COMMAND_FLUSHATTRS = 7

    # Current client-side command implementation versions

    # search command version
    VER_COMMAND_SEARCH     = 0x117
    # excerpt command version
    VER_COMMAND_EXCERPT    = 0x100
    # update command version
    VER_COMMAND_UPDATE     = 0x102
    # keywords command version
    VER_COMMAND_KEYWORDS   = 0x100
    # persist command version
    VER_COMMAND_PERSIST    = 0x000
    # status command version
    VER_COMMAND_STATUS     = 0x100
    # query command version
    VER_COMMAND_QUERY      = 0x100
    # flushattrs command version
    VER_COMMAND_FLUSHATTRS = 0x100

    # Known searchd status codes

    # general success, command-specific reply follows
    SEARCHD_OK      = 0
    # general failure, command-specific reply may follow
    SEARCHD_ERROR   = 1
    # temporaty failure, client should retry later
    SEARCHD_RETRY   = 2
    # general success, warning message and command-specific reply follow
    SEARCHD_WARNING = 3

    attr_reader :servers
    attr_reader :timeout
    attr_reader :retries
    attr_reader :reqtimeout
    attr_reader :reqretries

    # :startdoc:

    # Known match modes

    # match all query words
    SPH_MATCH_ALL       = 0
    # match any query word
    SPH_MATCH_ANY       = 1
    # match this exact phrase
    SPH_MATCH_PHRASE    = 2
    # match this boolean query
    SPH_MATCH_BOOLEAN   = 3
    # match this extended query
    SPH_MATCH_EXTENDED  = 4
    # match all document IDs w/o fulltext query, apply filters
    SPH_MATCH_FULLSCAN  = 5
    # extended engine V2 (TEMPORARY, WILL BE REMOVED IN 0.9.8-RELEASE)
    SPH_MATCH_EXTENDED2 = 6

    # Known ranking modes (ext2 only)

    # default mode, phrase proximity major factor and BM25 minor one
    SPH_RANK_PROXIMITY_BM25 = 0
    # statistical mode, BM25 ranking only (faster but worse quality)
    SPH_RANK_BM25           = 1
    # no ranking, all matches get a weight of 1
    SPH_RANK_NONE           = 2
    # simple word-count weighting, rank is a weighted sum of per-field keyword occurence counts
    SPH_RANK_WORDCOUNT      = 3
    # phrase proximity
    SPH_RANK_PROXIMITY      = 4
    # emulate old match-any weighting
    SPH_RANK_MATCHANY       = 5
    # sets bits where there were matches
    SPH_RANK_FIELDMASK      = 6
    # codename SPH04, phrase proximity + bm25 + head/exact boost
    SPH_RANK_SPH04          = 7

    # Known sort modes

    # sort by document relevance desc, then by date
    SPH_SORT_RELEVANCE     = 0
    # sort by document date desc, then by relevance desc
    SPH_SORT_ATTR_DESC     = 1
    # sort by document date asc, then by relevance desc
    SPH_SORT_ATTR_ASC      = 2
    # sort by time segments (hour/day/week/etc) desc, then by relevance desc
    SPH_SORT_TIME_SEGMENTS = 3
    # sort by SQL-like expression (eg. "@relevance DESC, price ASC, @id DESC")
    SPH_SORT_EXTENDED      = 4
    # sort by arithmetic expression in descending order (eg. "@id + max(@weight,1000)*boost + log(price)")
    SPH_SORT_EXPR          = 5

    # Known filter types

    # filter by integer values set
    SPH_FILTER_VALUES      = 0
    # filter by integer range
    SPH_FILTER_RANGE       = 1
    # filter by float range
    SPH_FILTER_FLOATRANGE  = 2

    # Known attribute types

    # this attr is just an integer
    SPH_ATTR_INTEGER   = 1
    # this attr is a timestamp
    SPH_ATTR_TIMESTAMP = 2
    # this attr is an ordinal string number (integer at search time,
    # specially handled at indexing time)
    SPH_ATTR_ORDINAL   = 3
    # this attr is a boolean bit field
    SPH_ATTR_BOOL      = 4
    # this attr is a float
    SPH_ATTR_FLOAT     = 5
    # signed 64-bit integer
    SPH_ATTR_BIGINT    = 6
    # string (binary; in-memory)
    SPH_ATTR_STRING    = 7
    # this attr has multiple values (0 or more)
    SPH_ATTR_MULTI     = 0x40000000

    # Known grouping functions

    # group by day
    SPH_GROUPBY_DAY      = 0
    # group by week
    SPH_GROUPBY_WEEK     = 1
    # group by month
    SPH_GROUPBY_MONTH    = 2
    # group by year
    SPH_GROUPBY_YEAR     = 3
    # group by attribute value
    SPH_GROUPBY_ATTR     = 4
    # group by sequential attrs pair
    SPH_GROUPBY_ATTRPAIR = 5

    # Constructs the <tt>Sphinx::Client</tt> object and sets options to their default values.
    def initialize
      # per-query settings
      @offset        = 0                       # how many records to seek from result-set start (default is 0)
      @limit         = 20                      # how many records to return from result-set starting at offset (default is 20)
      @mode          = SPH_MATCH_ALL           # query matching mode (default is SPH_MATCH_ALL)
      @weights       = []                      # per-field weights (default is 1 for all fields)
      @sort          = SPH_SORT_RELEVANCE      # match sorting mode (default is SPH_SORT_RELEVANCE)
      @sortby        = ''                      # attribute to sort by (defualt is "")
      @min_id        = 0                       # min ID to match (default is 0, which means no limit)
      @max_id        = 0                       # max ID to match (default is 0, which means no limit)
      @filters       = []                      # search filters
      @groupby       = ''                      # group-by attribute name
      @groupfunc     = SPH_GROUPBY_DAY         # function to pre-process group-by attribute value with
      @groupsort     = '@group desc'           # group-by sorting clause (to sort groups in result set with)
      @groupdistinct = ''                      # group-by count-distinct attribute
      @maxmatches    = 1000                    # max matches to retrieve
      @cutoff        = 0                       # cutoff to stop searching at (default is 0)
      @retrycount    = 0                       # distributed retries count
      @retrydelay    = 0                       # distributed retries delay
      @anchor        = []                      # geographical anchor point
      @indexweights  = []                      # per-index weights
      @ranker        = SPH_RANK_PROXIMITY_BM25 # ranking mode (default is SPH_RANK_PROXIMITY_BM25)
      @maxquerytime  = 0                       # max query time, milliseconds (default is 0, do not limit)
      @fieldweights  = {}                      # per-field-name weights
      @overrides     = []                      # per-query attribute values overrides
      @select        = '*'                     # select-list (attributes or expressions, with optional aliases)

      # per-reply fields (for single-query case)
      @error         = ''                      # last error message
      @warning       = ''                      # last warning message
      @connerror     = false                   # connection error vs remote error flag

      @reqs          = []                      # requests storage (for multi-query case)
      @mbenc         = ''                      # stored mbstring encoding
      @timeout       = 0                       # connect timeout
      @retries       = 1                       # number of connect retries in case of emergency
      @reqtimeout    = 0                       # request timeout
      @reqretries    = 1                       # number of request retries in case of emergency

      # per-client-object settings
      # searchd servers list
      @servers       = [Sphinx::Server.new(self, 'localhost', 3312, false)].freeze
      @lastserver    = -1
    end

    # Returns last error message, as a string, in human readable format. If there
    # were no errors during the previous API call, empty string is returned.
    #
    # You should call it when any other function (such as +Query+) fails (typically,
    # the failing function returns false). The returned string will contain the
    # error description.
    #
    # The error message is not reset by this call; so you can safely call it
    # several times if needed.
    #
    def GetLastError
      @error
    end

    # Returns last warning message, as a string, in human readable format. If there
    # were no warnings during the previous API call, empty string is returned.
    #
    # You should call it to verify whether your request (such as +Query+) was
    # completed but with warnings. For instance, search query against a distributed
    # index might complete succesfully even if several remote agents timed out.
    # In that case, a warning message would be produced.
    #
    # The warning message is not reset by this call; so you can safely call it
    # several times if needed.
    #
    def GetLastWarning
      @warning
    end

    # Checks whether the last error was a network error on API side, or a
    # remote error reported by searchd. Returns true if the last connection
    # attempt to searchd failed on API side, false otherwise (if the error
    # was remote, or there were no connection attempts at all).
    #
    def IsConnectError
      @connerror || false
    end

    # Sets searchd host name and TCP port. All subsequent requests will
    # use the new host and port settings. Default +host+ and +port+ are
    # 'localhost' and 3312, respectively.
    #
    # Also, you can specify an absolute path to Sphinx's UNIX socket as +host+,
    # in this case pass port as +0+ or +nil+.
    #
    def SetServer(host, port)
      raise ArgumentError, '"host" argument must be String' unless host.kind_of?(String)

      path = nil
      # Check if UNIX socket should be used
      if host[0] == ?/
        path = host
      elsif host[0, 7] == 'unix://'
        path = host[7..-1]
      else
        raise ArgumentError, '"port" argument must be Integer' unless port.respond_to?(:integer?) and port.integer?
      end

      host = port = nil unless path.nil?

      @servers = [Sphinx::Server.new(self, host, port, path)].freeze
    end

    # Sets the list of searchd servers. Each subsequent request will use next
    # server in list (round-robin). In case of one server failure, request could
    # be retried on another server (see +SetConnectTimeout+ and +SetRequestTimeout+).
    #
    # Method accepts an +Array+ of +Hash+es, each of them should have :host
    # and :port (to connect to searchd through network) or :path (an absolute path
    # to UNIX socket) specified.
    #
    # Usage example:
    #
    #   sphinx.SetServers([
    #     { :host => 'browse01.local', :port => 3312 },
    #     { :host => 'browse02.local', :port => 3312 },
    #     { :host => 'browse03.local', :port => 3312 }
    #   ])
    #
    def SetServers(servers)
      raise ArgumentError, '"servers" argument must be Array'     unless servers.kind_of?(Array)
      raise ArgumentError, '"servers" argument must be not empty' if servers.empty?

      @servers = servers.map do |server|
        raise ArgumentError, '"servers" argument must be Array of Hashes' unless server.kind_of?(Hash)

        host = server[:path] || server['path'] || server[:host] || server['host']
        port = server[:port] || server['port']
        path = nil
        raise ArgumentError, '"host" argument must be String' unless host.kind_of?(String)

        # Check if UNIX socket should be used
        if host[0] == ?/
          path = host
        elsif host[0, 7] == 'unix://'
          path = host[7..-1]
        else
          raise ArgumentError, '"port" argument must be Integer' unless port.respond_to?(:integer?) and port.integer?
        end

        host = port = nil unless path.nil?

        Sphinx::Server.new(self, host, port, path)
      end.freeze
    end

    # Sets the time allowed to spend connecting to the server before giving up
    # and number of retries to perform.
    #
    # In the event of a failure to connect, an appropriate error code should
    # be returned back to the application in order for application-level error
    # handling to advise the user.
    #
    # When multiple servers configured through +SetServers+ method, and +retries+
    # number is greater than 1, library will try to connect to another server.
    # In case of single server configured, it will try to reconnect +retries+
    # times.
    #
    # Please note, this timeout will only be used for connection establishing, not
    # for regular API requests.
    #
    def SetConnectTimeout(timeout, retries = 1)
      raise ArgumentError, '"timeout" argument must be Integer'        unless timeout.respond_to?(:integer?) and timeout.integer?
      raise ArgumentError, '"retries" argument must be Integer'        unless retries.respond_to?(:integer?) and retries.integer?
      raise ArgumentError, '"retries" argument must be greater than 0' unless retries > 0

      @timeout = timeout
      @retries = retries
    end

    # Sets the time allowed to spend performing request to the server before giving up
    # and number of retries to perform.
    #
    # In the event of a failure to do request, an appropriate error code should
    # be returned back to the application in order for application-level error
    # handling to advise the user.
    #
    # When multiple servers configured through +SetServers+ method, and +retries+
    # number is greater than 1, library will try to do another try with this server
    # (with full reconnect). If connection would fail, behavior depends on
    # +SetConnectTimeout+ settings.
    #
    # Please note, this timeout will only be used for request performing, not
    # for connection establishing.
    #
    def SetRequestTimeout(timeout, retries = 1)
      raise ArgumentError, '"timeout" argument must be Integer'        unless timeout.respond_to?(:integer?) and timeout.integer?
      raise ArgumentError, '"retries" argument must be Integer'        unless retries.respond_to?(:integer?) and retries.integer?
      raise ArgumentError, '"retries" argument must be greater than 0' unless retries > 0

      @reqtimeout = timeout
      @reqretries = retries
    end

    # Sets offset into server-side result set (+offset+) and amount of matches to
    # return to client starting from that offset (+limit+). Can additionally control
    # maximum server-side result set size for current query (+max_matches+) and the
    # threshold amount of matches to stop searching at (+cutoff+). All parameters
    # must be non-negative integers.
    #
    # First two parameters to +SetLimits+ are identical in behavior to MySQL LIMIT
    # clause. They instruct searchd to return at most +limit+ matches starting from
    # match number +offset+. The default offset and limit settings are +0+ and +20+,
    # that is, to return first +20+ matches.
    #
    # +max_matches+ setting controls how much matches searchd will keep in RAM
    # while searching. All matching documents will be normally processed, ranked,
    # filtered, and sorted even if max_matches is set to +1+. But only best +N+
    # documents are stored in memory at any given moment for performance and RAM
    # usage reasons, and this setting controls that N. Note that there are two
    # places where max_matches limit is enforced. Per-query limit is controlled
    # by this API call, but there also is per-server limit controlled by +max_matches+
    # setting in the config file. To prevent RAM usage abuse, server will not
    # allow to set per-query limit higher than the per-server limit.
    #
    # You can't retrieve more than +max_matches+ matches to the client application.
    # The default limit is set to +1000+. Normally, you must not have to go over
    # this limit. One thousand records is enough to present to the end user.
    # And if you're thinking about pulling the results to application for further
    # sorting or filtering, that would be much more efficient if performed on
    # Sphinx side.
    #
    # +cutoff+ setting is intended for advanced performance control. It tells
    # searchd to forcibly stop search query once $cutoff matches had been found
    # and processed.
    #
    def SetLimits(offset, limit, max = 0, cutoff = 0)
      raise ArgumentError, '"offset" argument must be Integer' unless offset.respond_to?(:integer?) and offset.integer?
      raise ArgumentError, '"limit" argument must be Integer'  unless limit.respond_to?(:integer?)  and limit.integer?
      raise ArgumentError, '"max" argument must be Integer'    unless max.respond_to?(:integer?)    and max.integer?
      raise ArgumentError, '"cutoff" argument must be Integer' unless cutoff.respond_to?(:integer?) and cutoff.integer?

      raise ArgumentError, '"offset" argument should be greater or equal to zero' unless offset >= 0
      raise ArgumentError, '"limit" argument should be greater to zero'           unless limit > 0
      raise ArgumentError, '"max" argument should be greater or equal to zero'    unless max >= 0
      raise ArgumentError, '"cutoff" argument should be greater or equal to zero' unless cutoff >= 0

      @offset = offset
      @limit = limit
      @maxmatches = max if max > 0
      @cutoff = cutoff if cutoff > 0
    end

    # Sets maximum search query time, in milliseconds. Parameter must be a
    # non-negative integer. Default valus is +0+ which means "do not limit".
    #
    # Similar to +cutoff+ setting from +SetLimits+, but limits elapsed query
    # time instead of processed matches count. Local search queries will be
    # stopped once that much time has elapsed. Note that if you're performing
    # a search which queries several local indexes, this limit applies to each
    # index separately.
    #
    def SetMaxQueryTime(max)
      raise ArgumentError, '"max" argument must be Integer' unless max.respond_to?(:integer?) and max.integer?
      raise ArgumentError, '"max" argument should be greater or equal to zero' unless max >= 0

      @maxquerytime = max
    end

    # Sets full-text query matching mode.
    #
    # Parameter must be a +Fixnum+ constant specifying one of the known modes
    # (+SPH_MATCH_ALL+, +SPH_MATCH_ANY+, etc), +String+ with identifier (<tt>"all"</tt>,
    # <tt>"any"</tt>, etc), or a +Symbol+ (<tt>:all</tt>, <tt>:any</tt>, etc).
    #
    # Corresponding sections in Sphinx reference manual:
    # * {Section 4.1, "Matching modes"}[http://www.sphinxsearch.com/docs/current.html#matching-modes] for details.
    # * {Section 6.3.1, "SetMatchMode"}[http://www.sphinxsearch.com/docs/current.html#api-func-setmatchmode] for details.
    #
    def SetMatchMode(mode)
      case mode
        when String, Symbol
          begin
            mode = self.class.const_get("SPH_MATCH_#{mode.to_s.upcase}")
          rescue NameError
            raise ArgumentError, "\"mode\" argument value \"#{mode}\" is invalid"
          end
        when Fixnum
          raise ArgumentError, "\"mode\" argument value \"#{mode}\" is invalid" unless (SPH_MATCH_ALL..SPH_MATCH_EXTENDED2).include?(mode)
        else
          raise ArgumentError, '"mode" argument must be Fixnum, String, or Symbol'
      end

      @mode = mode
    end

    # Set ranking mode.
    #
    # You can specify ranking mode as String ("proximity_bm25", "bm25", etc),
    # Symbol (:proximity_bm25, :bm25, etc), or
    # Fixnum constant (SPH_RANK_PROXIMITY_BM25, SPH_RANK_BM25, etc).
    #
    def SetRankingMode(ranker)
      case ranker
        when String, Symbol
          begin
            ranker = self.class.const_get("SPH_RANK_#{ranker.to_s.upcase}")
          rescue NameError
            raise ArgumentError, "\"ranker\" argument value \"#{ranker}\" is invalid"
          end
        when Fixnum
          raise ArgumentError, "\"ranker\" argument value \"#{ranker}\" is invalid" unless (SPH_RANK_PROXIMITY_BM25..SPH_RANK_SPH04).include?(ranker)
        else
          raise ArgumentError, '"ranker" argument must be Fixnum, String, or Symbol'
      end

      @ranker = ranker
    end

    # Set matches sorting mode.
    #
    # You can specify sorting mode as String ("relevance", "attr_desc", etc),
    # Symbol (:relevance, :attr_desc, etc), or
    # Fixnum constant (SPH_SORT_RELEVANCE, SPH_SORT_ATTR_DESC, etc).
    #
    def SetSortMode(mode, sortby = '')
      case mode
        when String, Symbol
          begin
            mode = self.class.const_get("SPH_SORT_#{mode.to_s.upcase}")
          rescue NameError
            raise ArgumentError, "\"mode\" argument value \"#{mode}\" is invalid"
          end
        when Fixnum
          raise ArgumentError, "\"mode\" argument value \"#{mode}\" is invalid" unless (SPH_SORT_RELEVANCE..SPH_SORT_EXPR).include?(mode)
        else
          raise ArgumentError, '"mode" argument must be Fixnum, String, or Symbol'
      end

      raise ArgumentError, '"sortby" argument must be String' unless sortby.kind_of?(String)
      raise ArgumentError, '"sortby" should not be empty unless mode is SPH_SORT_RELEVANCE' unless mode == SPH_SORT_RELEVANCE or !sortby.empty?

      @sort = mode
      @sortby = sortby
    end

    # Bind per-field weights by order.
    #
    # DEPRECATED; use SetFieldWeights() instead.
    #
    def SetWeights(weights)
      raise ArgumentError, '"weights" argument must be Array' unless weights.kind_of?(Array)
      weights.each do |weight|
        raise ArgumentError, '"weights" argument must be Array of integers' unless weight.respond_to?(:integer?) and weight.integer?
      end

      @weights = weights
    end

    # Bind per-field weights by name.
    #
    # Takes string (field name) to integer (field weight) hash as an argument.
    # * Takes precedence over SetWeights().
    # * Unknown names will be silently ignored.
    # * Unbound fields will be silently given a weight of 1.
    #
    def SetFieldWeights(weights)
      raise ArgumentError, '"weights" argument must be Hash' unless weights.kind_of?(Hash)
      weights.each do |name, weight|
        unless (name.kind_of?(String) or name.kind_of?(Symbol)) and (weight.respond_to?(:integer?) and weight.integer?)
          raise ArgumentError, '"weights" argument must be Hash map of strings to integers'
        end
      end

      @fieldweights = weights
    end

    # Bind per-index weights by name.
    #
    def SetIndexWeights(weights)
      raise ArgumentError, '"weights" argument must be Hash' unless weights.kind_of?(Hash)
      weights.each do |index, weight|
        unless (index.kind_of?(String) or index.kind_of?(Symbol)) and (weight.respond_to?(:integer?) and weight.integer?)
          raise ArgumentError, '"weights" argument must be Hash map of strings to integers'
        end
      end

      @indexweights = weights
    end

    # Set IDs range to match.
    #
    # Only match records if document ID is beetwen <tt>min_id</tt> and <tt>max_id</tt> (inclusive).
    #
    def SetIDRange(min, max)
      raise ArgumentError, '"min" argument must be Integer' unless min.respond_to?(:integer?) and min.integer?
      raise ArgumentError, '"max" argument must be Integer' unless max.respond_to?(:integer?) and max.integer?
      raise ArgumentError, '"max" argument greater or equal to "min"' unless min <= max

      @min_id = min
      @max_id = max
    end

    # Set values filter.
    #
    # Only match those records where <tt>attribute</tt> column values
    # are in specified set.
    #
    def SetFilter(attribute, values, exclude = false)
      raise ArgumentError, '"attribute" argument must be String or Symbol' unless attribute.kind_of?(String) or attribute.kind_of?(Symbol)
      raise ArgumentError, '"values" argument must be Array'               unless values.kind_of?(Array)
      raise ArgumentError, '"values" argument must not be empty'           if values.empty?
      raise ArgumentError, '"exclude" argument must be Boolean'            unless exclude.kind_of?(TrueClass) or exclude.kind_of?(FalseClass)

      values.each do |value|
        raise ArgumentError, '"values" argument must be Array of Integer' unless value.respond_to?(:integer?) and value.integer?
      end

      @filters << { 'type' => SPH_FILTER_VALUES, 'attr' => attribute.to_s, 'exclude' => exclude, 'values' => values }
    end

    # Set range filter.
    #
    # Only match those records where <tt>attribute</tt> column value
    # is beetwen <tt>min</tt> and <tt>max</tt> (including <tt>min</tt> and <tt>max</tt>).
    def SetFilterRange(attribute, min, max, exclude = false)
      raise ArgumentError, '"attribute" argument must be String or Symbol' unless attribute.kind_of?(String) or attribute.kind_of?(Symbol)
      raise ArgumentError, '"min" argument must be Integer'                unless min.respond_to?(:integer?) and min.integer?
      raise ArgumentError, '"max" argument must be Integer'                unless max.respond_to?(:integer?) and max.integer?
      raise ArgumentError, '"max" argument greater or equal to "min"'      unless min <= max
      raise ArgumentError, '"exclude" argument must be Boolean'            unless exclude.kind_of?(TrueClass) or exclude.kind_of?(FalseClass)

      @filters << { 'type' => SPH_FILTER_RANGE, 'attr' => attribute.to_s, 'exclude' => exclude, 'min' => min, 'max' => max }
    end

    # Set float range filter.
    #
    # Only match those records where <tt>attribute</tt> column value
    # is beetwen <tt>min</tt> and <tt>max</tt> (including <tt>min</tt> and <tt>max</tt>).
    #
    def SetFilterFloatRange(attribute, min, max, exclude = false)
      raise ArgumentError, '"attribute" argument must be String or Symbol' unless attribute.kind_of?(String) or attribute.kind_of?(Symbol)
      raise ArgumentError, '"min" argument must be Float or Integer'       unless min.kind_of?(Float) or (min.respond_to?(:integer?) and min.integer?)
      raise ArgumentError, '"max" argument must be Float or Integer'       unless max.kind_of?(Float) or (max.respond_to?(:integer?) and max.integer?)
      raise ArgumentError, '"max" argument greater or equal to "min"'      unless min <= max
      raise ArgumentError, '"exclude" argument must be Boolean'            unless exclude.kind_of?(TrueClass) or exclude.kind_of?(FalseClass)

      @filters << { 'type' => SPH_FILTER_FLOATRANGE, 'attr' => attribute.to_s, 'exclude' => exclude, 'min' => min.to_f, 'max' => max.to_f }
    end

    # Setup anchor point for geosphere distance calculations.
    #
    # Required to use <tt>@geodist</tt> in filters and sorting
    # distance will be computed to this point. Latitude and longitude
    # must be in radians.
    #
    # * <tt>attrlat</tt> -- is the name of latitude attribute
    # * <tt>attrlong</tt> -- is the name of longitude attribute
    # * <tt>lat</tt> -- is anchor point latitude, in radians
    # * <tt>long</tt> -- is anchor point longitude, in radians
    #
    def SetGeoAnchor(attrlat, attrlong, lat, long)
      raise ArgumentError, '"attrlat" argument must be String or Symbol'  unless attrlat.kind_of?(String)  or attrlat.kind_of?(Symbol)
      raise ArgumentError, '"attrlong" argument must be String or Symbol' unless attrlong.kind_of?(String) or attrlong.kind_of?(Symbol)
      raise ArgumentError, '"lat" argument must be Float or Integer'      unless lat.kind_of?(Float)  or (lat.respond_to?(:integer?)  and lat.integer?)
      raise ArgumentError, '"long" argument must be Float or Integer'     unless long.kind_of?(Float) or (long.respond_to?(:integer?) and long.integer?)

      @anchor = { 'attrlat' => attrlat.to_s, 'attrlong' => attrlong.to_s, 'lat' => lat.to_f, 'long' => long.to_f }
    end

    # Set grouping attribute and function.
    #
    # In grouping mode, all matches are assigned to different groups
    # based on grouping function value.
    #
    # Each group keeps track of the total match count, and the best match
    # (in this group) according to current sorting function.
    #
    # The final result set contains one best match per group, with
    # grouping function value and matches count attached.
    #
    # Groups in result set could be sorted by any sorting clause,
    # including both document attributes and the following special
    # internal Sphinx attributes:
    #
    # * @id - match document ID;
    # * @weight, @rank, @relevance -  match weight;
    # * @group - groupby function value;
    # * @count - amount of matches in group.
    #
    # the default mode is to sort by groupby value in descending order,
    # ie. by '@group desc'.
    #
    # 'total_found' would contain total amount of matching groups over
    # the whole index.
    #
    # WARNING: grouping is done in fixed memory and thus its results
    # are only approximate; so there might be more groups reported
    # in total_found than actually present. @count might also
    # be underestimated.
    #
    # For example, if sorting by relevance and grouping by "published"
    # attribute with SPH_GROUPBY_DAY function, then the result set will
    # contain one most relevant match per each day when there were any
    # matches published, with day number and per-day match count attached,
    # and sorted by day number in descending order (ie. recent days first).
    #
    def SetGroupBy(attribute, func, groupsort = '@group desc')
      raise ArgumentError, '"attribute" argument must be String or Symbol' unless attribute.kind_of?(String)  or attribute.kind_of?(Symbol)
      raise ArgumentError, '"groupsort" argument must be String'           unless groupsort.kind_of?(String)

      case func
        when String, Symbol
          begin
            func = self.class.const_get("SPH_GROUPBY_#{func.to_s.upcase}")
          rescue NameError
            raise ArgumentError, "\"func\" argument value \"#{func}\" is invalid"
          end
        when Fixnum
          raise ArgumentError, "\"func\" argument value \"#{func}\" is invalid" unless (SPH_GROUPBY_DAY..SPH_GROUPBY_ATTRPAIR).include?(func)
        else
          raise ArgumentError, '"func" argument must be Fixnum, String, or Symbol'
      end

      @groupby = attribute.to_s
      @groupfunc = func
      @groupsort = groupsort
    end

    # Set count-distinct attribute for group-by queries.
    #
    def SetGroupDistinct(attribute)
      raise ArgumentError, '"attribute" argument must be String or Symbol' unless attribute.kind_of?(String)  or attribute.kind_of?(Symbol)

      @groupdistinct = attribute.to_s
    end

    # Sets distributed retry count and delay.
    #
    # On temporary failures searchd will attempt up to +count+ retries per
    # agent. +delay+ is the delay between the retries, in milliseconds. Retries
    # are disabled by default. Note that this call will not make the API itself
    # retry on temporary failure; it only tells searchd to do so. Currently,
    # the list of temporary failures includes all kinds of +connect+
    # failures and maxed out (too busy) remote agents.
    #
    def SetRetries(count, delay = 0)
      raise ArgumentError, '"count" argument must be Integer' unless count.respond_to?(:integer?) and count.integer?
      raise ArgumentError, '"delay" argument must be Integer' unless delay.respond_to?(:integer?) and delay.integer?

      @retrycount = count
      @retrydelay = delay
    end

    # Sets temporary (per-query) per-document attribute value overrides. Only
    # supports scalar attributes. +values+ must be a +Hash+ that maps document
    # IDs to overridden attribute values.
    #
    # Override feature lets you "temporary" update attribute values for some
    # documents within a single query, leaving all other queries unaffected.
    # This might be useful for personalized data. For example, assume you're
    # implementing a personalized search function that wants to boost the posts
    # that the user's friends recommend. Such data is not just dynamic, but
    # also personal; so you can't simply put it in the index because you don't
    # want everyone's searches affected. Overrides, on the other hand, are local
    # to a single query and invisible to everyone else. So you can, say, setup
    # a "friends_weight" value for every document, defaulting to 0, then
    # temporary override it with 1 for documents 123, 456 and 789 (recommended
    # by exactly the friends of current user), and use that value when ranking.
    #
    def SetOverride(attrname, attrtype, values)
      raise ArgumentError, '"attrname" argument must be String or Symbol' unless attrname.kind_of?(String) or attrname.kind_of?(Symbol)

      case attrtype
        when String, Symbol
          begin
            attrtype = self.class.const_get("SPH_ATTR_#{attrtype.to_s.upcase}")
          rescue NameError
            raise ArgumentError, "\"attrtype\" argument value \"#{attrtype}\" is invalid"
          end
        when Fixnum
          raise ArgumentError, "\"attrtype\" argument value \"#{attrtype}\" is invalid" unless (SPH_ATTR_INTEGER..SPH_ATTR_BIGINT).include?(attrtype)
        else
          raise ArgumentError, '"attrtype" argument must be Fixnum, String, or Symbol'
      end

      raise ArgumentError, '"values" argument must be Hash' unless values.kind_of?(Hash)

      values.each do |id, value|
        raise ArgumentError, '"values" argument must be Hash map of Integer to Integer or Time' unless id.respond_to?(:integer?) and id.integer?
        case attrtype
          when SPH_ATTR_TIMESTAMP
            raise ArgumentError, '"values" argument must be Hash map of Integer to Integer or Time' unless (value.respond_to?(:integer?) and value.integer?) or value.kind_of?(Time)
          when SPH_ATTR_FLOAT
            raise ArgumentError, '"values" argument must be Hash map of Integer to Float or Integer' unless value.kind_of?(Float) or (value.respond_to?(:integer?) and value.integer?)
          else
            # SPH_ATTR_INTEGER, SPH_ATTR_ORDINAL, SPH_ATTR_BOOL, SPH_ATTR_BIGINT
            raise ArgumentError, '"values" argument must be Hash map of Integer to Integer' unless value.respond_to?(:integer?) and value.integer?
        end
      end

      @overrides << { 'attr' => attrname.to_s, 'type' => attrtype, 'values' => values }
    end

    # Sets the select clause, listing specific attributes to fetch, and
    # expressions to compute and fetch. Clause syntax mimics SQL.
    #
    # +SetSelect+ is very similar to the part of a typical SQL query between
    # +SELECT+ and +FROM+. It lets you choose what attributes (columns) to
    # fetch, and also what expressions over the columns to compute and fetch.
    # A certain difference from SQL is that expressions must always be aliased
    # to a correct identifier (consisting of letters and digits) using +AS+
    # keyword. SQL also lets you do that but does not require to. Sphinx enforces
    # aliases so that the computation results can always be returned under a
    #{ }"normal" name in the result set, used in other clauses, etc.
    #
    # Everything else is basically identical to SQL. Star ('*') is supported.
    # Functions are supported. Arbitrary amount of expressions is supported.
    # Computed expressions can be used for sorting, filtering, and grouping,
    # just as the regular attributes.
    #
    # Starting with version 0.9.9-rc2, aggregate functions (<tt>AVG()</tt>,
    # <tt>MIN()</tt>, <tt>MAX()</tt>, <tt>SUM()</tt>) are supported when using
    # <tt>GROUP BY</tt>.
    #
    # Expression sorting (Section 4.5, “SPH_SORT_EXPR mode”) and geodistance
    # functions (+SetGeoAnchor+) are now internally implemented
    # using this computed expressions mechanism, using magic names '<tt>@expr</tt>'
    # and '<tt>@geodist</tt>' respectively.
    #
    # Usage example:
    #
    #   sphinx.SetSelect('*, @weight+(user_karma+ln(pageviews))*0.1 AS myweight')
    #   sphinx.SetSelect('exp_years, salary_gbp*{$gbp_usd_rate} AS salary_usd, IF(age>40,1,0) AS over40')
    #   sphinx.SetSelect('*, AVG(price) AS avgprice')
    #
    def SetSelect(select)
      raise ArgumentError, '"select" argument must be String' unless select.kind_of?(String)

      @select = select
    end

    # Clears all currently set filters.
    #
    # This call is only normally required when using multi-queries. You might want
    # to set different filters for different queries in the batch. To do that,
    # you should call +ResetFilters+ and add new filters using the respective calls.
    #
    # Usage example:
    #
    #   sphinx.ResetFilters
    #
    def ResetFilters
      @filters = []
      @anchor = []
    end

    # Clears all currently group-by settings, and disables group-by.
    #
    # This call is only normally required when using multi-queries. You can
    # change individual group-by settings using +SetGroupBy+ and +SetGroupDistinct+
    # calls, but you can not disable group-by using those calls. +ResetGroupBy+
    # fully resets previous group-by settings and disables group-by mode in the
    # current state, so that subsequent +AddQuery+ calls can perform non-grouping
    # searches.
    #
    # Usage example:
    #
    #   sphinx.ResetGroupBy
    #
    def ResetGroupBy
      @groupby       = ''
      @groupfunc     = SPH_GROUPBY_DAY
      @groupsort     = '@group desc'
      @groupdistinct = ''
    end

    # Clear all attribute value overrides (for multi-queries).
    def ResetOverrides
      @overrides = []
    end

    # Connect to searchd server and run given search query.
    #
    # <tt>query</tt> is query string

    # <tt>index</tt> is index name (or names) to query. default value is "*" which means
    # to query all indexes. Accepted characters for index names are letters, numbers,
    # dash, and underscore; everything else is considered a separator. Therefore,
    # all the following calls are valid and will search two indexes:
    #
    #   sphinx.Query('test query', 'main delta')
    #   sphinx.Query('test query', 'main;delta')
    #   sphinx.Query('test query', 'main, delta')
    #
    # Index order matters. If identical IDs are found in two or more indexes,
    # weight and attribute values from the very last matching index will be used
    # for sorting and returning to client. Therefore, in the example above,
    # matches from "delta" index will always "win" over matches from "main".
    #
    # Returns false on failure.
    # Returns hash which has the following keys on success:
    #
    # * <tt>'matches'</tt> -- array of hashes {'weight', 'group', 'id'}, where 'id' is document_id.
    # * <tt>'total'</tt> -- total amount of matches retrieved (upto SPH_MAX_MATCHES, see sphinx.h)
    # * <tt>'total_found'</tt> -- total amount of matching documents in index
    # * <tt>'time'</tt> -- search time
    # * <tt>'words'</tt> -- hash which maps query terms (stemmed!) to ('docs', 'hits') hash
    #
    def Query(query, index = '*', comment = '')
      @reqs = []

      self.AddQuery(query, index, comment)
      results = self.RunQueries

      # probably network error; error message should be already filled
      return false unless results.instance_of?(Array)

      @error = results[0]['error']
      @warning = results[0]['warning']

      return false if results[0]['status'] == SEARCHD_ERROR
      return results[0]
    end

    # Add query to batch.
    #
    # Batch queries enable searchd to perform internal optimizations,
    # if possible; and reduce network connection overheads in all cases.
    #
    # For instance, running exactly the same query with different
    # groupby settings will enable searched to perform expensive
    # full-text search and ranking operation only once, but compute
    # multiple groupby results from its output.
    #
    # Parameters are exactly the same as in <tt>Query</tt> call.
    # Returns index to results array returned by <tt>RunQueries</tt> call.
    #
    def AddQuery(query, index = '*', comment = '')
      # build request

      # mode and limits
      request = Request.new
      request.put_int @offset, @limit, @mode, @ranker, @sort
      request.put_string @sortby
      # query itself
      request.put_string query
      # weights
      request.put_int_array @weights
      # indexes
      request.put_string index
      # id64 range marker
      request.put_int 1
      # id64 range
      request.put_int64 @min_id.to_i, @max_id.to_i

      # filters
      request.put_int @filters.length
      @filters.each do |filter|
        request.put_string filter['attr']
        request.put_int filter['type']

        case filter['type']
          when SPH_FILTER_VALUES
            request.put_int64_array filter['values']
          when SPH_FILTER_RANGE
            request.put_int64 filter['min'], filter['max']
          when SPH_FILTER_FLOATRANGE
            request.put_float filter['min'], filter['max']
          else
            raise SphinxInternalError, 'Internal error: unhandled filter type'
        end
        request.put_int filter['exclude'] ? 1 : 0
      end

      # group-by clause, max-matches count, group-sort clause, cutoff count
      request.put_int @groupfunc
      request.put_string @groupby
      request.put_int @maxmatches
      request.put_string @groupsort
      request.put_int @cutoff, @retrycount, @retrydelay
      request.put_string @groupdistinct

      # anchor point
      if @anchor.empty?
        request.put_int 0
      else
        request.put_int 1
        request.put_string @anchor['attrlat'], @anchor['attrlong']
        request.put_float @anchor['lat'], @anchor['long']
      end

      # per-index weights
      request.put_int @indexweights.length
      @indexweights.each do |idx, weight|
        request.put_string idx.to_s
        request.put_int weight
      end

      # max query time
      request.put_int @maxquerytime

      # per-field weights
      request.put_int @fieldweights.length
      @fieldweights.each do |field, weight|
        request.put_string field.to_s
        request.put_int weight
      end

      # comment
      request.put_string comment

      # attribute overrides
      request.put_int @overrides.length
      for entry in @overrides do
        request.put_string entry['attr']
        request.put_int entry['type'], entry['values'].size
        entry['values'].each do |id, val|
          request.put_int64 id
          case entry['type']
            when SPH_ATTR_FLOAT
              request.put_float val.to_f
            when SPH_ATTR_BIGINT
              request.put_int64 val.to_i
            else
              request.put_int val.to_i
          end
        end
      end

      # select-list
      request.put_string @select

      # store request to requests array
      @reqs << request.to_s;
      return @reqs.length - 1
    end

    # Run queries batch.
    #
    # Returns an array of result sets on success.
    # Returns false on network IO failure.
    #
    # Each result set in returned array is a hash which containts
    # the same keys as the hash returned by <tt>Query</tt>, plus:
    #
    # * <tt>'error'</tt> -- search error for this query
    # * <tt>'words'</tt> -- hash which maps query terms (stemmed!) to ( "docs", "hits" ) hash
    #
    def RunQueries
      if @reqs.empty?
        @error = 'No queries defined, issue AddQuery() first'
        return false
      end

      req = @reqs.join('')
      nreqs = @reqs.length
      @reqs = []
      response = perform_request(:search, req, nreqs)

      # parse response
      results = []
      ires = 0
      while ires < nreqs
        ires += 1
        result = {}

        result['error'] = ''
        result['warning'] = ''

        # extract status
        status = result['status'] = response.get_int
        if status != SEARCHD_OK
          message = response.get_string
          if status == SEARCHD_WARNING
            result['warning'] = message
          else
            result['error'] = message
            results << result
            next
          end
        end

        # read schema
        fields = []
        attrs = {}
        attrs_names_in_order = []

        nfields = response.get_int
        while nfields > 0
          nfields -= 1
          fields << response.get_string
        end
        result['fields'] = fields

        nattrs = response.get_int
        while nattrs > 0
          nattrs -= 1
          attr = response.get_string
          type = response.get_int
          attrs[attr] = type
          attrs_names_in_order << attr
        end
        result['attrs'] = attrs

        # read match count
        count = response.get_int
        id64 = response.get_int

        # read matches
        result['matches'] = []
        while count > 0
          count -= 1

          if id64 != 0
            doc = response.get_int64
            weight = response.get_int
          else
            doc, weight = response.get_ints(2)
          end

          r = {} # This is a single result put in the result['matches'] array
          r['id'] = doc
          r['weight'] = weight
          attrs_names_in_order.each do |a|
            r['attrs'] ||= {}

            case attrs[a]
              when SPH_ATTR_BIGINT
                # handle 64-bit ints
                r['attrs'][a] = response.get_int64
              when SPH_ATTR_FLOAT
                # handle floats
                r['attrs'][a] = response.get_float
              when SPH_ATTR_STRING
                r['attrs'][a] = response.get_string
              else
                # handle everything else as unsigned ints
                val = response.get_int
                if (attrs[a] & SPH_ATTR_MULTI) != 0
                  r['attrs'][a] = []
                  1.upto(val) do
                    r['attrs'][a] << response.get_int
                  end
                else
                  r['attrs'][a] = val
                end
            end
          end
          result['matches'] << r
        end
        result['total'], result['total_found'], msecs, words = response.get_ints(4)
        result['time'] = '%.3f' % (msecs / 1000.0)

        result['words'] = {}
        while words > 0
          words -= 1
          word = response.get_string
          docs, hits = response.get_ints(2)
          result['words'][word] = { 'docs' => docs, 'hits' => hits }
        end

        results << result
      end

      return results
    end

    # Connect to searchd server and generate exceprts from given documents.
    #
    # * <tt>docs</tt> -- an array of strings which represent the documents' contents
    # * <tt>index</tt> -- a string specifiying the index which settings will be used
    # for stemming, lexing and case folding
    # * <tt>words</tt> -- a string which contains the words to highlight
    # * <tt>opts</tt> is a hash which contains additional optional highlighting parameters.
    #
    # You can use following parameters:
    # * <tt>'before_match'</tt> -- a string to insert before a set of matching words, default is "<b>"
    # * <tt>'after_match'</tt> -- a string to insert after a set of matching words, default is "<b>"
    # * <tt>'chunk_separator'</tt> -- a string to insert between excerpts chunks, default is " ... "
    # * <tt>'limit'</tt> -- max excerpt size in symbols (codepoints), default is 256
    # * <tt>'around'</tt> -- how much words to highlight around each match, default is 5
    # * <tt>'exact_phrase'</tt> -- whether to highlight exact phrase matches only, default is <tt>false</tt>
    # * <tt>'single_passage'</tt> -- whether to extract single best passage only, default is false
    # * <tt>'use_boundaries'</tt> -- whether to extract passages by phrase boundaries setup in tokenizer
    # * <tt>'weight_order'</tt> -- whether to order best passages in document (default) or weight order
    #
    # Returns false on failure.
    # Returns an array of string excerpts on success.
    #
    def BuildExcerpts(docs, index, words, opts = {})
      raise ArgumentError, '"docs" argument must be Array'   unless docs.kind_of?(Array)
      raise ArgumentError, '"index" argument must be String' unless index.kind_of?(String) or index.kind_of?(Symbol)
      raise ArgumentError, '"words" argument must be String' unless words.kind_of?(String)
      raise ArgumentError, '"opts" argument must be Hash'    unless opts.kind_of?(Hash)

      docs.each do |doc|
        raise ArgumentError, '"docs" argument must be Array of Strings' unless doc.kind_of?(String)
      end

      # fixup options
      opts['before_match']    ||= opts[:before_match]    || '<b>';
      opts['after_match']     ||= opts[:after_match]     || '</b>';
      opts['chunk_separator'] ||= opts[:chunk_separator] || ' ... ';
      opts['limit']           ||= opts[:limit]           || 256;
      opts['around']          ||= opts[:around]          || 5;
      opts['exact_phrase']    ||= opts[:exact_phrase]    || false
      opts['single_passage']  ||= opts[:single_passage]  || false
      opts['use_boundaries']  ||= opts[:use_boundaries]  || false
      opts['weight_order']    ||= opts[:weight_order]    || false
      opts['query_mode']      ||= opts[:query_mode]      || false

      # build request

      # v.1.0 req
      flags = 1
      flags |= 2  if opts['exact_phrase']
      flags |= 4  if opts['single_passage']
      flags |= 8  if opts['use_boundaries']
      flags |= 16 if opts['weight_order']
      flags |= 32 if opts['query_mode']

      request = Request.new
      request.put_int 0, flags # mode=0, flags=1 (remove spaces)
      # req index
      request.put_string index.to_s
      # req words
      request.put_string words

      # options
      request.put_string opts['before_match']
      request.put_string opts['after_match']
      request.put_string opts['chunk_separator']
      request.put_int opts['limit'].to_i, opts['around'].to_i

      # documents
      request.put_int docs.size
      request.put_string(*docs)

      response = perform_request(:excerpt, request)

      # parse response
      docs.map { response.get_string }
    end

    # Connect to searchd server, and generate keyword list for a given query.
    #
    # Returns an array of words on success.
    #
    def BuildKeywords(query, index, hits)
      raise ArgumentError, '"query" argument must be String' unless query.kind_of?(String)
      raise ArgumentError, '"index" argument must be String' unless index.kind_of?(String) or index.kind_of?(Symbol)
      raise ArgumentError, '"hits" argument must be Boolean' unless hits.kind_of?(TrueClass) or hits.kind_of?(FalseClass)

      # build request
      request = Request.new
      # v.1.0 req
      request.put_string query # req query
      request.put_string index # req index
      request.put_int hits ? 1 : 0

      response = perform_request(:keywords, request)

      # parse response
      nwords = response.get_int
      (0...nwords).map do
        tokenized = response.get_string
        normalized = response.get_string

        entry = { 'tokenized' => tokenized, 'normalized' => normalized }
        entry['docs'], entry['hits'] = response.get_ints(2) if hits

        entry
      end
    end

    # Batch update given attributes in given rows in given indexes.
    #
    # * +index+ is a name of the index to be updated
    # * +attrs+ is an array of attribute name strings.
    # * +values+ is a hash where key is document id, and value is an array of
    # * +mva+ identifies whether update MVA
    # new attribute values
    #
    # Returns number of actually updated documents (0 or more) on success.
    # Returns -1 on failure.
    #
    # Usage example:
    #    sphinx.UpdateAttributes('test1', ['group_id'], { 1 => [456] })
    #    sphinx.UpdateAttributes('test1', ['group_id'], { 1 => [[456, 789]] }, true)
    #
    def UpdateAttributes(index, attrs, values, mva = false)
      # verify everything
      raise ArgumentError, '"index" argument must be String' unless index.kind_of?(String) or index.kind_of?(Symbol)
      raise ArgumentError, '"mva" argument must be Boolean'  unless mva.kind_of?(TrueClass) or mva.kind_of?(FalseClass)

      raise ArgumentError, '"attrs" argument must be Array' unless attrs.kind_of?(Array)
      attrs.each do |attr|
        raise ArgumentError, '"attrs" argument must be Array of Strings' unless attr.kind_of?(String) or attr.kind_of?(Symbol)
      end

      raise ArgumentError, '"values" argument must be Hash' unless values.kind_of?(Hash)
      values.each do |id, entry|
        raise ArgumentError, '"values" argument must be Hash map of Integer to Array' unless id.respond_to?(:integer?) and id.integer?
        raise ArgumentError, '"values" argument must be Hash map of Integer to Array' unless entry.kind_of?(Array)
        raise ArgumentError, "\"values\" argument Hash values Array must have #{attrs.length} elements" unless entry.length == attrs.length
        entry.each do |v|
          if mva
            raise ArgumentError, '"values" argument must be Hash map of Integer to Array of Arrays' unless v.kind_of?(Array)
            v.each do |vv|
              raise ArgumentError, '"values" argument must be Hash map of Integer to Array of Arrays of Integers' unless vv.respond_to?(:integer?) and vv.integer?
            end
          else
            raise ArgumentError, '"values" argument must be Hash map of Integer to Array of Integers' unless v.respond_to?(:integer?) and v.integer?
          end
        end
      end

      # build request
      request = Request.new
      request.put_string index

      request.put_int attrs.length
      for attr in attrs
        request.put_string attr
        request.put_int mva ? 1 : 0
      end

      request.put_int values.length
      values.each do |id, entry|
        request.put_int64 id
        if mva
          entry.each { |v| request.put_int_array v }
        else
          request.put_int(*entry)
        end
      end

      response = perform_request(:update, request)

      # parse response
      response.get_int
    end

    # persistent connections

    # Opens persistent connection to the server.
    #
    def Open
      if @servers.size > 1
        @error = 'too many servers. persistent socket allowed only for a single server.'
        return false
      end

      if @servers.first.persistent?
        @error = 'already connected'
        return false;
      end

      request = Request.new
      request.put_int(1)

      perform_request(:persist, request, nil) do |server, socket|
        server.make_persistent!(socket)
      end

      true
    end

    # Closes previously opened persistent connection.
    #
    def Close
      if @servers.size > 1
        @error = 'too many servers. persistent socket allowed only for a single server.'
        return false
      end

      unless @servers.first.persistent?
        @error = 'not connected'
        return false;
      end

      @servers.first.close_persistent!
    end

    # Queries searchd status, and returns an array of status variable name
    # and value pairs.
    #
    # Usage example:
    #
    #   status = sphinx.Status
    #   puts status.map { |key, value| "#{key.rjust(20)}: #{value}" }
    #
    def Status
      request = Request.new
      request.put_int(1)
      response = perform_request(:status, request)

      # parse response
      rows, cols = response.get_ints(2)
      (0...rows).map do
        (0...cols).map { response.get_string }
      end
    end

    def FlushAttrs
      request = Request.new
      response = perform_request(:flushattrs, request)

      # parse response
      begin
        response.get_int
      rescue EOFError
        -1
      end
    end

    protected

      # Connect, send query, get response.
      #
      # Use this method to communicate with Sphinx server. It ensures connection
      # will be instantiated properly, all headers will be generated properly, etc.
      #
      # Parameters:
      # * +command+ -- searchd command to perform (<tt>:search</tt>, <tt>:excerpt</tt>,
      #   <tt>:update</tt>, <tt>:keywords</tt>, <tt>:persist</tt>, <tt>:status</tt>,
      #   <tt>:query</tt>, <tt>:flushattrs</tt>. See <tt>SEARCHD_COMMAND_*</tt> for details).
      # * +request+ -- an instance of <tt>Sphinx::Request</tt> class. Contains request body.
      # * +additional+ -- additional integer data to be placed between header and body.
      # * +block+ -- if given, response will not be parsed, plain socket will be
      #   passed instead. this is special mode used for persistent connections,
      #   do not use for other tasks.
      #
      def perform_request(command, request, additional = nil, &block)
        with_server do |server|
          cmd = command.to_s.upcase
          command_id = Sphinx::Client.const_get("SEARCHD_COMMAND_#{cmd}")
          command_ver = Sphinx::Client.const_get("VER_COMMAND_#{cmd}")

          with_socket(server) do |socket|
            len = request.to_s.length + (additional.nil? ? 0 : 4)
            header = [command_id, command_ver, len].pack('nnN')
            header << [additional].pack('N') unless additional.nil?

            socket.write(header + request.to_s)

            if block_given?
              yield server, socket
            else
              parse_response(socket, command_ver)
            end
          end
        end
      end

      # This is internal method which gets and parses response packet from
      # searchd server.
      #
      # There are several exceptions which could be thrown in this method:
      #
      # * various network errors -- should be handled by caller (see +with_socket+).
      # * +SphinxResponseError+ -- incomplete reply from searchd.
      # * +SphinxInternalError+ -- searchd error.
      # * +SphinxTemporaryError+ -- temporary searchd error.
      # * +SphinxUnknownError+ -- unknows searchd error.
      #
      # Method returns an instance of <tt>Sphinx::Response</tt> class, which
      # could be used for context-based parsing of reply from the server.
      #
      def parse_response(socket, client_version)
        response = ''
        status = ver = len = 0

        # Read server reply from server. All exceptions are handled by +with_socket+.
        header = socket.read(8)
        if header.length == 8
          status, ver, len = header.unpack('n2N')
          response = socket.read(len) if len > 0
        end

        # check response
        read = response.length
        if response.empty? or read != len.to_i
          error = len > 0 \
            ? "failed to read searchd response (status=#{status}, ver=#{ver}, len=#{len}, read=#{read})" \
            : 'received zero-sized searchd response'
          raise SphinxResponseError, error
        end

        # check status
        if (status == SEARCHD_WARNING)
          wlen = response[0, 4].unpack('N*').first
          @warning = response[4, wlen]
          return response[4 + wlen, response.length - 4 - wlen]
        end

        if status == SEARCHD_ERROR
          error = 'searchd error: ' + response[4, response.length - 4]
          raise SphinxInternalError, error
        end

        if status == SEARCHD_RETRY
          error = 'temporary searchd error: ' + response[4, response.length - 4]
          raise SphinxTemporaryError, error
        end

        unless status == SEARCHD_OK
          error = "unknown status code: '#{status}'"
          raise SphinxUnknownError, error
        end

        # check version
        if ver < client_version
          @warning = "searchd command v.#{ver >> 8}.#{ver & 0xff} older than client's " +
            "v.#{client_version >> 8}.#{client_version & 0xff}, some options might not work"
        end

        Response.new(response)
      end

      # This is internal method which selects next server (round-robin)
      # and yields it to the block passed.
      #
      # In case of connection error, it will try next server several times
      # (see +SetConnectionTimeout+ method details). If all servers are down,
      # it will set +error+ attribute value with the last exception message,
      # and <tt>connection_timeout?</tt> method will return true. Also,
      # +SphinxConnectErorr+ exception will be raised.
      #
      def with_server
        attempts = @retries
        begin
          # Get the next server
          @lastserver = (@lastserver + 1) % @servers.size
          server = @servers[@lastserver]
          yield server
        rescue SphinxConnectError => e
          # Connection error! Do we need to try it again?
          attempts -= 1
          retry if attempts > 0

          # Re-raise original exception
          @error = e.message
          @connerror = true
          raise
        end
      end

      # This is internal method which retrieves socket for a given server,
      # initiates Sphinx session, and yields this socket to a block passed.
      #
      # In case of any problems with session initiation, +SphinxConnectError+
      # will be raised, because this is part of connection establishing. See
      # +with_server+ method details to get more infromation about how this
      # exception is handled.
      #
      # Socket retrieving routine is wrapped in a block with it's own
      # timeout value (see +SetConnectTimeout+). This is done in
      # <tt>Server#get_socket</tt> method, so check it for details.
      #
      # Request execution is wrapped with block with another timeout
      # (see +SetRequestTimeout+). This ensures no Sphinx request will
      # take unreasonable time.
      #
      # In case of any Sphinx error (incomplete reply, internal or temporary
      # error), connection to the server will be re-established, and request
      # will be retried (see +SetRequestTimeout+). Of course, if connection
      # could not be established, next server will be selected (see explanation
      # above).
      #
      def with_socket(server)
        attempts = @reqretries
        socket = nil

        begin
          s = server.get_socket do |sock|
            # Remember socket to close it in case of emergency
            socket = sock

            # send my version
            # this is a subtle part. we must do it before (!) reading back from searchd.
            # because otherwise under some conditions (reported on FreeBSD for instance)
            # TCP stack could throttle write-write-read pattern because of Nagle.
            sock.write([1].pack('N'))
            v = sock.read(4).unpack('N*').first

            # Ouch, invalid protocol!
            if v < 1
              raise SphinxConnectError, "expected searchd protocol version 1+, got version '#{v}'"
            end
          end

          Sphinx::safe_execute(@reqtimeout) do
            yield s
          end
        rescue SocketError, SystemCallError, IOError, ::Errno::EPIPE => e
          # Ouch, communication problem, will be treated as a connection problem.
          raise SphinxConnectError, "failed to read searchd response (msg=#{e.message})"
        rescue SphinxResponseError, SphinxInternalError, SphinxTemporaryError, SphinxUnknownError, ::Timeout::Error, EOFError => e
          # EOFError should not occur in ideal world, because we compare response length
          # with a value passed by Sphinx. But we want to ensure that client will not
          # fail with unexpected error when Sphinx implementation has bugs, aren't we?
          if e.kind_of?(EOFError) or e.kind_of?(::Timeout::Error)
            new_e = SphinxResponseError.new("failed to read searchd response (msg=#{e.message})")
            new_e.set_backtrace(e.backtrace)
            e = new_e
          end

          # Close previously opened socket (in case of it has been really opened)
          server.free_socket(socket)

          # Request error! Do we need to try it again?
          attempts -= 1
          retry if attempts > 0

          # Re-raise original exception
          @error = e.message
          raise e
        ensure
          # Close previously opened socket on any other error
          server.free_socket(socket)
        end
      end
  end
end
