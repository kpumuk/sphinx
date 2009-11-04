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
    puts "[sphinx] Could not load SystemTimer gem, falling back to Ruby's slower/unsafe timeout library: #{e.message}"
    require 'timeout'
    Timeout = ::Timeout
  end
  
  def self.safe_execute(timeout = 5, attempts = 3, &block)
    if timeout > 0
      begin
        Sphinx::Timeout.timeout(timeout, &block)
      rescue ::Timeout::Error, ::Errno::EPIPE
        attempts -= 1
        raise if attempts <= 0
        retry
      end
    else
      yield
    end
  end
end
