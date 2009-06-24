require 'ruby/node'
require 'ruby/backfit/list'

module Ruby
  class List < Aggregate
    include Conversions::List
    include Backfit::List
    
    child_accessor :elements
    
    def initialize(elements = nil)
      self.elements = Array(elements)
    end
    
    def nodes
      elements
    end
    
    def method_missing(method, *args, &block)
      elements.respond_to?(method) ? elements.send(method, *args, &block) : super
    end
  end
  
  class DelimitedList < List
    child_accessor :ldelim, :rdelim
    
    def initialize(elements = nil, ldelim = nil, rdelim = nil)
      self.ldelim = ldelim
      self.rdelim = rdelim
      super(elements)
    end
    
    def nodes
      ([ldelim] + super + [rdelim]).flatten.compact
    end
  end
end
