module Ruby
  class Node
    module Traversal
      class UnknownArgumentWrapper < StandardError
      end      
      
      def select(*args, &block)
        result = []
        result << self if matches?(args.dup, &block)
        children = (prolog.try(:elements).to_a || []) + nodes
        children.flatten.compact.inject(result) do |result, node|
          if node.class.to_s == 'Symbol'
            return result
          end
          result + node.select(*args, &block)
        end
      end

      def matches?(args, &block)
        conditions = args.last.is_a?(::Hash) ? args.pop : {}
        conditions[:is_a] = args unless args.empty?

        conditions.inject(!conditions.empty?) do |result, (type, value)|
          result && case type
          when :is_a
            has_type?(value)
          when :class
            is_instance_of?(value)
          when :token
            has_token?(value)
          when :value
            has_value?(value)
          when :identifier
            has_identifier?(value)
          when :const
            has_const?(value)
          when :block
            has_block?
          when :namespace          
            has_namespace?(value)
          when :superclass
            superclass?(value)
          when :args, :params
            args?(value)                        
          when :block_params          
            args?(value, has_block?)          
          when :pos, :position
            position?(value)
          when :right_of
            right_of?(value)
          when :left_of
            left_of?(value)
          end
        end && (!block_given? || block.call(self))
      end

      def has_type?(klass)
        case klass
        when ::Array
          klass.each { |klass| return true if has_type?(klass) } and false
        else
          is_a?(klass) # allow to pass a symbol or string, too
        end
      end

      def args?(value, with_block = nil)
        found = 0        
        obj = with_block ? self.block : self
        args_list = get_args_list(obj)
        return false if !args_list    
        args_list.elements.each do |arg|    
          argument = retrieve_arg(arg) 
          value.each do |v|            
            v = v[:array] if v.respond_to?(:has_key?) && v[:array]              
            found += 1 if argument == v
          end
        end       
        return found == value.size
      end                             

      def get_args_list(obj)                         
        return obj.params if obj.respond_to? :params 
        return obj.arguments if obj.respond_to? :arguments 
        # return obj if obj.class == Ruby::ArgsList       
      end

      def resolve_arg_wrapper(arg_wrapper)
        return arg_wrapper.arg if arg_wrapper.respond_to? :arg            
        return arg_wrapper.param if arg_wrapper.respond_to? :param            
        return arg_wrapper if arg_wrapper.class == Ruby::Arg
        arg_wrapper
      end

      def retrieve_arg(arg_wrapper)
        arg = resolve_arg_wrapper(arg_wrapper)
        argument = get_arg(arg)       
        convert_value(argument, arg)
      end

      def convert_value(value, type = nil)
        type_val = type || value
        case type_val                    
        when Ruby::Symbol  
          value.to_sym
        when Ruby::Integer
          value.to_i                          
        when Ruby::Float
          value.to_f        
        when Ruby::Hash
          type ? get_hash(type) : value       
        when Ruby::Array
          type ? get_array(type) : value       
        when Ruby::Assoc   
          return get_assoc(type)
        else
          value
        end
      end      

      def get_arg(arg)  
        get_symbol(arg) || get_assoc(arg) || get_composite(arg) || get_identifier(arg) || get_token(arg) || resolve_arg_wrapper(arg)
      end

      def get_symbol(arg)
        return nil if !(arg.class == Ruby::Symbol)
        t = get_token(arg)
        t ? t.to_sym : nil
      end

      def get_composite(arg)
        return nil if !arg.respond_to? :elements
        e = arg.elements
        return get_arg(e[0]) if e.size == 1
        get_hash(e) || get_array(e)
      end

      def get_array(args)
        return nil if arg.class != Ruby::Array
        arr = []  
        args.each do |arg|
           arr << get_arg(arg)
        end
        return arr if !arr.empty?
        nil
      end 

      def get_hash(args)    
        return nil if !args.class == Ruby::Hash
        items = args.respond_to?(:elements) ? args.elements : args 
        hash = {}  
        items.each do |arg|  
           hash_val = get_arg(arg) 
           hash.merge!(hash_val)
        end    
        return hash if !hash.empty?
        nil
      end 

      def get_assoc(arg)
        return nil if !(arg.class == Ruby::Assoc) 
        get_hash_item(arg)
      end

      def get_hash_item(arg)
        return if !arg.respond_to? :key
        key = get_key(arg.key)
        value = get_value(arg.value)
        return {key => value}
      end

      def get_key(key)
        if key.respond_to? :identifier
         id = get_identifier(key)
        end
        return id.to_sym if key.class == Ruby::Symbol
        return get_token(key) if key.class == Ruby::Variable
        id
      end

      # Needs rework!
      def get_value(value)
        real_value = get_arg(value)
        convert_value(real_value, value)
      end

      def get_identifier(arg)
        get_token(arg.identifier) if arg.respond_to? :identifier
      end

      def get_string(arg)
        get_token(arg.elements[0]) if arg.class == Ruby::String
      end

      def get_token(arg)
        arg.token if arg.respond_to? :token
      end

      def is_instance_of?(klass)
        case klass
        when ::Array
          klass.each { |klass| return true if has_type?(klass) } and false
        else
          instance_of?(klass) # allow to pass a symbol or string, too
        end
      end

      def has_token?(token)
        case token
        when ::Array
          type.each { |type| return true if has_token?(token) } and false
        else
          self.token == token
        end if respond_to?(:token)
      end

      def has_const?(value)
        if respond_to?(:const)
          if namespace?(value)
            name = value.split('::').last
            return self.const.identifier.token == name
          end
        end
        false
      end

      def has_block?
        respond_to? :block
      end

      def superclass?(value)      
        if class_or_module?
          ns = get_full_namespace(self.super_class) 
          return ns == value
        end
        false      
      end

      def has_namespace?(value)
        if respond_to?(:namespace)
          return self.namespace.identifier.token == value
        end
        false
      end


      def has_identifier?(value)
        if respond_to?(:identifier)
          id = self.identifier
          
          if namespace?(value)
            return id.token.to_s == value.to_s if id.respond_to?(:token)
            if id.respond_to?(:identifier)
              name = value.split('::').last
              return id.identifier.token == name
            end
          end
        else
          has_const?(value)
        end
      end

      def has_value?(value)
        self.value == value if respond_to?(:value)
      end

      def position?(pos)
        position == pos
      end

      def left_of?(right)
        right.nil? || self.position < right.position
      end

      def right_of?(left)
        left.nil? || left.position < self.position
      end

      protected

      def namespace?(full_name)
        if full_name.split('::').size > 1
          namespaces = full_name.split('::')[0..-2]
          namespace = namespaces.join('::')

          if class_or_module?
            return module_namespace?(namespace)
          end
        end
        true
      end

      def class_or_module?
        [Ruby::Class, Ruby::Module].include?(self.class)
      end

      def module_namespace?(namespace)
        namespace == get_full_namespace(get_namespace) 
      end

      def get_namespace
        return self.const.namespace if self.respond_to?(:const)
        self.identifier.namespace      
      end

      def get_full_namespace(ns)
        if ns.respond_to?(:namespace)
          name = ns.identifier.token 
          parent_ns = get_full_namespace(ns.namespace)
          name += ('::' + parent_ns) if !parent_ns.empty?
          return name.split('::').reverse.join('::')
        else
          return ns.identifier.token if ns.respond_to?(:identifier)
          ""
        end
      end
    end
  end
end
