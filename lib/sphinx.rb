require 'socket'
require 'net/protocol'

module Sphinx
end

require File.dirname(__FILE__) + '/sphinx/request'
require File.dirname(__FILE__) + '/sphinx/response'
require File.dirname(__FILE__) + '/sphinx/client'
require File.dirname(__FILE__) + '/sphinx/timeout'
require File.dirname(__FILE__) + '/sphinx/buffered_io'
