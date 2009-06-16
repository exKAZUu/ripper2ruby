require 'ripper'
require 'ruby'
require 'ripper/ruby_builder/token'
require 'ripper/ruby_builder/stack'

Dir[File.dirname(__FILE__) + '/ruby_builder/callbacks/*.rb'].each { |file| require file }

class Ripper
  class RubyBuilder < Ripper::SexpBuilder
    class << self
      def build(src)
        new(src).parse
      end
    end

    WHITESPACE = [:@sp, :@nl, :@ignored_nl]

    include Scanner, Core, Body, Method, If, Case, While, For, Call, Block, Params,
            String, Symbol, Hash, Array, Args, Assignment, Operator

    attr_reader :src, :filename, :stack

    def initialize(src, filename = nil, lineno = nil)
      @src = src || filename && File.read(filename)
      @filename = filename
      @whitespace = ''
      @stack = []
      @_stack_ignore_stack = [[]]
      @stack = Stack.new
      super
    end

    def position
      [lineno - 1, column]
    end

    def push(sexp)
      stack.push(Token.new(*sexp))
    end

    protected

      def build_identifier(token)
      end

      def build_token(token)
        Ruby::Token.new(token.value, token.position, token.whitespace) if token
      end

      def pop(*args)
        stack.pop(*args)
      end

      def pop_token(*types)
        options = types.last.is_a?(::Hash) ? types.pop : {}
        options[:max] = 1
        pop_tokens(*types, options).first
      end

      def pop_tokens(*types)
        options = types.last.is_a?(::Hash) ? types.pop : {}
        stack_ignore(*WHITESPACE) do
          types.map { |type| pop(type, options).map { |token| build_token(token) } }.flatten.compact
        end
      end

      def pop_whitespace
        pop(*WHITESPACE).reverse.map { |token| token.value }.join
      end

      def stack_ignore(*types, &block)
        stack.ignore_types(*types, &block)
      end
  end
end