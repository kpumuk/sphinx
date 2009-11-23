# Sphinx Client API
#
# Author::    Dmytro Shteflyuk <mailto:kpumuk@kpumuk.info>.
# Copyright:: Copyright (c) 2006 — 2009 Dmytro Shteflyuk
# License::   Distributes under the same terms as Ruby
# Version::   0.9.10-r2091
# Website::   http://kpumuk.info/projects/ror-plugins/sphinx
# Sources::   http://github.com/kpumuk/sphinx
#
# This library is distributed under the terms of the Ruby license.
# You can freely distribute/modify this library.
#
module Sphinx
  VERSION = begin
    config = YAML.load(File.read(File.dirname(__FILE__) + '/../VERSION.yml'))
    "#{config[:major]}.#{config[:minor]}.#{config[:patch]}.#{config[:build]}"
  end

  # Base class for all Sphinx errors
  class SphinxError < StandardError; end

  # Connect error occurred on the API side.
  class SphinxConnectError < SphinxError; end

  # Request error occurred on the API side.
  class SphinxResponseError < SphinxError; end

  # Internal error occurred inside searchd.
  class SphinxInternalError < SphinxError; end

  # Temporary error occurred inside searchd.
  class SphinxTemporaryError < SphinxError; end

  # Unknown error occurred inside searchd.
  class SphinxUnknownError < SphinxError; end
end

require 'net/protocol'
require 'socket'
require 'zlib'

path = File.dirname(__FILE__)
require "#{path}/sphinx/constants"
require "#{path}/sphinx/indifferent_access"
require "#{path}/sphinx/request"
require "#{path}/sphinx/response"
require "#{path}/sphinx/timeout"
require "#{path}/sphinx/buffered_io"
require "#{path}/sphinx/server"
require "#{path}/sphinx/client"
