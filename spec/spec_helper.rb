require 'bundler/setup'
require 'sphinx'
require 'stringio'

# Helper exception class to omit real dialogue between client and server
class SphinxSpecError < StandardError; end

# Runs PHP fixture to get request dump
def sphinx_fixture(name, type = :request)
  File.open(File.join(File.dirname(__FILE__), 'fixtures', "#{type}s", "#{name}.dat"), 'rb') do |f|
    f.read
  end
end

class SphinxFakeSocket
  def initialize(data = '', mode = 'rb')
    @sock = StringIO.new(data, mode)
  end

  def method_missing(method, *args)
    @sock.__send__(method, *args)
  rescue IOError
  end
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
