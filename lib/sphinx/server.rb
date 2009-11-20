# Represents an instance of searchd server.
#
# @private
class Sphinx::Server
  # The host the Sphinx server is running on
  attr_reader :host

  # The port the Sphinx server is listening on
  attr_reader :port

  # The path to UNIX socket where Sphinx server is running on
  attr_reader :path
  
  # Creates a new instance of +Server+.
  #
  # Parameters:
  # * +sphinx+ -- an instance of <tt>Sphinx::Client</tt>.
  # * +host+ -- name of host where search is running (if +path+ is not specified).
  # * +port+ -- searchd port (if +path+ is not specified).
  # * +path+ -- an absolute path to the UNIX socket.
  #
  def initialize(sphinx, host, port, path)
    @sphinx = sphinx
    @host = host
    @port = port
    @path = path
    
    @socket = nil
  end
  
  # Gets the opened socket to the server.
  #
  # You can pass a block to make any connection establishing related things,
  # like protocol version interchange. They will be treated as a part of
  # connection routine, so connection timeout will include them.
  #
  # In case of connection error, +SphinxConnectError+ exception will be raised.
  #
  # Method returns opened socket, so do not forget to close it using +free_socket+
  # method. Make sure you will close socket in case of any emergency.
  #
  def get_socket(&block)
    if persistent?
      yield @socket
      @socket
    else
      socket = nil
      Sphinx::safe_execute(@sphinx.timeout) do
        socket = establish_connection

        # Do custom initialization
        yield socket if block_given?
      end
      socket
    end
  rescue SocketError, SystemCallError, IOError, EOFError, ::Timeout::Error, ::Errno::EPIPE => e
    # Close previously opened socket (in case of it has been really opened)
    free_socket(socket, true)
    
    location = @path || "#{@host}:#{@port}"
    error = "connection to #{location} failed ("
    if e.kind_of?(SystemCallError)
      error << "errno=#{e.class::Errno}, "
    end
    error << "msg=#{e.message})"
    raise Sphinx::SphinxConnectError, error
  end
  
  # Closes previously opened socket.
  #
  # Pass socket retrieved with +get_socket+ method when finished work. It does
  # not close persistent sockets, but if really you need to do it, pass +true+
  # as +force+ parameter value.
  # 
  def free_socket(socket, force = false)
    # Socket has not been open
    return false if socket.nil?
    
    # Do we try to close persistent socket?
    if socket == @socket
      # do not close it if not forced
      if force
        @socket.close unless @socket.closed?
        @socket = nil
        true
      else
        false
      end
    else
      # Just close this socket
      socket.close unless socket.closed?
      true
    end
  end
  
  # Makes specified socket persistent.
  #
  # Previous persistent socket will be closed as well.
  def make_persistent!(socket)
    unless socket == @socket
      close_persistent!
      @socket = socket
    end
    @socket
  end
  
  # Closes persistent socket.
  def close_persistent!
    free_socket(@socket, true)
  end
  
  # Gets a value indicating whether server has persistent socket associated.
  def persistent?
    !@socket.nil?
  end
  
  private
  
    # This is internal method which establishes a connection to a configured server.
    #
    # Method configures various socket options (like TCP_NODELAY), and
    # sets socket timeouts.
    #
    # It does not close socket on any failure, please do it from calling code!
    # 
    def establish_connection
      if @path
        sock = UNIXSocket.new(@path)
      else
        sock = TCPSocket.new(@host, @port)
      end

      io = Sphinx::BufferedIO.new(sock)
      io.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      if @sphinx.reqtimeout > 0
        io.read_timeout = @sphinx.reqtimeout
    
        # This is a part of memcache-client library.
        #
        # Getting reports from several customers, including 37signals,
        # that the non-blocking timeouts in 1.7.5 don't seem to be reliable.
        # It can't hurt to set the underlying socket timeout also, if possible.
        secs = Integer(@sphinx.reqtimeout)
        usecs = Integer((@sphinx.reqtimeout - secs) * 1_000_000)
        optval = [secs, usecs].pack("l_2")
        begin
          io.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval
          io.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, optval
        rescue Exception => ex
          # Solaris, for one, does not like/support socket timeouts.
          @warning = "Unable to use raw socket timeouts: #{ex.class.name}: #{ex.message}"
        end
      else
        io.read_timeout = false
      end
      
      io
    end
end
