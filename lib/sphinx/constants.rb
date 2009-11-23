module Sphinx
  # Contains all constants need by Sphinx API.
  #
  module Constants
    #=================================================================
    # Known searchd commands
    #=================================================================

    # search command
    # @private
    SEARCHD_COMMAND_SEARCH     = 0
    # excerpt command
    # @private
    SEARCHD_COMMAND_EXCERPT    = 1
    # update command
    # @private
    SEARCHD_COMMAND_UPDATE     = 2
    # keywords command
    # @private
    SEARCHD_COMMAND_KEYWORDS   = 3
    # persist command
    # @private
    SEARCHD_COMMAND_PERSIST    = 4
    # status command
    # @private
    SEARCHD_COMMAND_STATUS     = 5
    # query command
    # @private
    SEARCHD_COMMAND_QUERY      = 6
    # flushattrs command
    # @private
    SEARCHD_COMMAND_FLUSHATTRS = 7

    #=================================================================
    # Current client-side command implementation versions
    #=================================================================

    # search command version
    # @private
    VER_COMMAND_SEARCH     = 0x117
    # excerpt command version
    # @private
    VER_COMMAND_EXCERPT    = 0x100
    # update command version
    # @private
    VER_COMMAND_UPDATE     = 0x102
    # keywords command version
    # @private
    VER_COMMAND_KEYWORDS   = 0x100
    # persist command version
    # @private
    VER_COMMAND_PERSIST    = 0x000
    # status command version
    # @private
    VER_COMMAND_STATUS     = 0x100
    # query command version
    # @private
    VER_COMMAND_QUERY      = 0x100
    # flushattrs command version
    # @private
    VER_COMMAND_FLUSHATTRS = 0x100

    #=================================================================
    # Known searchd status codes
    #=================================================================

    # general success, command-specific reply follows
    # @private
    SEARCHD_OK      = 0
    # general failure, command-specific reply may follow
    # @private
    SEARCHD_ERROR   = 1
    # temporaty failure, client should retry later
    # @private
    SEARCHD_RETRY   = 2
    # general success, warning message and command-specific reply follow
    # @private
    SEARCHD_WARNING = 3

    #=================================================================
    # Known match modes
    #=================================================================

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

    #=================================================================
    # Known ranking modes (ext2 only)
    #=================================================================

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

    #=================================================================
    # Known sort modes
    #=================================================================

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

    #=================================================================
    # Known filter types
    #=================================================================

    # filter by integer values set
    SPH_FILTER_VALUES      = 0
    # filter by integer range
    SPH_FILTER_RANGE       = 1
    # filter by float range
    SPH_FILTER_FLOATRANGE  = 2

    #=================================================================
    # Known attribute types
    #=================================================================

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

    #=================================================================
    # Known grouping functions
    #=================================================================

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
  end

  include Constants
end