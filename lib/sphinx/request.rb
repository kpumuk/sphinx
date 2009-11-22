module Sphinx
  # Pack ints, floats, strings, and arrays to internal representation
  # needed by Sphinx search engine.
  #
  class Request
    # Initialize new empty request.
    #
    def initialize
      @request = ''
    end

    # Put int(s) to request.
    #
    # @param [Integer] ints one or more integers to put to the request.
    # @return [Request] self.
    #
    # @example
    #   request.put_int 10
    #   request.put_int 10, 20, 30
    #   request.put_int *[10, 20, 30]
    #
    def put_int(*ints)
      ints.each { |i| @request << [i].pack('N') }
      self
    end

    # Put 64-bit int(s) to request.
    #
    # @param [Integer] ints one or more 64-bit integers to put to the request.
    # @return [Request] self.
    #
    # @example
    #   request.put_int64 10
    #   request.put_int64 10, 20, 30
    #   request.put_int64 *[10, 20, 30]
    #
    def put_int64(*ints)
      ints.each { |i| @request << [i].pack('q').reverse }#[i >> 32, i & ((1 << 32) - 1)].pack('NN') }
      self
    end

    # Put strings to request.
    #
    # @param [String] strings one or more strings to put to the request.
    # @return [Request] self.
    #
    # @example
    #   request.put_string 'str1'
    #   request.put_string 'str1', 'str2', 'str3'
    #   request.put_string *['str1', 'str2', 'str3']
    #
    def put_string(*strings)
      strings.each { |s| @request << [s.length].pack('N') + s }
      self
    end

    # Put float(s) to request.
    #
    # @param [Integer, Float] floats one or more floats to put to the request.
    # @return [Request] self.
    #
    # @example
    #   request.put_float 10
    #   request.put_float 10, 20, 30
    #   request.put_float *[10, 20, 30]
    #
    def put_float(*floats)
      floats.each do |f|
        t1 = [f.to_f].pack('f') # machine order
        t2 = t1.unpack('L*').first # int in machine order
        @request << [t2].pack('N')
      end
      self
    end

    # Put array of ints to request.
    #
    # @param [Array<Integer>] arr an array of integers to put to the request.
    # @return [Request] self.
    #
    # @example
    #   request.put_int_array [10]
    #   request.put_int_array [10, 20, 30]
    #
    def put_int_array(arr)
      put_int arr.length, *arr
      self
    end

    # Put array of 64-bit ints to request.
    #
    # @param [Array<Integer>] arr an array of integers to put to the request.
    # @return [Request] self.
    #
    # @example
    #   request.put_int64_array [10]
    #   request.put_int64_array [10, 20, 30]
    #
    def put_int64_array(arr)
      put_int(arr.length)
      put_int64(*arr)
      self
    end

    # Returns the serialized request.
    #
    # @return [String] serialized request.
    #
    def to_s
      @request
    end

    # Returns CRC32 of the serialized request.
    #
    # @return [Integer] CRC32 of the serialized request.
    #
    def crc32
      Zlib.crc32(@request)
    end
  end
end
