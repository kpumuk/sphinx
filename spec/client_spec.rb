require File.dirname(__FILE__) + '/spec_helper'

describe Sphinx::Client, 'disconnected' do
  context 'in Connect method' do
    before :each do
      @sphinx = Sphinx::Client.new
      @sock = mock('TCPSocket')
    end

    it 'should establish TCP connection to the server and initialize session' do
      TCPSocket.should_receive(:new).with('localhost', 3312).and_return(@sock)
      @sock.should_receive(:recv).with(4).and_return([1].pack('N'))
      @sock.should_receive(:send).with([1].pack('N'), 0)
      @sphinx.send(:Connect).should be(@sock)
    end

    it 'should raise exception when searchd protocol is not 1+' do
      TCPSocket.should_receive(:new).with('localhost', 3312).and_return(@sock)
      @sock.should_receive(:send).with([1].pack('N'), 0)
      @sock.should_receive(:recv).with(4).and_return([0].pack('N'))
      @sock.should_receive(:close)
      lambda { @sphinx.send(:Connect) }.should raise_error(Sphinx::SphinxConnectError)
      @sphinx.GetLastError.should == 'expected searchd protocol version 1+, got version \'0\''
    end

    it 'should raise exception on connection error' do
      TCPSocket.should_receive(:new).with('localhost', 3312).and_raise(Errno::EBADF)
      lambda { @sphinx.send(:Connect) }.should raise_error(Sphinx::SphinxConnectError)
      @sphinx.GetLastError.should == 'connection to localhost:3312 failed (errno=9, msg=Bad file descriptor)'
      @sphinx.IsConnectError.should be_true
    end

    it 'should use custom host and port' do
      @sphinx.SetServer('anotherhost', 55555)
      TCPSocket.should_receive(:new).with('anotherhost', 55555).and_raise(Errno::EBADF)
      lambda { @sphinx.send(:Connect) }.should raise_error(Sphinx::SphinxConnectError)
      @sphinx.IsConnectError.should be_true
    end
    
    it 'should handle connection timeouts' do
      TCPSocket.should_receive(:new).with('localhost', 3312).and_return { sleep(5) }
      @sphinx.SetConnectTimeout(1)
      lambda { @sphinx.send(:Connect) }.should raise_error(Sphinx::SphinxConnectError)
      @sphinx.GetLastError.should == 'connection to localhost:3312 failed (msg=time\'s up!)'
      @sphinx.IsConnectError.should be_true
    end
  end
  
  context 'in GetResponse method' do
    before :each do
      @sphinx = Sphinx::Client.new
      @sock = mock('TCPSocket')
      @sock.should_receive(:close)
    end

    it 'should receive response' do
      @sock.should_receive(:recv).with(8).and_return([Sphinx::Client::SEARCHD_OK, 1, 4].pack('n2N'))
      @sock.should_receive(:recv).with(4).and_return([0].pack('N'))
      @sphinx.send(:GetResponse, @sock, 1)
    end

    it 'should raise exception on zero-sized response' do
      @sock.should_receive(:recv).with(8).and_return([Sphinx::Client::SEARCHD_OK, 1, 0].pack('n2N'))
      lambda { @sphinx.send(:GetResponse, @sock, 1) }.should raise_error(Sphinx::SphinxResponseError)
    end

    it 'should raise exception when response is incomplete' do
      @sock.should_receive(:recv).with(8).and_return([Sphinx::Client::SEARCHD_OK, 1, 4].pack('n2N'))
      @sock.should_receive(:recv).with(4).and_raise(EOFError)
      lambda { @sphinx.send(:GetResponse, @sock, 1) }.should raise_error(Sphinx::SphinxResponseError)
    end

    it 'should set warning message when SEARCHD_WARNING received' do
      @sock.should_receive(:recv).with(8).and_return([Sphinx::Client::SEARCHD_WARNING, 1, 14].pack('n2N'))
      @sock.should_receive(:recv).with(14).and_return([5].pack('N') + 'helloworld')
      @sphinx.send(:GetResponse, @sock, 1).should == 'world'
      @sphinx.GetLastWarning.should == 'hello'
    end

    it 'should raise exception when SEARCHD_ERROR received' do
      @sock.should_receive(:recv).with(8).and_return([Sphinx::Client::SEARCHD_ERROR, 1, 9].pack('n2N'))
      @sock.should_receive(:recv).with(9).and_return([1].pack('N') + 'hello')
      lambda { @sphinx.send(:GetResponse, @sock, 1) }.should raise_error(Sphinx::SphinxInternalError)
      @sphinx.GetLastError.should == 'searchd error: hello'
    end

    it 'should raise exception when SEARCHD_RETRY received' do
      @sock.should_receive(:recv).with(8).and_return([Sphinx::Client::SEARCHD_RETRY, 1, 9].pack('n2N'))
      @sock.should_receive(:recv).with(9).and_return([1].pack('N') + 'hello')
      lambda { @sphinx.send(:GetResponse, @sock, 1) }.should raise_error(Sphinx::SphinxTemporaryError)
      @sphinx.GetLastError.should == 'temporary searchd error: hello'
    end

    it 'should raise exception when unknown status received' do
      @sock.should_receive(:recv).with(8).and_return([65535, 1, 9].pack('n2N'))
      @sock.should_receive(:recv).with(9).and_return([1].pack('N') + 'hello')
      lambda { @sphinx.send(:GetResponse, @sock, 1) }.should raise_error(Sphinx::SphinxUnknownError)
      @sphinx.GetLastError.should == 'unknown status code: \'65535\''
    end

    it 'should set warning when server is older than client' do
      @sock.should_receive(:recv).with(8).and_return([Sphinx::Client::SEARCHD_OK, 1, 9].pack('n2N'))
      @sock.should_receive(:recv).with(9).and_return([1].pack('N') + 'hello')
      @sphinx.send(:GetResponse, @sock, 5)
      @sphinx.GetLastWarning.should == 'searchd command v.0.1 older than client\'s v.0.5, some options might not work'
    end
  end

  context 'in Query method' do
    before :each do
      @sphinx = sphinx_create_client
    end

    it 'should generate valid request with default parameters' do
      expected = sphinx_fixture('default_search')
      @sock.should_receive(:send).with(expected, 0)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with default parameters and index' do
      expected = sphinx_fixture('default_search_index')
      @sock.should_receive(:send).with(expected, 0)
      sphinx_safe_call { @sphinx.Query('query', 'index') }
    end

    it 'should generate valid request with limits' do
      expected = sphinx_fixture('limits')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetLimits(10, 20)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with limits and max number to retrieve' do
      expected = sphinx_fixture('limits_max')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetLimits(10, 20, 30)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with limits and cutoff to retrieve' do
      expected = sphinx_fixture('limits_cutoff')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetLimits(10, 20, 30, 40)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with max query time specified' do
      expected = sphinx_fixture('max_query_time')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetMaxQueryTime(1000)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    describe 'with match' do
      [ :all, :any, :phrase, :boolean, :extended, :fullscan, :extended2 ].each do |match|
        it "should generate valid request for SPH_MATCH_#{match.to_s.upcase}" do
          expected = sphinx_fixture("match_#{match}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetMatchMode(Sphinx::Client::const_get("SPH_MATCH_#{match.to_s.upcase}"))
          sphinx_safe_call { @sphinx.Query('query') }
        end

        it "should generate valid request for \"#{match}\"" do
          expected = sphinx_fixture("match_#{match}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetMatchMode(match.to_s)
          sphinx_safe_call { @sphinx.Query('query') }
        end

        it "should generate valid request for :#{match}" do
          expected = sphinx_fixture("match_#{match}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetMatchMode(match)
          sphinx_safe_call { @sphinx.Query('query') }
        end
      end
    end

    describe 'with rank' do
      [ :proximity_bm25, :bm25, :none, :wordcount, :proximity, :matchany, :fieldmask, :sph04 ].each do |rank|
        it "should generate valid request for SPH_RANK_#{rank.to_s.upcase}" do
          expected = sphinx_fixture("ranking_#{rank}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetRankingMode(Sphinx::Client.const_get("SPH_RANK_#{rank.to_s.upcase}"))
          sphinx_safe_call { @sphinx.Query('query') }
        end

        it "should generate valid request for \"#{rank}\"" do
          expected = sphinx_fixture("ranking_#{rank}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetRankingMode(rank.to_s)
          sphinx_safe_call { @sphinx.Query('query') }
        end

        it "should generate valid request for :#{rank}" do
          expected = sphinx_fixture("ranking_#{rank}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetRankingMode(rank)
          sphinx_safe_call { @sphinx.Query('query') }
        end
      end
    end

    describe 'with sorting' do
      [ :attr_desc, :relevance, :attr_asc, :time_segments, :extended, :expr ].each do |mode|
        it "should generate valid request for SPH_SORT_#{mode.to_s.upcase}" do
          expected = sphinx_fixture("sort_#{mode}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetSortMode(Sphinx::Client.const_get("SPH_SORT_#{mode.to_s.upcase}"), mode == :relevance ? '' : 'sortby')
          sphinx_safe_call { @sphinx.Query('query') }
        end

        it "should generate valid request for \"#{mode}\"" do
          expected = sphinx_fixture("sort_#{mode}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetSortMode(mode.to_s, mode == :relevance ? '' : 'sortby')
          sphinx_safe_call { @sphinx.Query('query') }
        end

        it "should generate valid request for :#{mode}" do
          expected = sphinx_fixture("sort_#{mode}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetSortMode(mode, mode == :relevance ? '' : 'sortby')
          sphinx_safe_call { @sphinx.Query('query') }
        end
      end
    end

    it 'should generate valid request with weights' do
      expected = sphinx_fixture('weights')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetWeights([10, 20, 30, 40])
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with field weights' do
      expected = sphinx_fixture('field_weights')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetFieldWeights({'field1' => 10, 'field2' => 20})
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with index weights' do
      expected = sphinx_fixture('index_weights')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetIndexWeights({'index1' => 10, 'index2' => 20})
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with ID range' do
      expected = sphinx_fixture('id_range')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetIDRange(10, 20)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with ID range and 64-bit ints' do
      expected = sphinx_fixture('id_range64')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetIDRange(8589934591, 17179869183)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with values filter' do
      expected = sphinx_fixture('filter')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetFilter('attr', [10, 20, 30])
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with two values filters' do
      expected = sphinx_fixture('filters')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetFilter('attr2', [40, 50])
      @sphinx.SetFilter('attr1', [10, 20, 30])
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with values filter excluded' do
      expected = sphinx_fixture('filter_exclude')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetFilter('attr', [10, 20, 30], true)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with values filter range' do
      expected = sphinx_fixture('filter_range')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetFilterRange('attr', 10, 20)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with two filter ranges' do
      expected = sphinx_fixture('filter_ranges')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetFilterRange('attr2', 30, 40)
      @sphinx.SetFilterRange('attr1', 10, 20)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with filter range excluded' do
      expected = sphinx_fixture('filter_range_exclude')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetFilterRange('attr', 10, 20, true)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with signed int64-based filter range' do
      expected = sphinx_fixture('filter_range_int64')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetFilterRange('attr1', -10, 20)
      @sphinx.SetFilterRange('attr2', -1099511627770, 1099511627780)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with float filter range' do
      expected = sphinx_fixture('filter_float_range')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetFilterFloatRange('attr', 10.5, 20.3)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with float filter excluded' do
      expected = sphinx_fixture('filter_float_range_exclude')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetFilterFloatRange('attr', 10.5, 20.3, true)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with different filters' do
      expected = sphinx_fixture('filters_different')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetFilterRange('attr1', 10, 20, true)
      @sphinx.SetFilter('attr3', [30, 40, 50])
      @sphinx.SetFilterRange('attr1', 60, 70)
      @sphinx.SetFilter('attr2', [80, 90, 100], true)
      @sphinx.SetFilterFloatRange('attr1', 60.8, 70.5)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with geographical anchor point' do
      expected = sphinx_fixture('geo_anchor')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetGeoAnchor('attrlat', 'attrlong', 20.3, 40.7)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    describe 'with group by' do
      [ :day, :week, :month, :year, :attr, :attrpair ].each do |groupby|
        it "should generate valid request for SPH_GROUPBY_#{groupby.to_s.upcase}" do
          expected = sphinx_fixture("group_by_#{groupby}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetGroupBy('attr', Sphinx::Client::const_get("SPH_GROUPBY_#{groupby.to_s.upcase}"))
          sphinx_safe_call { @sphinx.Query('query') }
        end

        it "should generate valid request for \"#{groupby}\"" do
          expected = sphinx_fixture("group_by_#{groupby}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetGroupBy('attr', groupby.to_s)
          sphinx_safe_call { @sphinx.Query('query') }
        end

        it "should generate valid request for :#{groupby}" do
          expected = sphinx_fixture("group_by_#{groupby}")
          @sock.should_receive(:send).with(expected, 0)
          @sphinx.SetGroupBy('attr', groupby)
          sphinx_safe_call { @sphinx.Query('query') }
        end
      end

      it 'should generate valid request for SPH_GROUPBY_DAY with sort' do
        expected = sphinx_fixture('group_by_day_sort')
        @sock.should_receive(:send).with(expected, 0)
        @sphinx.SetGroupBy('attr', Sphinx::Client::SPH_GROUPBY_DAY, 'somesort')
        sphinx_safe_call { @sphinx.Query('query') }
      end

      it 'should generate valid request with count-distinct attribute' do
        expected = sphinx_fixture('group_distinct')
        @sock.should_receive(:send).with(expected, 0)
        @sphinx.SetGroupBy('attr', Sphinx::Client::SPH_GROUPBY_DAY)
        @sphinx.SetGroupDistinct('attr')
        sphinx_safe_call { @sphinx.Query('query') }
      end
    end

    it 'should generate valid request with retries count specified' do
      expected = sphinx_fixture('retries')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetRetries(10)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request with retries count and delay specified' do
      expected = sphinx_fixture('retries_delay')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetRetries(10, 20)
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request for SetOverride' do
      expected = sphinx_fixture('set_override')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetOverride('attr1', Sphinx::Client::SPH_ATTR_INTEGER, { 10 => 20 })
      @sphinx.SetOverride('attr2', Sphinx::Client::SPH_ATTR_FLOAT, { 11 => 30.3 })
      @sphinx.SetOverride('attr3', Sphinx::Client::SPH_ATTR_BIGINT, { 12 => 1099511627780 })
      sphinx_safe_call { @sphinx.Query('query') }
    end

    it 'should generate valid request for SetSelect' do
      expected = sphinx_fixture('select')
      @sock.should_receive(:send).with(expected, 0)
      @sphinx.SetSelect('attr1, attr2')
      sphinx_safe_call { @sphinx.Query('query') }
    end
  end

  context 'in RunQueries method' do
    before(:each) do
      @sphinx = sphinx_create_client
    end

    it 'should generate valid request for multiple queries' do
      expected = sphinx_fixture('miltiple_queries')
      @sock.should_receive(:send).with(expected, 0)

      @sphinx.SetRetries(10, 20)
      @sphinx.AddQuery('test1')
      @sphinx.SetGroupBy('attr', Sphinx::Client::SPH_GROUPBY_DAY)
      @sphinx.AddQuery('test2')

      sphinx_safe_call { @sphinx.RunQueries }
    end
  end

  context 'in BuildExcerpts method' do
    before :each do
      @sphinx = sphinx_create_client
    end

    it 'should generate valid request with default parameters' do
      expected = sphinx_fixture('excerpt_default')
      @sock.should_receive(:send).with(expected, 0)
      sphinx_safe_call { @sphinx.BuildExcerpts(['10', '20'], 'index', 'word1 word2') }
    end

    it 'should generate valid request with custom parameters' do
      expected = sphinx_fixture('excerpt_custom')
      @sock.should_receive(:send).with(expected, 0)
      sphinx_safe_call do
        @sphinx.BuildExcerpts(['10', '20'], 'index', 'word1 word2', { 'before_match'    => 'before',
                                                                      'after_match'     => 'after',
                                                                      'chunk_separator' => 'separator',
                                                                      'limit'           => 10 })
      end
    end

    it 'should generate valid request with custom parameters as symbols' do
      expected = sphinx_fixture('excerpt_custom')
      @sock.should_receive(:send).with(expected, 0)
      sphinx_safe_call do
        @sphinx.BuildExcerpts(['10', '20'], 'index', 'word1 word2', { :before_match    => 'before',
                                                                      :after_match     => 'after',
                                                                      :chunk_separator => 'separator',
                                                                      :limit           => 10 })
      end
    end

    it 'should generate valid request with flags' do
      expected = sphinx_fixture('excerpt_flags')
      @sock.should_receive(:send).with(expected, 0)
      sphinx_safe_call do
        @sphinx.BuildExcerpts(['10', '20'], 'index', 'word1 word2', { 'exact_phrase'   => true,
                                                                      'single_passage' => true,
                                                                      'use_boundaries' => true,
                                                                      'weight_order'   => true,
                                                                      'query_mode'     => true })
      end
    end

    it 'should generate valid request with flags as symbols' do
      expected = sphinx_fixture('excerpt_flags')
      @sock.should_receive(:send).with(expected, 0)
      sphinx_safe_call do
        @sphinx.BuildExcerpts(['10', '20'], 'index', 'word1 word2', { :exact_phrase   => true,
                                                                      :single_passage => true,
                                                                      :use_boundaries => true,
                                                                      :weight_order   => true,
                                                                      :query_mode     => true })
      end
    end
  end

  context 'in BuildKeywords method' do
    before :each do
      @sphinx = sphinx_create_client
    end

    it 'should generate valid request' do
      expected = sphinx_fixture('keywords')
      @sock.should_receive(:send).with(expected, 0)
      sphinx_safe_call { @sphinx.BuildKeywords('test', 'index', true) }
    end
  end

  context 'in UpdateAttributes method' do
    before :each do
      @sphinx = sphinx_create_client
    end

    it 'should generate valid request' do
      expected = sphinx_fixture('update_attributes')
      @sock.should_receive(:send).with(expected, 0)
      sphinx_safe_call { @sphinx.UpdateAttributes('index', ['group'], { 123 => [456] }) }
    end

    it 'should generate valid request for MVA' do
      expected = sphinx_fixture('update_attributes_mva')
      @sock.should_receive(:send).with(expected, 0)
      sphinx_safe_call { @sphinx.UpdateAttributes('index', ['group', 'category'], { 123 => [ [456, 789], [1, 2, 3] ] }, true) }
    end
  end
end
