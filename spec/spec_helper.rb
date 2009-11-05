require File.dirname(__FILE__) + '/../init'

# Helper exception class to omit real dialogue between client and server
class SphinxSpecError < StandardError; end

# Runs PHP fixture to get request dump
def sphinx_fixture(name)
  `php #{File.dirname(__FILE__)}/fixtures/#{name}.php`
end

def sphinx_create_client
  @sphinx = Sphinx::Client.new
  @sock = mock('SocketMock')

  servers = @sphinx.instance_variable_get(:@servers)
  servers.first.stub(:get_socket => @sock, :free_socket => nil)
  @sphinx.stub!(:parse_response).and_raise(SphinxSpecError)
  return @sphinx
end

def sphinx_safe_call
  yield
rescue SphinxSpecError
end
