module Sphinx
  class Validation
    include Singleton

    def integer(name, value)
      raise ArgumentError, "'#{name}' argument must be Integer" unless Integer === value
    end

    def numeric(name, value)
      raise ArgumentError, "'#{name}' argument must be Numeric" unless Numeric === value
    end
    
    def string(name, value)
      raise ArgumentError, "'#{name}' argument must be String" unless String === value
    end

    def boolean(name, value)
      unless TrueClass === value or FalseClass === value
        raise ArgumentError, "'#{name}' argument must be String or Boolean"
      end
    end
    
    def string_or_symbol(name, value)
      unless String === value or Symbol === value
        raise ArgumentError, "'#{name}' argument must be String or Symbol"
      end
    end

    def array_of(name, value, klass)
      msg = "'#{name}' argument must be Array of #{klass}"
      raise ArgumentError, msg unless Array === value and value.all? { |el| klass === el }
    end
    
    def less_or_equal(name1, value1, name2, value2)
      raise ArgumentError, "'#{name1}' argument must be less or equal to '#{name2}'" unless value1 <= value2
    end
  end
  
  def self.validate(&block)
    Validation.instance.instance_eval(&block)
  end
end
