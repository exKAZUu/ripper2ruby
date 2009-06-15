$: << File.expand_path(File.dirname(__FILE__) + '/../lib')

require 'ripper/ruby_builder'
require 'test/unit'
require 'pp'

module TestRubyBuilderHelper
  def sexp(src)
    Ripper::SexpBuilder.new(src).parse
  end

  def build(src)
    Ripper::RubyBuilder.build(src)
  end

  def node(src, klass)
    build(src).statement { |n| n.is_a?(klass) } or nil
  end

  def string(src)
    node(src, Ruby::String)
  end

  def array(src)
    node(src, Ruby::Array)
  end

  def hash(src)
    node(src, Ruby::Hash)
  end

  def call(src)
    node(src, Ruby::Call)
  end

  def arguments(src)
    call(src).arguments
  end

  def method(src)
    node(src, Ruby::Method)
  end

  def const(src)
    node(src, Ruby::Const)
  end
end