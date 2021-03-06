$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift File.dirname(__FILE__)

require "bundler/setup"
require 'rspec'
require 'matchers'
require 'rdf/rdfxml'
require 'rdf/ntriples'
require 'rdf/turtle'
require 'rdf/spec'
require 'rdf/spec/matchers'
require 'rdf/isomorphic'
require 'open-uri/cached'
begin
  require 'nokogiri'
rescue LoadError => e
  :rexml
end

# Create and maintain a cache of downloaded URIs
URI_CACHE = File.expand_path(File.join(File.dirname(__FILE__), "uri-cache"))
Dir.mkdir(URI_CACHE) unless File.directory?(URI_CACHE)
OpenURI::Cache.class_eval { @cache_path = URI_CACHE }

::RSpec.configure do |c|
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
  c.include(RDF::Spec::Matchers)
end

# For testing, modify RDF::Util::File.open_file to use Kernel.open, so we can just use open-uri-cached
module RDF::Util::File
  def self.open_file(filename_or_url, options = {}, &block)
    options = options[:headers] || {} if filename_or_url.start_with?('http')
    Kernel.open(filename_or_url, options, &block)
  end
end

# Heuristically detect the input stream
def detect_format(stream)
  # Got to look into the file to see
  if stream.is_a?(IO) || stream.is_a?(StringIO)
    stream.rewind
    string = stream.read(1000)
    stream.rewind
  else
    string = stream.to_s
  end
  case string
  when /<\w+:RDF/ then :rdfxml
  when /<RDF/     then :rdfxml
  #when /<html/i   then :rdfa
  when /@prefix/i then :ttl
  else                 :ntriples
  end
end
