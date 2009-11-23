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

require File.dirname(__FILE__) + '/sphinx/constants'
require File.dirname(__FILE__) + '/sphinx/request'
require File.dirname(__FILE__) + '/sphinx/response'
require File.dirname(__FILE__) + '/sphinx/timeout'
require File.dirname(__FILE__) + '/sphinx/buffered_io'
require File.dirname(__FILE__) + '/sphinx/server'
require File.dirname(__FILE__) + '/sphinx/client'
