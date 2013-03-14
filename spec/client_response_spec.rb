require File.dirname(__FILE__) + '/spec_helper'

# To execute these tests you need to execute sphinx_test.sql and configure sphinx using sphinx.conf
# (both files are placed under sphinx directory)
describe Sphinx::Client, 'connected' do
  before :each do
    @sphinx = Sphinx::Client.new
  end

  def mock_sphinx_response(fixture)
    response = sphinx_fixture(fixture, :response)
    @sock = SphinxFakeSocket.new(response, 'rb')
    servers = @sphinx.instance_variable_get(:@servers)
    servers.first.stub(:get_socket => @sock, :free_socket => nil)
  end

  context 'in Query method' do
    it 'should parse response' do
      mock_sphinx_response('query')
      result = @sphinx.Query('wifi', 'test1')
      validate_results_wifi(result)
    end

    it 'should process 64-bit keys' do
      mock_sphinx_response('query_id64')
      result = @sphinx.Query('wifi', 'test2')
      result['total_found'].should == 3
      result['matches'].length.should == 3
      result['matches'][0]['id'].should == 4294967298
      result['matches'][1]['id'].should == 4294967299
      result['matches'][2]['id'].should == 4294967297
    end

    it 'should process errors in Query method' do
      mock_sphinx_response('query_error')
      @sphinx.Query('wifi', 'fakeindex').should be_false
      @sphinx.GetLastError.should =~ /unknown local index/
    end
  end

  context 'in RunQueries method' do
    it 'should parse batch-query responce' do
      mock_sphinx_response('run_queries')
      @sphinx.AddQuery('wifi', 'test1')
      @sphinx.AddQuery('gprs', 'test1')
      results = @sphinx.RunQueries
      results.should be_an_instance_of(Array)
      results.should have(2).items
      validate_results_wifi(results[0])
    end

    it 'should process errors in RunQueries method' do
      mock_sphinx_response('run_queries_error')
      @sphinx.AddQuery('wifi', 'fakeindex')
      r = @sphinx.RunQueries
      r[0]['error'].should_not be_empty
    end
  end

  context 'in BuildExcerpts method' do
    it 'should parse response' do
      mock_sphinx_response('build_excerpts')
      result = @sphinx.BuildExcerpts(['what the world', 'London is the capital of Great Britain'], 'test1', 'the')
      result.should == ['what <b>the</b> world', 'London is <b>the</b> capital of Great Britain']
    end
  end

  context 'in BuildKeywords method' do
    it 'should parse response' do
      mock_sphinx_response('build_keywords')
      result = @sphinx.BuildKeywords('wifi gprs', 'test1', true)
      result.should == [
        { 'normalized' => 'wifi', 'tokenized' => 'wifi', 'hits' => 6, 'docs' => 3 },
        { 'normalized' => 'gprs', 'tokenized' => 'gprs', 'hits' => 1, 'docs' => 1 }
      ]
    end
  end

  context 'in UpdateAttributes method' do
    it 'should parse response' do
      mock_sphinx_response('update_attributes')
      @sphinx.UpdateAttributes('test1', ['group_id'], { 2 => [1] }).should == 1
    end

    it 'should parse response with MVA' do
      mock_sphinx_response('update_attributes_mva')
      @sphinx.UpdateAttributes('test1', ['tags'], { 2 => [[1, 2, 3, 4, 5, 6, 7, 8, 9]] }, true).should == 1
    end
  end

  context 'in Open method' do
    it 'should open socket' do
      @sphinx.Open.should be_true
      socket = @sphinx.servers.first.instance_variable_get(:@socket)
      socket.should_not be_nil
      socket.should be_kind_of(Sphinx::BufferedIO)
      socket.close
    end

    it 'should produce an error when opened twice' do
      @sphinx.Open.should be_true
      @sphinx.Open.should be_false
      @sphinx.GetLastError.should == 'already connected'

      socket = @sphinx.servers.first.instance_variable_get(:@socket)
      socket.should be_kind_of(Sphinx::BufferedIO)
      socket.close
    end
  end

  context 'in Close method' do
    it 'should open socket' do
      @sphinx.Open.should be_true
      @sphinx.Close.should be_true
      @sphinx.servers.first.instance_variable_get(:@socket).should be_nil
    end

    it 'should produce socket is closed' do
      @sphinx.Close.should be_false
      @sphinx.GetLastError.should == 'not connected'
      @sphinx.servers.first.instance_variable_get(:@socket).should be_nil

      @sphinx.Open.should be_true
      @sphinx.Close.should be_true
      @sphinx.Close.should be_false
      @sphinx.GetLastError.should == 'not connected'
      @sphinx.servers.first.instance_variable_get(:@socket).should be_nil
    end
  end

  context 'in Status method' do
    it 'should parse response' do
      mock_sphinx_response('status')
      response = @sphinx.Status
      response.should be_an(Array)
      response.size.should be > 10
    end
  end

  context 'in FlushAttributes method' do
    it 'should not raise an error' do
      mock_sphinx_response('flush_attributes')
      expect {
        @sphinx.FlushAttributes
      }.to_not raise_error
    end
  end

  def validate_results_wifi(result)
    result['total_found'].should == 3
    result['matches'].length.should == 3
    result['time'].should_not be_nil
    result['attrs'].should == {
      'group_id' => Sphinx::SPH_ATTR_INTEGER,
      'created_at' => Sphinx::SPH_ATTR_TIMESTAMP,
      'rating' => Sphinx::SPH_ATTR_FLOAT,
      'tags' => Sphinx::SPH_ATTR_MULTI | Sphinx::SPH_ATTR_INTEGER
    }
    result['fields'].should == [ 'name', 'description' ]
    result['total'].should == 3
    result['matches'].should be_an_instance_of(Array)

    result['matches'][0]['id'].should == 2
    result['matches'][0]['weight'].should == 2
    result['matches'][0]['attrs']['group_id'].should == 2
    result['matches'][0]['attrs']['created_at'].should == 1175683755
    result['matches'][0]['attrs']['tags'].should == [5, 6, 7, 8]
    ('%0.2f' % result['matches'][0]['attrs']['rating']).should == '54.85'

    result['matches'][1]['id'].should == 3
    result['matches'][1]['weight'].should == 2
    result['matches'][1]['attrs']['group_id'].should == 1
    result['matches'][1]['attrs']['created_at'].should == 1175683847
    result['matches'][1]['attrs']['tags'].should == [1, 7, 9, 10]
    ('%0.2f' % result['matches'][1]['attrs']['rating']).should == '16.25'

    result['matches'][2]['id'].should == 1
    result['matches'][2]['weight'].should == 1
    result['matches'][2]['attrs']['group_id'].should == 1
    result['matches'][2]['attrs']['created_at'].should == 1175683690
    result['matches'][2]['attrs']['tags'].should == [1, 2, 3, 4]
    ('%0.2f' % result['matches'][2]['attrs']['rating']).should == '13.32'

    result['words'].should == { 'wifi' => { 'hits' => 6, 'docs' => 3 } }
  end
end
