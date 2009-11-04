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
  class SphinxArgumentError < SphinxError; end
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
      # per-client-object settings
      @host          = 'localhost'             # searchd host (default is "localhost")
      @port          = 3312                    # searchd port (default is 3312)
      @path          = false
      @socket        = false
      
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
    end
  
    # Get last error message.
    def GetLastError
      @error
    end
    
    # Get last warning message.
    def GetLastWarning
      @warning
    end
    
    # Get last error flag (to tell network connection errors from
    # searchd errors or broken responses)
    def IsConnectError
      @connerror
    end
    
    # Set searchd host name (string) and port (integer).
    #
    # You can specify an absolute path to Sphinx's UNIX socket as +host+, in this
    # case pass port as +0+ or +nil+.
    #
    # Otherwise +host+ should contain a host name or IP address.
    def SetServer(host, port)
      raise ArgumentError, '"host" argument must be String' unless host.kind_of?(String)
      
      # Check if UNIX socket should be used
      if host[0] == ?/
        @path = host
        return
      elsif host[0, 7] == 'unix://'
        @path = host[7..-1]
        return
      end
      
      raise ArgumentError, '"port" argument must be Integer' unless port.respond_to?(:integer?) and port.integer?

      @host = host
      @port = port
    end
    
    # Set connection timeout in seconds.
    #
    # Please note, this timeout will only be used for connection establishing, not
    # for regular API requests.
    def SetConnectTimeout(timeout, retries = 1)
      raise ArgumentError, '"timeout" argument must be Integer'        unless timeout.respond_to?(:integer?) and timeout.integer?
      raise ArgumentError, '"retries" argument must be Integer'        unless retries.respond_to?(:integer?) and retries.integer?
      raise ArgumentError, '"retries" argument must be greater than 0' unless retries > 0
      
      @timeout = timeout
      @retries = retries
    end
    
    # Set request timeout in seconds.
    #
    # Please note, this timeout will only be used for regular API requests, not
    # for connection establishing.
    def SetRequestTimeout(timeout, retries = 1)
      raise ArgumentError, '"timeout" argument must be Integer'        unless timeout.respond_to?(:integer?) and timeout.integer?
      raise ArgumentError, '"retries" argument must be Integer'        unless retries.respond_to?(:integer?) and retries.integer?
      raise ArgumentError, '"retries" argument must be greater than 0' unless retries > 0
      
      @reqtimeout = timeout
      @reqretries = retries
    end
   
    # Set offset and count into result set,
    # and optionally set max-matches and cutoff limits.
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
    
    # Set maximum query time, in milliseconds, per-index,
    # integer, 0 means "do not limit"
    def SetMaxQueryTime(max)
      raise ArgumentError, '"max" argument must be Integer' unless max.respond_to?(:integer?) and max.integer?
      raise ArgumentError, '"max" argument should be greater or equal to zero' unless max >= 0

      @maxquerytime = max
    end
    
    # Set matching mode.
    #
    # You can specify mode as String ("all", "any", etc), Symbol (:all, :any, etc), or
    # Fixnum constant (SPH_MATCH_ALL, SPH_MATCH_ANY, etc).
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
    def SetGroupDistinct(attribute)
      raise ArgumentError, '"attribute" argument must be String or Symbol' unless attribute.kind_of?(String)  or attribute.kind_of?(Symbol)

      @groupdistinct = attribute.to_s
    end
    
    # Set distributed retries count and delay.
    def SetRetries(count, delay = 0)
      raise ArgumentError, '"count" argument must be Integer' unless count.respond_to?(:integer?) and count.integer?
      raise ArgumentError, '"delay" argument must be Integer' unless delay.respond_to?(:integer?) and delay.integer?
      
      @retrycount = count
      @retrydelay = delay
    end
    
    # Set attribute values override
    #
    # There can be only one override per attribute.
    # +values+ must be a hash that maps document IDs to attribute values.
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

    # Set select-list (attributes or expressions), SQL-like syntax.
    def SetSelect(select)
      raise ArgumentError, '"select" argument must be String' unless select.kind_of?(String)

      @select = select
    end
    
    # Clear all filters (for multi-queries).
    def ResetFilters
      @filters = []
      @anchor = []
    end
    
    # Clear groupby settings (for multi-queries).
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
    def RunQueries
      if @reqs.empty?
        @error = 'No queries defined, issue AddQuery() first'
        return false
      end

      req = @reqs.join('')
      nreqs = @reqs.length
      @reqs = []
      response = PerformRequest(:search, req, nreqs)
     
      # parse response
      begin
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
      #rescue EOFError
      #  @error = 'incomplete reply'
      #  raise SphinxResponseError, @error
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
      request.put_string *docs
      
      response = PerformRequest(:excerpt, request)
      
      # parse response
      begin
        res = []
        docs.each do |doc|
          res << response.get_string
        end
      rescue EOFError
        @error = 'incomplete reply'
        raise SphinxResponseError, @error
      end
      return res
    end
    
    # Connect to searchd server, and generate keyword list for a given query.
    #
    # Returns an array of words on success.
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

      response = PerformRequest(:keywords, request)
      
      # parse response
      begin
        res = []
        nwords = response.get_int
        0.upto(nwords - 1) do |i|
          tokenized = response.get_string
          normalized = response.get_string
          
          entry = { 'tokenized' => tokenized, 'normalized' => normalized }
          entry['docs'], entry['hits'] = response.get_ints(2) if hits
          
          res << entry
        end
      rescue EOFError
        @error = 'incomplete reply'
        raise SphinxResponseError, @error
      end
      
      return res
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
      
      response = PerformRequest(:update, request)
      
      # parse response
      begin
        return response.get_int
      rescue EOFError
        @error = 'incomplete reply'
        raise SphinxResponseError, @error
      end
    end
    
    # persistent connections
    
    def Open
      unless @socket === false
        @error = 'already connected'
        return false
      end
      
      request = Request.new
      request.put_int(1)
      @socket = PerformRequest(:persist, request, nil, true)

      true
    end
    
    def Close
      if @socket === false
        @error = 'not connected'
        return false;
      end
      
      @socket.close if !@socket.closed?
      @socket = false
      
      true
    end
    
    def Status
      request = Request.new
      request.put_int(1)
      response = PerformRequest(:status, request)

      # parse response
      begin
        rows, cols = response.get_ints(2)
      
        res = []
        0.upto(rows - 1) do |i|
          res[i] = []
          0.upto(cols - 1) do |j|
            res[i] << response.get_string
          end
        end
      rescue EOFError
        @error = 'incomplete reply'
        raise SphinxResponseError, @error
      end
      
      res
    end
    
    def FlushAttrs
      request = Request.new
      response = PerformRequest(:flushattrs, request)

      # parse response
      begin
        response.get_int
      rescue EOFError
        -1
      end
    end
  
    protected
    
      # Connect to searchd server.
      def Connect
        return @socket unless @socket === false
        
        sock = nil
        begin
          Sphinx::safe_execute(@timeout, @retries) do
            if @path
              sock = UNIXSocket.new(@path)
            else
              sock = TCPSocket.new(@host, @port)
            end
          end
        rescue SocketError, SystemCallError, IOError, ::Timeout::Error => e
          location = @path || "#{@host}:#{@port}"
          @error = "connection to #{location} failed ("
          if e.kind_of?(SystemCallError)
            @error << "errno=#{e.class::Errno}, "
          end
          @error << "msg=#{e.message})"
          @connerror = true
          raise SphinxConnectError, @error
        end

        io = Sphinx::BufferedIO.new(sock)
        io.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        if @reqtimeout > 0
          io.read_timeout = @reqtimeout
          
          # This is a part of memcache-client library.
          #
          # Getting reports from several customers, including 37signals,
          # that the non-blocking timeouts in 1.7.5 don't seem to be reliable.
          # It can't hurt to set the underlying socket timeout also, if possible.
          if timeout
            secs = Integer(timeout)
            usecs = Integer((timeout - secs) * 1_000_000)
            optval = [secs, usecs].pack("l_2")
            begin
              io.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval
              io.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, optval
            rescue Exception => ex
              # Solaris, for one, does not like/support socket timeouts.
              @warning = "Unable to use raw socket timeouts: #{ex.class.name}: #{ex.message}"
            end
          end
        else
          io.read_timeout = false
        end

        # send my version
        # this is a subtle part. we must do it before (!) reading back from searchd.
        # because otherwise under some conditions (reported on FreeBSD for instance)
        # TCP stack could throttle write-write-read pattern because of Nagle.
        io.write([1].pack('N'))
        
        v = io.read(4).unpack('N*').first
        if v < 1
          io.close
          @error = "expected searchd protocol version 1+, got version '#{v}'"
          raise SphinxConnectError, @error
        end
        
        io
      end
      
      # Get and check response packet from searchd server.
      def GetResponse(sock, client_version)
        response = ''
        len = 0
        
        header = sock.read(8, '', true)
        if header.length == 8
          status, ver, len = header.unpack('n2N')
          response = sock.read(len, '', true) if len > 0
        end
        sock.close if @socket === false and !sock.closed?
    
        # check response
        read = response.length
        if response.empty? or read != len.to_i
          @error = len \
            ? "failed to read searchd response (status=#{status}, ver=#{ver}, len=#{len}, read=#{read})" \
            : 'received zero-sized searchd response'
          raise SphinxResponseError, @error
        end
        
        # check status
        if (status == SEARCHD_WARNING)
          wlen = response[0, 4].unpack('N*').first
          @warning = response[4, wlen]
          return response[4 + wlen, response.length - 4 - wlen]
        end

        if status == SEARCHD_ERROR
          @error = 'searchd error: ' + response[4, response.length - 4]
          raise SphinxInternalError, @error
        end
    
        if status == SEARCHD_RETRY
          @error = 'temporary searchd error: ' + response[4, response.length - 4]
          raise SphinxTemporaryError, @error
        end
    
        unless status == SEARCHD_OK
          @error = "unknown status code: '#{status}'"
          raise SphinxUnknownError, @error
        end
        
        # check version
        if ver < client_version
          @warning = "searchd command v.#{ver >> 8}.#{ver & 0xff} older than client's " +
            "v.#{client_version >> 8}.#{client_version & 0xff}, some options might not work"
        end
        
        return response
      end
      
      # Connect, send query, get response.
      def PerformRequest(command, request, additional = nil, skip_response = false)
        cmd = command.to_s.upcase
        command_id = Sphinx::Client.const_get('SEARCHD_COMMAND_' + cmd)
        command_ver = Sphinx::Client.const_get('VER_COMMAND_' + cmd)
        
        sock = self.Connect
        len = request.to_s.length + (additional != nil ? 4 : 0)
        header = [command_id, command_ver, len].pack('nnN')
        header << [additional].pack('N') if additional != nil
        
        Sphinx::safe_execute(@reqtimeout, @reqretries) do
          sock.write(header + request.to_s)
        
          skip_response ? sock : Response.new(self.GetResponse(sock, command_ver))
        end
      end
  end
end
