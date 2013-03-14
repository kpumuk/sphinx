module Sphinx
  # The Sphinx Client API is used to communicate with <tt>searchd</tt>
  # daemon and perform requests.
  #
  # @example
  #   sphinx = Sphinx::Client.new
  #   result = sphinx.query('test')
  #   ids = result['matches'].map { |match| match['id'] }
  #   posts = Post.all :conditions => { :id => ids },
  #                    :order => "FIELD(id,#{ids.join(',')})"
  #
  #   docs = posts.map(&:body)
  #   excerpts = sphinx.build_excerpts(docs, 'index', 'test')
  #
  class Client
    include Sphinx::Constants

    #=================================================================
    # Some internal attributes to use inside client API
    #=================================================================

    # List of searchd servers to connect to.
    # @private
    attr_reader :servers
    # Connection timeout in seconds.
    # @private
    attr_reader :timeout
    # Number of connection retries.
    # @private
    attr_reader :retries
    # Request timeout in seconds.
    # @private
    attr_reader :reqtimeout
    # Number of request retries.
    # @private
    attr_reader :reqretries
    # Log debug/info/warn to the given Logger, defaults to nil.
    # @private
    attr_reader :logger

    # Constructs the <tt>Sphinx::Client</tt> object and sets options
    # to their default values.
    #
    # @param [Logger] logger a logger object to put logs to. No logging
    #   will be performed when not set.
    #
    def initialize(logger = nil)
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
      @servers       = [Sphinx::Server.new(self, 'localhost', 9312, false)].freeze
      @logger        = logger

      logger.info { "[sphinx] version: #{VERSION}, #{@servers.inspect}" } if logger
    end

    # Returns a string representation of the sphinx client object.
    #
    def inspect
      params = {
        :error => @error,
        :warning => @warning,
        :connect_error => @connerror,
        :servers => @servers,
        :connect_timeout => { :timeout => @timeout, :retries => @retries },
        :request_timeout => { :timeout => @reqtimeout, :retries => @reqretries },
        :retries => { :count => @retrycount, :delay => @retrydelay },
        :limits => { :offset => @offset, :limit => @limit, :max => @maxmatches, :cutoff => @cutoff },
        :max_query_time => @maxquerytime,
        :overrides => @overrides,
        :select => @select,
        :match_mode => @mode,
        :ranking_mode => @ranker,
        :sort_mode => { :mode => @sort, :sortby => @sortby },
        :weights => @weights,
        :field_weights => @fieldweights,
        :index_weights => @indexweights,
        :id_range => { :min => @min_id, :max => @max_id },
        :filters => @filters,
        :geo_anchor => @anchor,
        :group_by => { :attribute => @groupby, :func => @groupfunc, :sort => @groupsort },
        :group_distinct => @groupdistinct
      }

      "<Sphinx::Client: %d servers, params: %s>" %
        [@servers.length, params.inspect]
    end

    #=================================================================
    # General API functions
    #=================================================================

    # Returns last error message, as a string, in human readable format. If there
    # were no errors during the previous API call, empty string is returned.
    #
    # You should call it when any other function (such as {#query}) fails (typically,
    # the failing function returns false). The returned string will contain the
    # error description.
    #
    # The error message is not reset by this call; so you can safely call it
    # several times if needed.
    #
    # @return [String] last error message.
    #
    # @example
    #   puts sphinx.last_error
    #
    # @see #last_warning
    # @see #connect_error?
    #
    def last_error
      @error
    end
    alias :GetLastError :last_error

    # Returns last warning message, as a string, in human readable format. If there
    # were no warnings during the previous API call, empty string is returned.
    #
    # You should call it to verify whether your request (such as {#query}) was
    # completed but with warnings. For instance, search query against a distributed
    # index might complete succesfully even if several remote agents timed out.
    # In that case, a warning message would be produced.
    #
    # The warning message is not reset by this call; so you can safely call it
    # several times if needed.
    #
    # @return [String] last warning message.
    #
    # @example
    #   puts sphinx.last_warning
    #
    # @see #last_error
    # @see #connect_error?
    #
    def last_warning
      @warning
    end
    alias :GetLastWarning :last_warning

    # Checks whether the last error was a network error on API side, or a
    # remote error reported by searchd. Returns true if the last connection
    # attempt to searchd failed on API side, false otherwise (if the error
    # was remote, or there were no connection attempts at all).
    #
    # @return [Boolean] the value indicating whether last error was a
    #   nework error on API side.
    #
    # @example
    #   puts "Connection failed!" if sphinx.connect_error?
    #
    # @see #last_error
    # @see #last_warning
    #
    def connect_error?
      @connerror || false
    end
    alias :IsConnectError :connect_error?

    # Sets searchd host name and TCP port. All subsequent requests will
    # use the new host and port settings. Default +host+ and +port+ are
    # 'localhost' and 9312, respectively.
    #
    # Also, you can specify an absolute path to Sphinx's UNIX socket as +host+,
    # in this case pass port as +0+ or +nil+.
    #
    # @param [String] host the searchd host name or UNIX socket absolute path.
    # @param [Integer] port the searchd port name (could be any if UNIX
    #   socket path specified).
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_server('localhost', 9312)
    #   sphinx.set_server('/opt/sphinx/var/run/sphinx.sock')
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    # @see #set_servers
    # @see #set_connect_timeout
    # @see #set_request_timeout
    #
    def set_server(host, port = 9312)
      raise ArgumentError, '"host" argument must be String' unless host.kind_of?(String)

      path = nil
      # Check if UNIX socket should be used
      if host[0] == ?/
        path = host
      elsif host[0, 7] == 'unix://'
        path = host[7..-1]
      else
        raise ArgumentError, '"port" argument must be Integer' unless port.kind_of?(Integer)
      end

      host = port = nil unless path.nil?

      @servers = [Sphinx::Server.new(self, host, port, path)].freeze
      logger.info { "[sphinx] servers now: #{@servers.inspect}" } if logger
      self
    end
    alias :SetServer :set_server

    # Sets the list of searchd servers. Each subsequent request will use next
    # server in list (round-robin). In case of one server failure, request could
    # be retried on another server (see {#set_connect_timeout} and
    # {#set_request_timeout}).
    #
    # Method accepts an +Array+ of +Hash+es, each of them should have <tt>:host</tt>
    # and <tt>:port</tt> (to connect to searchd through network) or <tt>:path</tt>
    # (an absolute path to UNIX socket) specified.
    #
    # @param [Array<Hash>] servers an +Array+ of +Hash+ objects with servers parameters.
    # @option servers [String] :host the searchd host name or UNIX socket absolute path.
    # @option servers [String] :path the searchd UNIX socket absolute path.
    # @option servers [Integer] :port (9312) the searchd port name (skiped when UNIX
    #   socket path specified)
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_servers([
    #     { :host => 'browse01.local' }, # default port is 9312
    #     { :host => 'browse02.local', :port => 9312 },
    #     { :path => '/opt/sphinx/var/run/sphinx.sock' }
    #   ])
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    # @see #set_server
    # @see #set_connect_timeout
    # @see #set_request_timeout
    #
    def set_servers(servers)
      raise ArgumentError, '"servers" argument must be Array'     unless servers.kind_of?(Array)
      raise ArgumentError, '"servers" argument must be not empty' if servers.empty?

      @servers = servers.map do |server|
        raise ArgumentError, '"servers" argument must be Array of Hashes' unless server.kind_of?(Hash)

        server = server.with_indifferent_access

        host = server[:path] || server[:host]
        port = server[:port] || 9312
        path = nil
        raise ArgumentError, '"host" argument must be String' unless host.kind_of?(String)

        # Check if UNIX socket should be used
        if host[0] == ?/
          path = host
        elsif host[0, 7] == 'unix://'
          path = host[7..-1]
        else
          raise ArgumentError, '"port" argument must be Integer' unless port.kind_of?(Integer)
        end

        host = port = nil unless path.nil?

        Sphinx::Server.new(self, host, port, path)
      end.freeze
      logger.info { "[sphinx] servers now: #{@servers.inspect}" } if logger
      self
    end
    alias :SetServers :set_servers

    # Sets the time allowed to spend connecting to the server before giving up
    # and number of retries to perform.
    #
    # In the event of a failure to connect, an appropriate error code should
    # be returned back to the application in order for application-level error
    # handling to advise the user.
    #
    # When multiple servers configured through {#set_servers} method, and +retries+
    # number is greater than 1, library will try to connect to another server.
    # In case of single server configured, it will try to reconnect +retries+
    # times.
    #
    # Please note, this timeout will only be used for connection establishing, not
    # for regular API requests.
    #
    # @param [Integer] timeout a connection timeout in seconds.
    # @param [Integer] retries number of connect retries.
    # @return [Sphinx::Client] self.
    #
    # @example Set connection timeout to 1 second and number of retries to 5
    #   sphinx.set_connect_timeout(1, 5)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    # @see #set_server
    # @see #set_servers
    # @see #set_request_timeout
    #
    def set_connect_timeout(timeout, retries = 1)
      raise ArgumentError, '"timeout" argument must be Integer'        unless timeout.kind_of?(Integer)
      raise ArgumentError, '"retries" argument must be Integer'        unless retries.kind_of?(Integer)
      raise ArgumentError, '"retries" argument must be greater than 0' unless retries > 0

      @timeout = timeout
      @retries = retries
      self
    end
    alias :SetConnectTimeout :set_connect_timeout

    # Sets the time allowed to spend performing request to the server before giving up
    # and number of retries to perform.
    #
    # In the event of a failure to do request, an appropriate error code should
    # be returned back to the application in order for application-level error
    # handling to advise the user.
    #
    # When multiple servers configured through {#set_servers} method, and +retries+
    # number is greater than 1, library will try to do another try with this server
    # (with full reconnect). If connection would fail, behavior depends on
    # {#set_connect_timeout} settings.
    #
    # Please note, this timeout will only be used for request performing, not
    # for connection establishing.
    #
    # @param [Integer] timeout a request timeout in seconds.
    # @param [Integer] retries number of request retries.
    # @return [Sphinx::Client] self.
    #
    # @example Set request timeout to 1 second and number of retries to 5
    #   sphinx.set_request_timeout(1, 5)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    # @see #set_server
    # @see #set_servers
    # @see #set_connect_timeout
    #
    def set_request_timeout(timeout, retries = 1)
      raise ArgumentError, '"timeout" argument must be Integer'        unless timeout.kind_of?(Integer)
      raise ArgumentError, '"retries" argument must be Integer'        unless retries.kind_of?(Integer)
      raise ArgumentError, '"retries" argument must be greater than 0' unless retries > 0

      @reqtimeout = timeout
      @reqretries = retries
      self
    end
    alias :SetRequestTimeout :set_request_timeout

    # Sets distributed retry count and delay.
    #
    # On temporary failures searchd will attempt up to +count+ retries
    # per agent. +delay+ is the delay between the retries, in milliseconds.
    # Retries are disabled by default. Note that this call will not make
    # the API itself retry on temporary failure; it only tells searchd
    # to do so. Currently, the list of temporary failures includes all
    # kinds of connection failures and maxed out (too busy) remote agents.
    #
    # @param [Integer] count a number of retries to perform.
    # @param [Integer] delay a delay between the retries.
    # @return [Sphinx::Client] self.
    #
    # @example Perform 5 retries with 200 ms between them
    #   sphinx.set_retries(5, 200)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    # @see #set_connect_timeout
    # @see #set_request_timeout
    #
    def set_retries(count, delay = 0)
      raise ArgumentError, '"count" argument must be Integer' unless count.kind_of?(Integer)
      raise ArgumentError, '"delay" argument must be Integer' unless delay.kind_of?(Integer)

      @retrycount = count
      @retrydelay = delay
      self
    end
    alias :SetRetries :set_retries

    #=================================================================
    # General query settings
    #=================================================================

    # Sets offset into server-side result set (+offset+) and amount of matches to
    # return to client starting from that offset (+limit+). Can additionally control
    # maximum server-side result set size for current query (+max_matches+) and the
    # threshold amount of matches to stop searching at (+cutoff+). All parameters
    # must be non-negative integers.
    #
    # First two parameters to {#set_limits} are identical in behavior to MySQL LIMIT
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
    # @param [Integer] offset an offset into server-side result set.
    # @param [Integer] limit an amount of matches to return.
    # @param [Integer] max a maximum server-side result set size.
    # @param [Integer] cutoff a threshold amount of matches to stop searching at.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_limits(100, 50, 1000, 5000)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    def set_limits(offset, limit, max = 0, cutoff = 0)
      raise ArgumentError, '"offset" argument must be Integer' unless offset.kind_of?(Integer)
      raise ArgumentError, '"limit" argument must be Integer'  unless limit.kind_of?(Integer)
      raise ArgumentError, '"max" argument must be Integer'    unless max.kind_of?(Integer)
      raise ArgumentError, '"cutoff" argument must be Integer' unless cutoff.kind_of?(Integer)

      raise ArgumentError, '"offset" argument should be greater or equal to zero' unless offset >= 0
      raise ArgumentError, '"limit" argument should be greater to zero'           unless limit > 0
      raise ArgumentError, '"max" argument should be greater or equal to zero'    unless max >= 0
      raise ArgumentError, '"cutoff" argument should be greater or equal to zero' unless cutoff >= 0

      @offset = offset
      @limit = limit
      @maxmatches = max if max > 0
      @cutoff = cutoff if cutoff > 0
      self
    end
    alias :SetLimits :set_limits

    # Sets maximum search query time, in milliseconds. Parameter must be a
    # non-negative integer. Default valus is +0+ which means "do not limit".
    #
    # Similar to +cutoff+ setting from {#set_limits}, but limits elapsed query
    # time instead of processed matches count. Local search queries will be
    # stopped once that much time has elapsed. Note that if you're performing
    # a search which queries several local indexes, this limit applies to each
    # index separately.
    #
    # @param [Integer] max maximum search query time in milliseconds.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_max_query_time(200)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    def set_max_query_time(max)
      raise ArgumentError, '"max" argument must be Integer' unless max.kind_of?(Integer)
      raise ArgumentError, '"max" argument should be greater or equal to zero' unless max >= 0

      @maxquerytime = max
      self
    end
    alias :SetMaxQueryTime :set_max_query_time

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
    # You can specify attribute type as String ("integer", "float", etc),
    # Symbol (:integer, :float, etc), or
    # Fixnum constant (SPH_ATTR_INTEGER, SPH_ATTR_FLOAT, etc).
    #
    # @param [String, Symbol] attribute an attribute name to override values of.
    # @param [Integer, String, Symbol] attrtype attribute type.
    # @param [Hash] values a +Hash+ that maps document IDs to overridden attribute values.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_override(:friends_weight, :integer, {123 => 1, 456 => 1, 789 => 1})
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setoverride Section 6.2.3, "SetOverride"
    #
    def set_override(attribute, attrtype, values)
      raise ArgumentError, '"attribute" argument must be String or Symbol' unless attribute.kind_of?(String) or attribute.kind_of?(Symbol)

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
        raise ArgumentError, '"values" argument must be Hash map of Integer to Integer or Time' unless id.kind_of?(Integer)
        case attrtype
          when SPH_ATTR_TIMESTAMP
            raise ArgumentError, '"values" argument must be Hash map of Integer to Numeric' unless value.kind_of?(Integer) or value.kind_of?(Time)
          when SPH_ATTR_FLOAT
            raise ArgumentError, '"values" argument must be Hash map of Integer to Numeric' unless value.kind_of?(Numeric)
          else
            # SPH_ATTR_INTEGER, SPH_ATTR_ORDINAL, SPH_ATTR_BOOL, SPH_ATTR_BIGINT
            raise ArgumentError, '"values" argument must be Hash map of Integer to Integer' unless value.kind_of?(Integer)
        end
      end

      @overrides << { 'attr' => attribute.to_s, 'type' => attrtype, 'values' => values }
      self
    end
    alias :SetOverride :set_override

    # Sets the select clause, listing specific attributes to fetch, and
    # expressions to compute and fetch. Clause syntax mimics SQL.
    #
    # {#set_select} is very similar to the part of a typical SQL query between
    # +SELECT+ and +FROM+. It lets you choose what attributes (columns) to
    # fetch, and also what expressions over the columns to compute and fetch.
    # A certain difference from SQL is that expressions must always be aliased
    # to a correct identifier (consisting of letters and digits) using +AS+
    # keyword. SQL also lets you do that but does not require to. Sphinx enforces
    # aliases so that the computation results can always be returned under a
    # "normal" name in the result set, used in other clauses, etc.
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
    # functions ({#set_geo_anchor}) are now internally implemented
    # using this computed expressions mechanism, using magic names '<tt>@expr</tt>'
    # and '<tt>@geodist</tt>' respectively.
    #
    # @param [String] select a select clause, listing specific attributes to fetch.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_select('*, @weight+(user_karma+ln(pageviews))*0.1 AS myweight')
    #   sphinx.set_select('exp_years, salary_gbp*{$gbp_usd_rate} AS salary_usd, IF(age>40,1,0) AS over40')
    #   sphinx.set_select('*, AVG(price) AS avgprice')
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#sort-expr Section 4.5, "SPH_SORT_EXPR mode"
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setgeoanchor Section 6.4.5, "SetGeoAnchor"
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setselect Section 6.2.4, "SetSelect"
    #
    def set_select(select)
      raise ArgumentError, '"select" argument must be String' unless select.kind_of?(String)

      @select = select
      self
    end
    alias :SetSelect :set_select

    #=================================================================
    # Full-text search query settings
    #=================================================================

    # Sets full-text query matching mode.
    #
    # Parameter must be a +Fixnum+ constant specifying one of the known modes
    # (+SPH_MATCH_ALL+, +SPH_MATCH_ANY+, etc), +String+ with identifier (<tt>"all"</tt>,
    # <tt>"any"</tt>, etc), or a +Symbol+ (<tt>:all</tt>, <tt>:any</tt>, etc).
    #
    # @param [Integer, String, Symbol] mode full-text query matching mode.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_match_mode(Sphinx::SPH_MATCH_ALL)
    #   sphinx.set_match_mode(:all)
    #   sphinx.set_match_mode('all')
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#matching-modes Section 4.1, "Matching modes"
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setmatchmode Section 6.3.1, "SetMatchMode"
    #
    def set_match_mode(mode)
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
      self
    end
    alias :SetMatchMode :set_match_mode

    # Sets ranking mode. Only available in +SPH_MATCH_EXTENDED2+
    # matching mode at the time of this writing. Parameter must be a
    # constant specifying one of the known modes.
    #
    # You can specify ranking mode as String ("proximity_bm25", "bm25", etc),
    # Symbol (:proximity_bm25, :bm25, etc), or
    # Fixnum constant (SPH_RANK_PROXIMITY_BM25, SPH_RANK_BM25, etc).
    #
    # @param [Integer, String, Symbol] ranker ranking mode.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_ranking_mode(Sphinx::SPH_RANK_BM25)
    #   sphinx.set_ranking_mode(:bm25)
    #   sphinx.set_ranking_mode('bm25')
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#matching-modes Section 4.1, "Matching modes"
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setmatchmode Section 6.3.1, "SetMatchMode"
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setrankingmode Section 6.3.2, "SetRankingMode"
    #
    def set_ranking_mode(ranker)
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
      self
    end
    alias :SetRankingMode :set_ranking_mode

    # Set matches sorting mode.
    #
    # You can specify sorting mode as String ("relevance", "attr_desc", etc),
    # Symbol (:relevance, :attr_desc, etc), or
    # Fixnum constant (SPH_SORT_RELEVANCE, SPH_SORT_ATTR_DESC, etc).
    #
    # @param [Integer, String, Symbol] mode matches sorting mode.
    # @param [String] sortby sorting clause, with the syntax depending on
    #   specific mode. Should be specified unless sorting mode is
    #   +SPH_SORT_RELEVANCE+.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_sort_mode(Sphinx::SPH_SORT_ATTR_ASC, 'attr')
    #   sphinx.set_sort_mode(:attr_asc, 'attr')
    #   sphinx.set_sort_mode('attr_asc', 'attr')
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#sorting-modes Section 4.5, "Sorting modes"
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setsortmode Section 6.3.3, "SetSortMode"
    #
    def set_sort_mode(mode, sortby = '')
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
      self
    end
    alias :SetSortMode :set_sort_mode

    # Binds per-field weights in the order of appearance in the index.
    #
    # @param [Array<Integer>] weights an +Array+ of integer per-field weights.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_weights([1, 3, 5])
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @deprecated Use {#set_field_weights} instead.
    # @see #set_field_weights
    #
    def set_weights(weights)
      raise ArgumentError, '"weights" argument must be Array' unless weights.kind_of?(Array)
      weights.each do |weight|
        raise ArgumentError, '"weights" argument must be Array of integers' unless weight.kind_of?(Integer)
      end

      @weights = weights
      self
    end
    alias :SetWeights :set_weights

    # Binds per-field weights by name. Parameter must be a +Hash+
    # mapping string field names to integer weights.
    #
    # Match ranking can be affected by per-field weights. For instance,
    # see Section 4.4, "Weighting" for an explanation how phrase
    # proximity ranking is affected. This call lets you specify what
    # non-default weights to assign to different full-text fields.
    #
    # The weights must be positive 32-bit integers. The final weight
    # will be a 32-bit integer too. Default weight value is 1. Unknown
    # field names will be silently ignored.
    #
    # There is no enforced limit on the maximum weight value at the
    # moment. However, beware that if you set it too high you can
    # start hitting 32-bit wraparound issues. For instance, if
    # you set a weight of 10,000,000 and search in extended mode,
    # then maximum possible weight will be equal to 10 million (your
    # weight) by 1 thousand (internal BM25 scaling factor, see
    # Section 4.4, “Weighting”) by 1 or more (phrase proximity rank).
    # The result is at least 10 billion that does not fit in 32 bits
    # and will be wrapped around, producing unexpected results.
    #
    # @param [Hash] weights a +Hash+ mapping string field names to
    #   integer weights.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_field_weights(:title => 20, :text => 10)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#weighting Section 4.4, "Weighting"
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setfieldweights Section 6.3.5, "SetFieldWeights"
    #
    def set_field_weights(weights)
      raise ArgumentError, '"weights" argument must be Hash' unless weights.kind_of?(Hash)
      weights.each do |name, weight|
        unless (name.kind_of?(String) or name.kind_of?(Symbol)) and weight.kind_of?(Integer)
          raise ArgumentError, '"weights" argument must be Hash map of strings to integers'
        end
      end

      @fieldweights = weights
      self
    end
    alias :SetFieldWeights :set_field_weights

    # Sets per-index weights, and enables weighted summing of match
    # weights across different indexes. Parameter must be a hash
    # (associative array) mapping string index names to integer
    # weights. Default is empty array that means to disable weighting
    # summing.
    #
    # When a match with the same document ID is found in several
    # different local indexes, by default Sphinx simply chooses the
    # match from the index specified last in the query. This is to
    # support searching through partially overlapping index partitions.
    #
    # However in some cases the indexes are not just partitions,
    # and you might want to sum the weights across the indexes
    # instead of picking one. {#set_index_weights} lets you do that.
    # With summing enabled, final match weight in result set will be
    # computed as a sum of match weight coming from the given index
    # multiplied by respective per-index weight specified in this
    # call. Ie. if the document 123 is found in index A with the
    # weight of 2, and also in index B with the weight of 3, and
    # you called {#set_index_weights} with <tt>{"A"=>100, "B"=>10}</tt>,
    # the final weight return to the client will be 2*100+3*10 = 230.
    #
    # @param [Hash] weights a +Hash+ mapping string index names to
    #   integer weights.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_field_weights(:fresh => 20, :archived => 10)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setindexweights Section 6.3.6, "SetIndexWeights"
    #
    def set_index_weights(weights)
      raise ArgumentError, '"weights" argument must be Hash' unless weights.kind_of?(Hash)
      weights.each do |index, weight|
        unless (index.kind_of?(String) or index.kind_of?(Symbol)) and weight.kind_of?(Integer)
          raise ArgumentError, '"weights" argument must be Hash map of strings to integers'
        end
      end

      @indexweights = weights
      self
    end
    alias :SetIndexWeights :set_index_weights

    #=================================================================
    # Result set filtering settings
    #=================================================================

    # Sets an accepted range of document IDs. Parameters must be integers.
    # Defaults are 0 and 0; that combination means to not limit by range.
    #
    # After this call, only those records that have document ID between
    # +min+ and +max+ (including IDs exactly equal to +min+ or +max+)
    # will be matched.
    #
    # @param [Integer] min min document ID.
    # @param [Integer] min max document ID.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_id_range(10, 1000)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setidrange Section 6.4.1, "SetIDRange"
    #
    def set_id_range(min, max)
      raise ArgumentError, '"min" argument must be Integer' unless min.kind_of?(Integer)
      raise ArgumentError, '"max" argument must be Integer' unless max.kind_of?(Integer)
      raise ArgumentError, '"max" argument greater or equal to "min"' unless min <= max

      @min_id = min
      @max_id = max
      self
    end
    alias :SetIDRange :set_id_range

    # Adds new integer values set filter.
    #
    # On this call, additional new filter is added to the existing
    # list of filters. $attribute must be a string with attribute
    # name. +values+ must be a plain array containing integer
    # values. +exclude+ must be a boolean value; it controls
    # whether to accept the matching documents (default mode, when
    # +exclude+ is +false+) or reject them.
    #
    # Only those documents where +attribute+ column value stored in
    # the index matches any of the values from +values+ array will
    # be matched (or rejected, if +exclude+ is +true+).
    #
    # @param [String, Symbol] attribute an attribute name to filter by.
    # @param [Array<Integer>, Integer] values an +Array+ of integers or
    #   single Integer with given attribute values.
    # @param [Boolean] exclude indicating whether documents with given attribute
    #   matching specified values should be excluded from search results.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_filter(:group_id, [10, 15, 20])
    #   sphinx.set_filter(:group_id, [10, 15, 20], true)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setfilter Section 6.4.2, "SetFilter"
    # @see #set_filter_range
    # @see #set_filter_float_range
    #
    def set_filter(attribute, values, exclude = false)
      raise ArgumentError, '"attribute" argument must be String or Symbol' unless attribute.kind_of?(String) or attribute.kind_of?(Symbol)
      values = [values] if values.kind_of?(Integer)
      raise ArgumentError, '"values" argument must be Array'               unless values.kind_of?(Array)
      raise ArgumentError, '"values" argument must be Array of Integers'   unless values.all? { |v| v.kind_of?(Integer) }
      raise ArgumentError, '"exclude" argument must be Boolean'            unless [TrueClass, FalseClass].include?(exclude.class)

      if values.any?
        @filters << { 'type' => SPH_FILTER_VALUES, 'attr' => attribute.to_s, 'exclude' => exclude, 'values' => values }
      end
      self
    end
    alias :SetFilter :set_filter

    # Adds new integer range filter.
    #
    # On this call, additional new filter is added to the existing
    # list of filters. +attribute+ must be a string with attribute
    # name. +min+ and +max+ must be integers that define the acceptable
    # attribute values range (including the boundaries). +exclude+
    # must be a boolean value; it controls whether to accept the
    # matching documents (default mode, when +exclude+ is false) or
    # reject them.
    #
    # Only those documents where +attribute+ column value stored
    # in the index is between +min+ and +max+ (including values
    # that are exactly equal to +min+ or +max+) will be matched
    # (or rejected, if +exclude+ is true).
    #
    # @param [String, Symbol] attribute an attribute name to filter by.
    # @param [Integer] min min value of the given attribute.
    # @param [Integer] max max value of the given attribute.
    # @param [Boolean] exclude indicating whether documents with given attribute
    #   matching specified boundaries should be excluded from search results.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_filter_range(:group_id, 10, 20)
    #   sphinx.set_filter_range(:group_id, 10, 20, true)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setfilterrange Section 6.4.3, "SetFilterRange"
    # @see #set_filter
    # @see #set_filter_float_range
    #
    def set_filter_range(attribute, min, max, exclude = false)
      raise ArgumentError, '"attribute" argument must be String or Symbol' unless attribute.kind_of?(String) or attribute.kind_of?(Symbol)
      raise ArgumentError, '"min" argument must be Integer'                unless min.kind_of?(Integer)
      raise ArgumentError, '"max" argument must be Integer'                unless max.kind_of?(Integer)
      raise ArgumentError, '"max" argument greater or equal to "min"'      unless min <= max
      raise ArgumentError, '"exclude" argument must be Boolean'            unless exclude.kind_of?(TrueClass) or exclude.kind_of?(FalseClass)

      @filters << { 'type' => SPH_FILTER_RANGE, 'attr' => attribute.to_s, 'exclude' => exclude, 'min' => min, 'max' => max }
      self
    end
    alias :SetFilterRange :set_filter_range

    # Adds new float range filter.
    #
    # On this call, additional new filter is added to the existing
    # list of filters. +attribute+ must be a string with attribute name.
    # +min+ and +max+ must be floats that define the acceptable
    # attribute values range (including the boundaries). +exclude+ must
    # be a boolean value; it controls whether to accept the matching
    # documents (default mode, when +exclude+ is false) or reject them.
    #
    # Only those documents where +attribute+ column value stored in
    # the index is between +min+ and +max+ (including values that are
    # exactly equal to +min+ or +max+) will be matched (or rejected,
    # if +exclude+ is true).
    #
    # @param [String, Symbol] attribute an attribute name to filter by.
    # @param [Numeric] min min value of the given attribute.
    # @param [Numeric] max max value of the given attribute.
    # @param [Boolean] exclude indicating whether documents with given attribute
    #   matching specified boundaries should be excluded from search results.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_filter_float_range(:group_id, 10.5, 20)
    #   sphinx.set_filter_float_range(:group_id, 10.5, 20, true)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setfilterfloatrange Section 6.4.4, "SetFilterFloatRange"
    # @see #set_filter
    # @see #set_filter_range
    #
    def set_filter_float_range(attribute, min, max, exclude = false)
      raise ArgumentError, '"attribute" argument must be String or Symbol' unless attribute.kind_of?(String) or attribute.kind_of?(Symbol)
      raise ArgumentError, '"min" argument must be Numeric'                unless min.kind_of?(Numeric)
      raise ArgumentError, '"max" argument must be Numeric'                unless max.kind_of?(Numeric)
      raise ArgumentError, '"max" argument greater or equal to "min"'      unless min <= max
      raise ArgumentError, '"exclude" argument must be Boolean'            unless exclude.kind_of?(TrueClass) or exclude.kind_of?(FalseClass)

      @filters << { 'type' => SPH_FILTER_FLOATRANGE, 'attr' => attribute.to_s, 'exclude' => exclude, 'min' => min.to_f, 'max' => max.to_f }
      self
    end
    alias :SetFilterFloatRange :set_filter_float_range

    # Sets anchor point for and geosphere distance (geodistance)
    # calculations, and enable them.
    #
    # +attrlat+ and +attrlong+ must be strings that contain the names
    # of latitude and longitude attributes, respectively. +lat+ and
    # +long+ are floats that specify anchor point latitude and
    # longitude, in radians.
    #
    # Once an anchor point is set, you can use magic <tt>"@geodist"</tt>
    # attribute name in your filters and/or sorting expressions.
    # Sphinx will compute geosphere distance between the given anchor
    # point and a point specified by latitude and lognitude attributes
    # from each full-text match, and attach this value to the resulting
    # match. The latitude and longitude values both in {#set_geo_anchor}
    # and the index attribute data are expected to be in radians.
    # The result will be returned in meters, so geodistance value of
    # 1000.0 means 1 km. 1 mile is approximately 1609.344 meters.
    #
    # @param [String, Symbol] attrlat a name of latitude attribute.
    # @param [String, Symbol] attrlong a name of longitude attribute.
    # @param [Numeric] lat an anchor point latitude, in radians.
    # @param [Numeric] long an anchor point longitude, in radians.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_geo_anchor(:latitude, :longitude, 192.5, 143.5)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setgeoanchor Section 6.4.5, "SetGeoAnchor"
    #
    def set_geo_anchor(attrlat, attrlong, lat, long)
      raise ArgumentError, '"attrlat" argument must be String or Symbol'  unless attrlat.kind_of?(String)  or attrlat.kind_of?(Symbol)
      raise ArgumentError, '"attrlong" argument must be String or Symbol' unless attrlong.kind_of?(String) or attrlong.kind_of?(Symbol)
      raise ArgumentError, '"lat" argument must be Numeric'               unless lat.kind_of?(Numeric)
      raise ArgumentError, '"long" argument must be Numeric'              unless long.kind_of?(Numeric)

      @anchor = { 'attrlat' => attrlat.to_s, 'attrlong' => attrlong.to_s, 'lat' => lat.to_f, 'long' => long.to_f }
      self
    end
    alias :SetGeoAnchor :set_geo_anchor

    #=================================================================
    # GROUP BY settings
    #=================================================================

    # Sets grouping attribute, function, and groups sorting mode; and
    # enables grouping (as described in Section 4.6, "Grouping (clustering) search results").
    #
    # +attribute+ is a string that contains group-by attribute name.
    # +func+ is a constant that chooses a function applied to the
    # attribute value in order to compute group-by key. +groupsort+
    # is a clause that controls how the groups will be sorted. Its
    # syntax is similar to that described in Section 4.5,
    # "SPH_SORT_EXTENDED mode".
    #
    # Grouping feature is very similar in nature to <tt>GROUP BY</tt> clause
    # from SQL. Results produces by this function call are going to
    # be the same as produced by the following pseudo code:
    #
    #   SELECT ... GROUP BY func(attribute) ORDER BY groupsort
    #
    # Note that it's +groupsort+ that affects the order of matches in
    # the final result set. Sorting mode (see {#set_sort_mode}) affect
    # the ordering of matches within group, ie. what match will be
    # selected as the best one from the group. So you can for instance
    # order the groups by matches count and select the most relevant
    # match within each group at the same time.
    #
    # Starting with version 0.9.9-rc2, aggregate functions (<tt>AVG()</tt>,
    # <tt>MIN()</tt>, <tt>MAX()</tt>, <tt>SUM()</tt>) are supported
    # through {#set_select} API call when using <tt>GROUP BY</tt>.
    #
    # You can specify group function and attribute as String
    # ("attr", "day", etc), Symbol (:attr, :day, etc), or
    # Fixnum constant (SPH_GROUPBY_ATTR, SPH_GROUPBY_DAY, etc).
    #
    # @param [String, Symbol] attribute an attribute name to group by.
    # @param [Integer, String, Symbol] func a grouping function.
    # @param [String] groupsort a groups sorting mode.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_group_by(:tag_id, :attr)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#clustering Section 4.6, "Grouping (clustering) search results"
    # @see http://www.sphinxsearch.com/docs/current.html#sort-extended Section 4.5, "SPH_SORT_EXTENDED mode"
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setgroupby Section 6.5.1, "SetGroupBy"
    # @see #set_sort_mode
    # @see #set_select
    # @see #set_group_distinct
    #
    def set_group_by(attribute, func, groupsort = '@group desc')
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
      self
    end
    alias :SetGroupBy :set_group_by

    # Sets attribute name for per-group distinct values count
    # calculations. Only available for grouping queries.
    #
    # +attribute+ is a string that contains the attribute name. For
    # each group, all values of this attribute will be stored (as
    # RAM limits permit), then the amount of distinct values will
    # be calculated and returned to the client. This feature is
    # similar to <tt>COUNT(DISTINCT)</tt> clause in standard SQL;
    # so these Sphinx calls:
    #
    #   sphinx.set_group_by(:category, :attr, '@count desc')
    #   sphinx.set_group_distinct(:vendor)
    #
    # can be expressed using the following SQL clauses:
    #
    #   SELECT id, weight, all-attributes,
    #     COUNT(DISTINCT vendor) AS @distinct,
    #     COUNT(*) AS @count
    #   FROM products
    #   GROUP BY category
    #   ORDER BY @count DESC
    #
    # In the sample pseudo code shown just above, {#set_group_distinct}
    # call corresponds to <tt>COUNT(DISINCT vendor)</tt> clause only.
    # <tt>GROUP BY</tt>, <tt>ORDER BY</tt>, and <tt>COUNT(*)</tt>
    # clauses are all an equivalent of {#set_group_by} settings. Both
    # queries will return one matching row for each category. In
    # addition to indexed attributes, matches will also contain
    # total per-category matches count, and the count of distinct
    # vendor IDs within each category.
    #
    # @param [String, Symbol] attribute an attribute name.
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.set_group_distinct(:category_id)
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-setgroupdistinct Section 6.5.2, "SetGroupDistinct"
    # @see #set_group_by
    #
    def set_group_distinct(attribute)
      raise ArgumentError, '"attribute" argument must be String or Symbol' unless attribute.kind_of?(String)  or attribute.kind_of?(Symbol)

      @groupdistinct = attribute.to_s
      self
    end
    alias :SetGroupDistinct :set_group_distinct

    #=================================================================
    # Querying
    #=================================================================

    # Clears all currently set filters.
    #
    # This call is only normally required when using multi-queries. You might want
    # to set different filters for different queries in the batch. To do that,
    # you should call {#reset_filters} and add new filters using the respective calls.
    #
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.reset_filters
    #
    # @see #set_filter
    # @see #set_filter_range
    # @see #set_filter_float_range
    # @see #set_geo_anchor
    #
    def reset_filters
      @filters = []
      @anchor = []
      self
    end
    alias :ResetFilters :reset_filters

    # Clears all currently group-by settings, and disables group-by.
    #
    # This call is only normally required when using multi-queries. You can
    # change individual group-by settings using {#set_group_by} and {#set_group_distinct}
    # calls, but you can not disable group-by using those calls. {#reset_group_by}
    # fully resets previous group-by settings and disables group-by mode in the
    # current state, so that subsequent {#add_query} calls can perform non-grouping
    # searches.
    #
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.reset_group_by
    #
    # @see #set_group_by
    # @see #set_group_distinct
    #
    def reset_group_by
      @groupby       = ''
      @groupfunc     = SPH_GROUPBY_DAY
      @groupsort     = '@group desc'
      @groupdistinct = ''
      self
    end
    alias :ResetGroupBy :reset_group_by

    # Clear all attribute value overrides (for multi-queries).
    #
    # This call is only normally required when using multi-queries. You might want
    # to set field overrides for different queries in the batch. To do that,
    # you should call {#reset_overrides} and add new overrides using the
    # respective calls.
    #
    # @return [Sphinx::Client] self.
    #
    # @example
    #   sphinx.reset_overrides
    #
    # @see #set_override
    #
    def reset_overrides
      @overrides = []
      self
    end
    alias :ResetOverrides :reset_overrides

    # Connects to searchd server, runs given search query with
    # current settings, obtains and returns the result set.
    #
    # +query+ is a query string. +index+ is an index name (or names)
    # string. Returns false and sets {#last_error} message on general
    # error. Returns search result set on success. Additionally,
    # the contents of +comment+ are sent to the query log, marked in
    # square brackets, just before the search terms, which can be very
    # useful for debugging. Currently, the comment is limited to 128
    # characters.
    #
    # Default value for +index+ is <tt>"*"</tt> that means to query
    # all local indexes. Characters allowed in index names include
    # Latin letters (a-z), numbers (0-9), minus sign (-), and
    # underscore (_); everything else is considered a separator.
    # Therefore, all of the following samples calls are valid and
    # will search the same two indexes:
    #
    #   sphinx.query('test query', 'main delta')
    #   sphinx.query('test query', 'main;delta')
    #   sphinx.query('test query', 'main, delta');
    #
    # Index specification order matters. If document with identical
    # IDs are found in two or more indexes, weight and attribute
    # values from the very last matching index will be used for
    # sorting and returning to client (unless explicitly overridden
    # with {#set_index_weights}). Therefore, in the example above,
    # matches from "delta" index will always win over matches
    # from "main".
    #
    # On success, {#query} returns a result set that contains some
    # of the found matches (as requested by {#set_limits}) and
    # additional general per-query statistics. The result set
    # is an +Hash+ with the following keys and values:
    #
    # <tt>"matches"</tt>::
    #   Array with small +Hash+es containing document weight and
    #   attribute values.
    # <tt>"total"</tt>::
    #   Total amount of matches retrieved on server (ie. to the server
    #   side result set) by this query. You can retrieve up to this
    #   amount of matches from server for this query text with current
    #   query settings.
    # <tt>"total_found"</tt>::
    #   Total amount of matching documents in index (that were found
    #   and procesed on server).
    # <tt>"words"</tt>::
    #   Hash which maps query keywords (case-folded, stemmed, and
    #   otherwise processed) to a small Hash with per-keyword statitics
    #   ("docs", "hits").
    # <tt>"error"</tt>::
    #   Query error message reported by searchd (string, human readable).
    #   Empty if there were no errors.
    # <tt>"warning"</tt>::
    #   Query warning message reported by searchd (string, human readable).
    #   Empty if there were no warnings.
    #
    # Please note: you can use both strings and symbols as <tt>Hash</tt> keys.
    #
    # It should be noted that {#query} carries out the same actions as
    # {#add_query} and {#run_queries} without the intermediate steps; it
    # is analoguous to a single {#add_query} call, followed by a
    # corresponding {#run_queries}, then returning the first array
    # element of matches (from the first, and only, query.)
    #
    # @param [String] query a query string.
    # @param [String] index an index name (or names).
    # @param [String] comment a comment to be sent to the query log.
    # @return [Hash, false] result set described above or +false+ on error.
    # @yield [Client] yields just before query performing. Useful to set
    #   filters or sortings. When block does not accept any parameters, it
    #   will be eval'ed inside {Client} instance itself. In this case you
    #   can omit +set_+ prefix for configuration methods.
    # @yieldparam [Client] sphinx self.
    #
    # @example Regular query with previously set filters
    #   sphinx.query('some search text', '*', 'search page')
    # @example Query with block
    #   sphinx.query('test') do |sphinx|
    #     sphinx.set_match_mode :all
    #     sphinx.set_id_range 10, 100
    #   end
    # @example Query with instant filters configuring
    #   sphinx.query('test') do
    #     match_mode :all
    #     id_range 10, 100
    #   end
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-query Section 6.6.1, "Query"
    # @see #add_query
    # @see #run_queries
    #
    def query(query, index = '*', comment = '', &block)
      @reqs = []

      if block_given?
        if block.arity > 0
          yield self
        else
          begin
            @inside_eval = true
            instance_eval(&block)
          ensure
            @inside_eval = false
          end
        end
      end

      logger.debug { "[sphinx] query('#{query}', '#{index}', '#{comment}'), #{self.inspect}" } if logger

      self.add_query(query, index, comment, false)
      results = self.run_queries

      # probably network error; error message should be already filled
      return false unless results.instance_of?(Array)

      @error = results[0]['error']
      @warning = results[0]['warning']

      return false if results[0]['status'] == SEARCHD_ERROR
      return results[0]
    end
    alias :Query :query

    # Adds additional query with current settings to multi-query batch.
    # +query+ is a query string. +index+ is an index name (or names)
    # string. Additionally if provided, the contents of +comment+ are
    # sent to the query log, marked in square brackets, just before
    # the search terms, which can be very useful for debugging.
    # Currently, this is limited to 128 characters. Returns index
    # to results array returned from {#run_queries}.
    #
    # Batch queries (or multi-queries) enable searchd to perform
    # internal optimizations if possible. They also reduce network
    # connection overheads and search process creation overheads in all
    # cases. They do not result in any additional overheads compared
    # to simple queries. Thus, if you run several different queries
    # from your web page, you should always consider using multi-queries.
    #
    # For instance, running the same full-text query but with different
    # sorting or group-by settings will enable searchd to perform
    # expensive full-text search and ranking operation only once, but
    # compute multiple group-by results from its output.
    #
    # This can be a big saver when you need to display not just plain
    # search results but also some per-category counts, such as the
    # amount of products grouped by vendor. Without multi-query, you
    # would have to run several queries which perform essentially the
    # same search and retrieve the same matches, but create result
    # sets differently. With multi-query, you simply pass all these
    # queries in a single batch and Sphinx optimizes the redundant
    # full-text search internally.
    #
    # {#add_query} internally saves full current settings state along
    # with the query, and you can safely change them afterwards for
    # subsequent {#add_query} calls. Already added queries will not
    # be affected; there's actually no way to change them at all.
    # Here's an example:
    #
    #   sphinx.set_sort_mode(:relevance)
    #   sphinx.add_query("hello world", "documents")
    #
    #   sphinx.set_sort_mode(:attr_desc, :price)
    #   sphinx.add_query("ipod", "products")
    #
    #   sphinx.add_query("harry potter", "books")
    #
    #   results = sphinx.run_queries
    #
    # With the code above, 1st query will search for "hello world"
    # in "documents" index and sort results by relevance, 2nd query
    # will search for "ipod" in "products" index and sort results
    # by price, and 3rd query will search for "harry potter" in
    # "books" index while still sorting by price. Note that 2nd
    # {#set_sort_mode} call does not affect the first query (because
    # it's already added) but affects both other subsequent queries.
    #
    # Additionally, any filters set up before an {#add_query} will
    # fall through to subsequent queries. So, if {#set_filter} is
    # called before the first query, the same filter will be in
    # place for the second (and subsequent) queries batched through
    # {#add_query} unless you call {#reset_filters} first. Alternatively,
    # you can add additional filters as well.
    #
    # This would also be true for grouping options and sorting options;
    # no current sorting, filtering, and grouping settings are affected
    # by this call; so subsequent queries will reuse current query settings.
    #
    # {#add_query} returns an index into an array of results that will
    # be returned from {#run_queries} call. It is simply a sequentially
    # increasing 0-based integer, ie. first call will return 0, second
    # will return 1, and so on. Just a small helper so you won't have
    # to track the indexes manualy if you need then.
    #
    # @param [String] query a query string.
    # @param [String] index an index name (or names).
    # @param [String] comment a comment to be sent to the query log.
    # @param [Boolean] log indicating whether this call should be logged.
    # @return [Integer] an index into an array of results that will
    #   be returned from {#run_queries} call.
    #
    # @example
    #   sphinx.add_query('some search text', '*', 'search page')
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-addquery Section 6.6.2, "AddQuery"
    # @see #query
    # @see #run_queries
    #
    def add_query(query, index = '*', comment = '', log = true)
      logger.debug { "[sphinx] add_query('#{query}', '#{index}', '#{comment}'), #{self.inspect}" } if log and logger
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
      @indexweights.sort_by { |idx, _| idx }.each do |idx, weight|
        request.put_string idx.to_s
        request.put_int weight
      end

      # max query time
      request.put_int @maxquerytime

      # per-field weights
      request.put_int @fieldweights.length
      @fieldweights.sort_by { |idx, _| idx }.each do |field, weight|
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
    alias :AddQuery :add_query

    # Connect to searchd, runs a batch of all queries added using
    # {#add_query}, obtains and returns the result sets. Returns
    # +false+ and sets {#last_error} message on general error
    # (such as network I/O failure). Returns a plain array of
    # result sets on success.
    #
    # Each result set in the returned array is exactly the same as
    # the result set returned from {#query}.
    #
    # Note that the batch query request itself almost always succeds —
    # unless there's a network error, blocking index rotation in
    # progress, or another general failure which prevents the whole
    # request from being processed.
    #
    # However individual queries within the batch might very well
    # fail. In this case their respective result sets will contain
    # non-empty "error" message, but no matches or query statistics.
    # In the extreme case all queries within the batch could fail.
    # There still will be no general error reported, because API
    # was able to succesfully connect to searchd, submit the batch,
    # and receive the results — but every result set will have a
    # specific error message.
    #
    # @return [Array<Hash>] an +Array+ of +Hash+es which are exactly
    #   the same as the result set returned from {#query}.
    #
    # @example
    #   sphinx.add_query('some search text', '*', 'search page')
    #   results = sphinx.run_queries
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-runqueries Section 6.6.3, "RunQueries"
    # @see #add_query
    #
    def run_queries
      logger.debug { "[sphinx] run_queries(#{@reqs.length} queries)" } if logger
      if @reqs.empty?
        @error = 'No queries defined, issue add_query() first'
        return false
      end

      reqs, nreqs = @reqs.join(''), @reqs.length
      @reqs = []
      response = perform_request(:search, reqs, nreqs)

      # parse response
      (1..nreqs).map do
        result = HashWithIndifferentAccess.new('error' => '', 'warning' => '')

        # extract status
        status = result['status'] = response.get_int
        if status != SEARCHD_OK
          message = response.get_string
          if status == SEARCHD_WARNING
            result['warning'] = message
          else
            result['error'] = message
            next result
          end
        end

        # read schema
        nfields = response.get_int
        result['fields'] = (1..nfields).map { response.get_string }

        attrs_names_in_order = []
        nattrs = response.get_int
        attrs = (1..nattrs).inject({}) do |hash, idx|
          name, type = response.get_string, response.get_int
          hash[name] = type
          attrs_names_in_order << name
          hash
        end
        result['attrs'] = attrs

        # read match count
        count, id64 = response.get_ints(2)

        # read matches
        result['matches'] = (1..count).map do
          doc, weight = if id64 == 0
            response.get_ints(2)
          else
            [response.get_int64, response.get_int]
          end

          # This is a single result put in the result['matches'] array
          match = { 'id' => doc, 'weight' => weight }
          match['attrs'] = attrs_names_in_order.inject({}) do |hash, name|
            hash[name] = case attrs[name]
              when SPH_ATTR_BIGINT
                # handle 64-bit ints
                response.get_int64
              when SPH_ATTR_FLOAT
                # handle floats
                response.get_float
              when SPH_ATTR_STRING
                response.get_string
              else
                # handle everything else as unsigned ints
                val = response.get_int
                if (attrs[name] & SPH_ATTR_MULTI) != 0
                  (1..val).map { response.get_int }
                else
                  val
                end
            end
            hash
          end
          match
        end
        result['total'], result['total_found'], msecs = response.get_ints(3)
        result['time'] = '%.3f' % (msecs / 1000.0)

        nwords = response.get_int
        result['words'] = (1..nwords).inject({}) do |hash, idx|
          word = response.get_string
          docs, hits = response.get_ints(2)
          hash[word] = { 'docs' => docs, 'hits' => hits }
          hash
        end

        result
      end
    end
    alias :RunQueries :run_queries

    #=================================================================
    # Additional functionality
    #=================================================================

    # Excerpts (snippets) builder function. Connects to searchd, asks
    # it to generate excerpts (snippets) from given documents, and
    # returns the results.
    #
    # +docs+ is a plain array of strings that carry the documents'
    # contents. +index+ is an index name string. Different settings
    # (such as charset, morphology, wordforms) from given index will
    # be used. +words+ is a string that contains the keywords to
    # highlight. They will be processed with respect to index settings.
    # For instance, if English stemming is enabled in the index,
    # "shoes" will be highlighted even if keyword is "shoe". Starting
    # with version 0.9.9-rc1, keywords can contain wildcards, that
    # work similarly to star-syntax available in queries.
    #
    # @param [Array<String>] docs an array of strings which represent
    #   the documents' contents.
    # @param [String] index an index which settings will be used for
    #   stemming, lexing and case folding.
    # @param [String] words a string which contains the words to highlight.
    # @param [Hash] opts a +Hash+ which contains additional optional
    #   highlighting parameters.
    # @option opts [String] 'before_match' ("<b>") a string to insert before a
    #   keyword match.
    # @option opts [String] 'after_match' ("</b>") a string to insert after a
    #   keyword match.
    # @option opts [String] 'chunk_separator' (" ... ") a string to insert
    #   between snippet chunks (passages).
    # @option opts [Integer] 'limit' (256) maximum snippet size, in symbols
    #   (codepoints).
    # @option opts [Integer] 'around' (5) how many words to pick around
    #   each matching keywords block.
    # @option opts [Boolean] 'exact_phrase' (false) whether to highlight exact
    #   query phrase matches only instead of individual keywords.
    # @option opts [Boolean] 'single_passage' (false) whether to extract single
    #   best passage only.
    # @option opts [Boolean] 'use_boundaries' (false) whether to extract
    #   passages by phrase boundaries setup in tokenizer.
    # @option opts [Boolean] 'weight_order' (false) whether to sort the
    #   extracted passages in order of relevance (decreasing weight),
    #   or in order of appearance in the document (increasing position).
    # @return [Array<String>, false] a plain array of strings with
    #   excerpts (snippets) on success; otherwise, +false+.
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @example
    #   sphinx.build_excerpts(['hello world', 'hello me'], 'idx', 'hello')
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-buildexcerpts Section 6.7.1, "BuildExcerpts"
    #
    def build_excerpts(docs, index, words, opts = {})
      raise ArgumentError, '"docs" argument must be Array'   unless docs.kind_of?(Array)
      raise ArgumentError, '"index" argument must be String' unless index.kind_of?(String) or index.kind_of?(Symbol)
      raise ArgumentError, '"words" argument must be String' unless words.kind_of?(String)
      raise ArgumentError, '"opts" argument must be Hash'    unless opts.kind_of?(Hash)

      docs.each do |doc|
        raise ArgumentError, '"docs" argument must be Array of Strings' unless doc.kind_of?(String)
      end

      # fixup options
      opts = HashWithIndifferentAccess.new(
        'before_match'    => '<b>',
        'after_match'     => '</b>',
        'chunk_separator' => ' ... ',
        'limit'           => 256,
        'around'          => 5,
        'exact_phrase'    => false,
        'single_passage'  => false,
        'use_boundaries'  => false,
        'weight_order'    => false,
        'query_mode'      => false,
        'force_all_words' => false
      ).update(opts)

      # build request

      # v.1.0 req
      flags = 1
      flags |= 2  if opts['exact_phrase']
      flags |= 4  if opts['single_passage']
      flags |= 8  if opts['use_boundaries']
      flags |= 16 if opts['weight_order']
      flags |= 32 if opts['query_mode']
      flags |= 64 if opts['force_all_words']

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
    alias :BuildExcerpts :build_excerpts

    # Extracts keywords from query using tokenizer settings for given
    # index, optionally with per-keyword occurrence statistics.
    # Returns an array of hashes with per-keyword information.
    #
    # +query+ is a query to extract keywords from. +index+ is a name of
    # the index to get tokenizing settings and keyword occurrence
    # statistics from. +hits+ is a boolean flag that indicates whether
    # keyword occurrence statistics are required.
    #
    # The result set consists of +Hash+es with the following keys and values:
    #
    # <tt>'tokenized'</tt>::
    #   Tokenized keyword.
    # <tt>'normalized'</tt>::
    #   Normalized keyword.
    # <tt>'docs'</tt>::
    #   A number of documents where keyword is found (if +hits+ param is +true+).
    # <tt>'hits'</tt>::
    #   A number of keywords occurrences among all documents (if +hits+ param is +true+).
    #
    # @param [String] query a query string.
    # @param [String] index an index to get tokenizing settings and
    #   keyword occurrence statistics from.
    # @param [Boolean] hits indicates whether keyword occurrence
    #   statistics are required.
    # @return [Array<Hash>] an +Array+ of +Hash+es in format specified
    #   above.
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @example
    #   keywords = sphinx.build_keywords("this.is.my query", "test1", false)
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-buildkeywords Section 6.7.3, "BuildKeywords"
    #
    def build_keywords(query, index, hits)
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

        entry = HashWithIndifferentAccess.new('tokenized' => tokenized, 'normalized' => normalized)
        entry['docs'], entry['hits'] = response.get_ints(2) if hits

        entry
      end
    end
    alias :BuildKeywords :build_keywords

    # Instantly updates given attribute values in given documents.
    # Returns number of actually updated documents (0 or more) on
    # success, or -1 on failure.
    #
    # +index+ is a name of the index (or indexes) to be updated.
    # +attrs+ is a plain array with string attribute names, listing
    # attributes that are updated. +values+ is a Hash where key is
    # document ID, and value is a plain array of new attribute values.
    #
    # +index+ can be either a single index name or a list, like in
    # {#query}. Unlike {#query}, wildcard is not allowed and all the
    # indexes to update must be specified explicitly. The list of
    # indexes can include distributed index names. Updates on
    # distributed indexes will be pushed to all agents.
    #
    # The updates only work with docinfo=extern storage strategy.
    # They are very fast because they're working fully in RAM, but
    # they can also be made persistent: updates are saved on disk
    # on clean searchd shutdown initiated by SIGTERM signal. With
    # additional restrictions, updates are also possible on MVA
    # attributes; refer to mva_updates_pool directive for details.
    #
    # The first sample statement will update document 1 in index
    # "test1", setting "group_id" to 456. The second one will update
    # documents 1001, 1002 and 1003 in index "products". For document
    # 1001, the new price will be set to 123 and the new amount in
    # stock to 5; for document 1002, the new price will be 37 and the
    # new amount will be 11; etc. The third one updates document 1
    # in index "test2", setting MVA attribute "group_id" to [456, 789].
    #
    # @example
    #   sphinx.update_attributes("test1", ["group_id"], { 1 => [456] });
    #   sphinx.update_attributes("products", ["price", "amount_in_stock"],
    #     { 1001 => [123, 5], 1002 => [37, 11], 1003 => [25, 129] });
    #   sphinx.update_attributes('test2', ['group_id'], { 1 => [[456, 789]] }, true)
    #
    # @param [String] index a name of the index to be updated.
    # @param [Array<String>] attrs an array of attribute name strings.
    # @param [Hash] values is a hash where key is document id, and
    #   value is an array of new attribute values.
    # @param [Boolean] mva indicating whether to update MVA.
    # @return [Integer] number of actually updated documents (0 or more) on success,
    #   -1 on failure.
    #
    # @raise [ArgumentError] Occurred when parameters are invalid.
    #
    # @see http://www.sphinxsearch.com/docs/current.html#api-func-updateatttributes Section 6.7.2, "UpdateAttributes"
    #
    def update_attributes(index, attrs, values, mva = false)
      # verify everything
      raise ArgumentError, '"index" argument must be String' unless index.kind_of?(String) or index.kind_of?(Symbol)
      raise ArgumentError, '"mva" argument must be Boolean'  unless mva.kind_of?(TrueClass) or mva.kind_of?(FalseClass)

      raise ArgumentError, '"attrs" argument must be Array' unless attrs.kind_of?(Array)
      attrs.each do |attr|
        raise ArgumentError, '"attrs" argument must be Array of Strings' unless attr.kind_of?(String) or attr.kind_of?(Symbol)
      end

      raise ArgumentError, '"values" argument must be Hash' unless values.kind_of?(Hash)
      values.each do |id, entry|
        raise ArgumentError, '"values" argument must be Hash map of Integer to Array' unless id.kind_of?(Integer)
        raise ArgumentError, '"values" argument must be Hash map of Integer to Array' unless entry.kind_of?(Array)
        raise ArgumentError, "\"values\" argument Hash values Array must have #{attrs.length} elements" unless entry.length == attrs.length
        entry.each do |v|
          if mva
            raise ArgumentError, '"values" argument must be Hash map of Integer to Array of Arrays' unless v.kind_of?(Array)
            v.each do |vv|
              raise ArgumentError, '"values" argument must be Hash map of Integer to Array of Arrays of Integers' unless vv.kind_of?(Integer)
            end
          else
            raise ArgumentError, '"values" argument must be Hash map of Integer to Array of Integers' unless v.kind_of?(Integer)
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
    alias :UpdateAttributes :update_attributes

    # Escapes characters that are treated as special operators by the
    # query language parser.
    #
    # This function might seem redundant because it's trivial to
    # implement in any calling application. However, as the set of
    # special characters might change over time, it makes sense to
    # have an API call that is guaranteed to escape all such
    # characters at all times.
    #
    # @param [String] string is a string to escape.
    # @return [String] an escaped string.
    #
    # @example:
    #   escaped = sphinx.escape_string "escaping-sample@query/string"
    #
    def escape_string(string)
      string.to_s.gsub(/([\\()|\-!@~"&\/\^\$=])/, '\\\\\\1')
    end
    alias :EscapeString :escape_string

    # Queries searchd status, and returns an array of status variable name
    # and value pairs.
    #
    # @return [Array<Array>, Array<Hash>] a table containing searchd status information.
    #   If there are more than one server configured ({#set_servers}), an
    #   +Array+ of +Hash+es will be returned, one for each server. Hash will
    #   contain <tt>:server</tt> element with string name of server (<tt>host:port</tt>)
    #   and <tt>:status</tt> table just like one for a single server. In case of
    #   any error, it will be stored in the <tt>:error</tt> key.
    #
    # @example Single server
    #   status = sphinx.status
    #   puts status.map { |key, value| "#{key.rjust(20)}: #{value}" }
    #
    # @example Multiple servers
    #   sphinx.set_servers([
    #     { :host => 'localhost' },
    #     { :host => 'browse02.local' }
    #   ])
    #   sphinx.status.each do |report|
    #     puts "=== #{report[:server]}"
    #     if report[:error]
    #       puts "Error: #{report[:error]}"
    #     else
    #       puts report[:status].map { |key, value| "#{key.rjust(20)}: #{value}" }
    #     end
    #   end
    #
    def status
      request = Request.new
      request.put_int(1)

      # parse response
      results = @servers.map do |server|
        begin
          response = perform_request(:status, request, nil, server)
          rows, cols = response.get_ints(2)
          status = (0...rows).map do
            (0...cols).map { response.get_string }
          end
          HashWithIndifferentAccess.new(:server => server.to_s, :status => status)
        rescue SphinxError
          # Re-raise error when a single server configured
          raise if @servers.size == 1
          HashWithIndifferentAccess.new(:server => server.to_s, :error => self.last_error)
        end
      end

      @servers.size > 1 ? results : results.first[:status]
    end
    alias :Status :status

    # Force attribute flush, and block until it completes.
    #
    # @return [Integer] current internal flush tag on success, -1 on failure.
    #
    # @example
    #   sphinx.flush_attrs
    #
    def flush_attributes
      request = Request.new
      response = perform_request(:flushattrs, request)

      # parse response
      begin
        response.get_int
      rescue EOFError
        @error = 'unexpected response length'
        -1
      end
    end
    alias :FlushAttributes :flush_attributes
    alias :FlushAttrs :flush_attributes
    alias :flush_attrs :flush_attributes

    #=================================================================
    # Persistent connections
    #=================================================================

    # Opens persistent connection to the server.
    #
    # This method could be used only when a single searchd server
    # configured.
    #
    # @return [Boolean] +true+ when persistent connection has been
    #   established; otherwise, +false+.
    #
    # @example
    #   begin
    #     sphinx.open
    #     # perform several requests
    #   ensure
    #     sphinx.close
    #   end
    #
    # @see #close
    #
    def open
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
    alias :Open :open

    # Closes previously opened persistent connection.
    #
    # This method could be used only when a single searchd server
    # configured.
    #
    # @return [Boolean] +true+ when persistent connection has been
    #   closed; otherwise, +false+.
    #
    # @example
    #   begin
    #     sphinx.open
    #     # perform several requests
    #   ensure
    #     sphinx.close
    #   end
    #
    # @see #open
    #
    def close
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
    alias :Close :close

    protected

      # Connect, send query, get response.
      #
      # Use this method to communicate with Sphinx server. It ensures connection
      # will be instantiated properly, all headers will be generated properly, etc.
      #
      # @param [Symbol, String] command searchd command to perform (<tt>:search</tt>, <tt>:excerpt</tt>,
      #   <tt>:update</tt>, <tt>:keywords</tt>, <tt>:persist</tt>, <tt>:status</tt>,
      #   <tt>:query</tt>, <tt>:flushattrs</tt>. See <tt>SEARCHD_COMMAND_*</tt> for details).
      # @param [Sphinx::Request] request contains request body.
      # @param [Integer] additional additional integer data to be placed between header and body.
      # @param [Sphinx::Server] server where perform request on. This is special
      #   parameter for internal usage. If specified, request will be performed
      #   on specified server, and it will try to establish connection to this
      #   server only once.
      #
      # @yield if block given, response will not be parsed, plain socket
      #   will be yielded instead. This is special mode used for
      #   persistent connections, do not use for other tasks.
      # @yieldparam [Sphinx::Server] server a server where request was performed on.
      # @yieldparam [Sphinx::BufferedIO] socket a socket used to perform the request.
      # @return [Sphinx::Response] contains response body.
      #
      # @see #parse_response
      #
      def perform_request(command, request, additional = nil, server = nil)
        if server
          attempts = 1
        else
          server = case request
            when String
              Zlib.crc32(request)
            when Request
              request.crc32
            else
              raise ArgumentError, "request argument must be String or Sphinx::Request"
          end
          attempts = nil
        end

        with_server(server, attempts) do |server|
          logger.info { "[sphinx] #{command} on server #{server}" } if logger

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
      # @param [Sphinx::BufferedIO] socket an input stream object.
      # @param [Integer] client_version a command version which client supports.
      # @return [Sphinx::Response] could be used for context-based
      #   parsing of reply from the server.
      #
      # @raise [SystemCallError, SocketError] should be handled by caller (see {#with_socket}).
      # @raise [SphinxResponseError] incomplete reply from searchd.
      # @raise [SphinxInternalError] searchd internal error.
      # @raise [SphinxTemporaryError] searchd temporary error.
      # @raise [SphinxUnknownError] searchd unknown error.
      #
      # @see #with_socket
      # @private
      #
      def parse_response(socket, client_version)
        response = ''
        status = ver = len = 0

        # Read server reply from server. All exceptions are handled by {#with_socket}.
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
      # (see {#set_connect_timeout} method details). If all servers are down,
      # it will set error attribute (could be retrieved with {#last_error}
      # method) with the last exception message, and {#connect_error?}
      # method will return true. Also, {SphinxConnectError} exception
      # will be raised.
      #
      # @overload with_server(server_index)
      #   Get the server based on some seed value (usually CRC32 of
      #   request. In this case initial server will be choosed using
      #   this seed value, in case of connetion failure next server
      #   in servers list will be used).
      #   @param [Integer] server_index server index, must be any
      #     integer value (not necessarily less than number of servers.)
      #   @param [Integer] attempts how many retries to perform. Use
      #     +nil+ to perform retries configured with {#set_connect_timeout}.
      # @overload with_server(server)
      #   Get the server specified as a parameter. If specified, request
      #   will be performed on specified server, and it will try to
      #   establish connection to this server only once.
      #   @param [Server] server server to perform request on.
      #   @param [Integer] attempts how many retries to perform. Use
      #     +nil+ to perform retries configured with {#set_connect_timeout}.
      #
      # @yield a block which performs request on a given server.
      # @yieldparam [Sphinx::Server] server contains information
      #   about the server to perform request on.
      # @raise [SphinxConnectError] on any connection error.
      #
      def with_server(server = nil, attempts = nil)
        case server
          when Server
            idx = @servers.index(server) || 0
            s = server
          when Integer
            idx = server % @servers.size
            s = @servers[idx]
          when NilClass
            idx = 0
            s = @servers[idx]
          else
            raise ArgumentError, 'server argument must be Integer or Sphinx::Server'
        end
        attempts ||= @retries
        begin
          yield s
        rescue SphinxConnectError => e
          logger.warn { "[sphinx] server failed: #{e.class.name}: #{e.message}" } if logger
          # Connection error! Do we need to try it again?
          attempts -= 1
          if attempts > 0
            logger.info { "[sphinx] connection to server #{s.inspect} DIED! Retrying operation..." } if logger
            # Get the next server
            idx = (idx + 1) % @servers.size
            s = @servers[idx]
            retry
          end

          # Re-raise original exception
          @error = e.message
          @connerror = true
          raise
        end
      end

      # This is internal method which retrieves socket for a given server,
      # initiates Sphinx session, and yields this socket to a block passed.
      #
      # In case of any problems with session initiation, {SphinxConnectError}
      # will be raised, because this is part of connection establishing. See
      # {#with_server} method details to get more infromation about how this
      # exception is handled.
      #
      # Socket retrieving routine is wrapped in a block with it's own
      # timeout value (see {#set_connect_timeout}). This is done in
      # {Server#get_socket} method, so check it for details.
      #
      # Request execution is wrapped with block with another timeout
      # (see {#set_request_timeout}). This ensures no Sphinx request will
      # take unreasonable time.
      #
      # In case of any Sphinx error (incomplete reply, internal or temporary
      # error), connection to the server will be re-established, and request
      # will be retried (see {#set_request_timeout}). Of course, if connection
      # could not be established, next server will be selected (see explanation
      # above).
      #
      # @param [Sphinx::Server] server contains information
      #   about the server to perform request on.
      # @yield a block which will actually perform the request.
      # @yieldparam [Sphinx::BufferedIO] socket a socket used to
      #   perform the request.
      #
      # @raise [SphinxResponseError, SphinxInternalError, SphinxTemporaryError, SphinxUnknownError]
      #   on any response error.
      # @raise [SphinxConnectError] on any connection error.
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
          logger.warn { "[sphinx] socket failure: #{e.message}" } if logger
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
          logger.warn { "[sphinx] generic failure: #{e.class.name}: #{e.message}" } if logger

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

      # Enables ability to skip +set_+ prefix for methods inside {#query} block.
      #
      # @example
      #   sphinx.query('test') do
      #     match_mode :all
      #     id_range 10, 100
      #   end
      #
      def method_missing(method_id, *arguments, &block)
        if @inside_eval and self.respond_to?("set_#{method_id}")
          self.send("set_#{method_id}", *arguments)
        else
          super
        end
      end
  end
end
