module Sphinx
  begin
    # Try to use the SystemTimer gem instead of Ruby's timeout library
    # when running on something that looks like Ruby 1.8.x. See:
    #   http://ph7spot.com/articles/system_timer
    # We don't want to bother trying to load SystemTimer on jruby and
    # ruby 1.9+
    if defined?(JRUBY_VERSION) || (RUBY_VERSION >= '1.9')
      require 'timeout'
      Timeout = ::Timeout
    else
      require 'system_timer'
      Timeout = ::SystemTimer
    end
  rescue LoadError => e
    # puts "[sphinx] Could not load SystemTimer gem, falling back to Ruby's slower/unsafe timeout library: #{e.message}"
    require 'timeout'
    Timeout = ::Timeout
  end

  # Executes specified block respecting timeout passed.
  #
  # @private
  def self.safe_execute(timeout = 5, &block)
    if timeout > 0
      Sphinx::Timeout.timeout(timeout, &block)
    else
      yield
    end
  end
end
