# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/reader'

# w3c test suite: http://www.w3.org/TR/rdf-testcases/

describe "RDF::RDFXML::Reader" do
  let!(:doap) {File.expand_path("../../etc/doap.rdf", __FILE__)}
  let!(:doap_nt) {File.expand_path("../../etc/doap.nt", __FILE__)}
  let!(:doap_count) {File.open(doap_nt).each_line.to_a.length}

  before(:each) do
    @reader_input = File.read(doap)
    @reader = RDF::RDFXML::Reader.new(@reader_input)
    @reader_count = doap_count
  end

  include RDF_Reader

  context "discovery" do
    {
      "rdfxml" => RDF::Reader.for(:rdfxml),
      "etc/foaf.rdf" => RDF::Reader.for("etc/foaf.rdf"),
      "foaf.rdf" => RDF::Reader.for(:file_name      => "foaf.rdf"),
      ".rdf" => RDF::Reader.for(:file_extension => "rdf"),
      "application/rdf+xml" => RDF::Reader.for(:content_type   => "application/rdf+xml"),
    }.each_pair do |label, format|
      it "should discover '#{label}'" do
        expect(format).to eq RDF::RDFXML::Reader
      end
    end
  end

  context :interface do
    before(:each) do
      @sampledoc = %q(<?xml version="1.0" ?>
        <GenericXML xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ex="http://example.org/">
          <rdf:RDF>
            <rdf:Description rdf:about="http://example.org/one">
              <ex:name>Foo</ex:name>
            </rdf:Description>
          </rdf:RDF>
          <blablabla />
          <rdf:RDF>
            <rdf:Description rdf:about="http://example.org/two">
              <ex:name>Bar</ex:name>
            </rdf:Description>
          </rdf:RDF>
        </GenericXML>)
    end
    
    it "should yield reader" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::RDFXML::Reader)
      RDF::RDFXML::Reader.new(@sampledoc) do |reader|
        inner.called(reader.class)
      end
    end
    
    it "should return reader" do
      expect(RDF::RDFXML::Reader.new(@sampledoc)).to be_a(RDF::RDFXML::Reader)
    end
    
    it "should yield statements" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::Statement).twice
      RDF::RDFXML::Reader.new(@sampledoc).each_statement do |statement|
        inner.called(statement.class)
      end
    end
    
    it "should yield triples" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::URI, RDF::URI, RDF::Literal).twice
      RDF::RDFXML::Reader.new(@sampledoc).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
  end
  
  [:rexml, :nokogiri].each do |library|
    context library.to_s, :library => library, skip: ("Nokogiri not loaded" if library == :nokogiri && !defined?(::Nokogiri)) do
      before(:all) {@library = library}
      
      context "simple parsing" do
        it "should recognise and create single triple for empty non-RDF root" do
          sampledoc = %(<?xml version="1.0" ?>
            <NotRDF />)
            expected = %q(
              @prefix xml: <http://www.w3.org/XML/1998/namespace> .
              [ a xml:NotRDF] .
            )
          graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          expect(graph).to be_equivalent_graph(expected, :about => "http://example.com/", :trace => @debug)
        end
  
        it "should parse on XML documents with multiple RDF nodes" do
          sampledoc = %q(<?xml version="1.0" ?>
            <GenericXML xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ex="http://example.org/">
              <rdf:RDF>
                <rdf:Description rdf:about="http://example.org/one">
                  <ex:name>Foo</ex:name>
                </rdf:Description>
              </rdf:RDF>
              <blablabla />
              <rdf:RDF>
                <rdf:Description rdf:about="http://example.org/two">
                  <ex:name>Bar</ex:name>
                </rdf:Description>
              </rdf:RDF>
            </GenericXML>)
          graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          objects = graph.statements.map {|s| s.object.value}.sort
          expect(objects).to include("Bar", "Foo")
        end
  
        it "should be able to parse a simple single-triple document" do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
            xmlns:ex="http://www.example.org/" xml:lang="en" xml:base="http://www.example.org/foo">
              <ex:Thing rdf:about="http://example.org/joe" ex:name="bar">
                <ex:belongsTo rdf:resource="http://tommorris.org/" />
                <ex:sampleText rdf:datatype="http://www.w3.org/2001/XMLSchema#string">foo</ex:sampleText>
                <ex:hadADodgyRelationshipWith>
                  <rdf:Description>
                    <ex:name>Tom</ex:name>
                    <ex:hadADodgyRelationshipWith>
                      <rdf:Description>
                        <ex:name>Rob</ex:name>
                        <ex:hadADodgyRelationshipWith>
                          <rdf:Description>
                            <ex:name>Mary</ex:name>
                          </rdf:Description>
                        </ex:hadADodgyRelationshipWith>
                      </rdf:Description>
                    </ex:hadADodgyRelationshipWith>
                  </rdf:Description>
                </ex:hadADodgyRelationshipWith>
              </ex:Thing>
            </rdf:RDF>)

          expected = %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

            <http://example.org/joe> a <http://www.example.org/Thing>;
               <http://www.example.org/name> "bar"@en;
               <http://www.example.org/sampleText> "foo"^^xsd:string;
               <http://www.example.org/belongsTo> <http://tommorris.org/>;
               <http://www.example.org/hadADodgyRelationshipWith> [
                 <http://www.example.org/hadADodgyRelationshipWith> [
                   <http://www.example.org/hadADodgyRelationshipWith> [
                     <http://www.example.org/name> "Mary"@en];
                   <http://www.example.org/name> "Rob"@en];
                 <http://www.example.org/name> "Tom"@en] .
          )
          graph = parse(sampledoc, :base_uri => "http://example.com/", :validate => true)
          expect(graph).to be_equivalent_graph(expected, :about => "http://example.com/", debug: @debug)
        end

        it "should be able to handle Bags/Alts etc." do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:eg="http://example.org/">
              <rdf:Bag>
                <rdf:li rdf:resource="http://tommorris.org/" />
                <rdf:li rdf:resource="http://twitter.com/tommorris" />
              </rdf:Bag>
            </rdf:RDF>)
          graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          expect(graph.predicates.map(&:to_s)).to include("http://www.w3.org/1999/02/22-rdf-syntax-ns#_1", "http://www.w3.org/1999/02/22-rdf-syntax-ns#_2")
        end
      end

      it "extracts embedded RDF/XML" do
        svg = %(<?xml version="1.0" encoding="UTF-8"?>
          <svg width="12cm" height="4cm" viewBox="0 0 1200 400"
          xmlns:dc="http://purl.org/dc/terms/"
          xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
          xml:base="http://example.net/"
          xml:lang="fr"
          xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny">
            <desc property="dc:description">A yellow rectangle with sharp corners.</desc>
            <metadata>
              <rdf:RDF>
                <rdf:Description rdf:about="">
                  <dc:title>Test 0304</dc:title>
                </rdf:Description>
              </rdf:RDF>
            </metadata>
            <!-- Show outline of canvas using 'rect' element -->
            <rect x="1" y="1" width="1198" height="398"
                  fill="none" stroke="blue" stroke-width="2"/>
            <rect x="400" y="100" width="400" height="200"
                  fill="yellow" stroke="navy" stroke-width="10"  />
          </svg>
        )
        expected = %(
        	<http://example.net/> <http://purl.org/dc/terms/title> "Test 0304"@fr .
        )
        graph = parse(svg, :base_uri => "http://example.com/", :validate => true)
        expect(graph).to be_equivalent_graph(expected, debug: @debug)
      end

      context :exceptions do
        it "should raise an error if rdf:aboutEach is used, as per the negative parser test rdfms-abouteach-error001 (rdf:aboutEach attribute)" do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:eg="http://example.org/">

              <rdf:Bag rdf:ID="node">
                <rdf:li rdf:resource="http://example.org/node2"/>
              </rdf:Bag>

              <rdf:Description rdf:aboutEach="#node">
                <dc:rights xmlns:dc="http://purl.org/dc/elements/1.1/">me</dc:rights>

              </rdf:Description>

            </rdf:RDF>)
  
          expect do
            graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          end.to raise_error(RDF::ReaderError, /Obsolete attribute .*aboutEach/)
        end

        it "should raise an error if rdf:aboutEachPrefix is used, as per the negative parser test rdfms-abouteach-error002 (rdf:aboutEachPrefix attribute)" do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:eg="http://example.org/">

              <rdf:Description rdf:about="http://example.org/node">
                <eg:property>foo</eg:property>
              </rdf:Description>

              <rdf:Description rdf:aboutEachPrefix="http://example.org/">
                <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">me</dc:creator>

              </rdf:Description>

            </rdf:RDF>)
  
          expect do
            graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          end.to raise_error(RDF::ReaderError, /Obsolete attribute .*aboutEachPrefix/)
        end

        it "should fail if given a non-ID as an ID (as per rdfcore-rdfms-rdf-id-error001)" do
          sampledoc = %q(<?xml version="1.0"?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
              <rdf:Description rdf:ID='333-555-666' />
            </rdf:RDF>)
  
          expect do
            graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          end.to raise_error(RDF::ReaderError, /ID addtribute '.*' must be a NCName/)
        end

        it "should make sure that the value of rdf:ID attributes match the XML Name production (child-element version)" do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:eg="http://example.org/">
             <rdf:Description>
               <eg:prop rdf:ID="q:name" />
             </rdf:Description>
            </rdf:RDF>)
  
          expect do
            graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          end.to raise_error(RDF::ReaderError, /ID addtribute '.*' must be a NCName/)
        end

        it "should make sure that the value of rdf:ID attributes match the XML Name production (data attribute version)" do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:eg="http://example.org/">
              <rdf:Description rdf:ID="a/b" eg:prop="val" />
            </rdf:RDF>)
  
          expect do
            graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          end.to raise_error(RDF::ReaderError, "ID addtribute 'a/b' must be a NCName")
        end
  
        it "should detect bad bagIDs" do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
              <rdf:Description rdf:bagID='333-555-666' />
            </rdf:RDF>)
    
          expect do
            graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          end.to raise_error(RDF::ReaderError, /Obsolete attribute .*bagID/)
        end
      end
  
      context :reification do
        it "should be able to reify according to §2.17 of RDF/XML Syntax Specification" do
          sampledoc = %q(<?xml version="1.0"?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:ex="http://example.org/stuff/1.0/"
                     xml:base="http://example.org/triples/">
              <rdf:Description rdf:about="http://example.org/">
                <ex:prop rdf:ID="triple1">blah</ex:prop>
              </rdf:Description>
            </rdf:RDF>)

          expected = %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix ex: <http://example.org/stuff/1.0/> .
            <http://example.org/> ex:prop "blah" .
            <http://example.org/triples/#triple1> a rdf:Statement;
              rdf:subject <http://example.org/>;
              rdf:predicate ex:prop;
              rdf:object "blah" .
          )

          graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          expect(graph).to be_equivalent_graph(expected, :about => "http://example.com/", debug: @debug)
        end
      end
  
      context :entities do
        it "decodes attribute value" do
          sampledoc = %q(<?xml version="1.0"?>
            <!DOCTYPE rdf:RDF [<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#" >]>
            <rdf:RDF xmlns:rdf="&rdf;"
                     xmlns:ex="http://example.org/stuff/1.0/"
                     xml:base="http://example.org/triples/">
              <rdf:Description rdf:about="http://example.org/">
                <ex:prop rdf:ID="triple1">blah</ex:prop>
              </rdf:Description>
            </rdf:RDF>)

          expected = %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix ex: <http://example.org/stuff/1.0/> .
            <http://example.org/> ex:prop "blah" .
            <http://example.org/triples/#triple1> a rdf:Statement;
              rdf:subject <http://example.org/>;
              rdf:predicate ex:prop;
              rdf:object "blah" .
          )

          graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          expect(graph).to be_equivalent_graph(expected, :about => "http://example.com/", debug: @debug)
        end

        it "decodes element content" do
          sampledoc = %q(<?xml version="1.0"?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:ex="http://example.org/stuff/1.0/">
              <rdf:Description rdf:about="http://example.org/">
                <ex:prop>&gt;</ex:prop>
              </rdf:Description>
            </rdf:RDF>)

          expected = %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix ex: <http://example.org/stuff/1.0/> .
            <http://example.org/> ex:prop ">" .
          )

          graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
          expect(graph).to be_equivalent_graph(expected, :about => "http://example.com/", debug: @debug)
        end
      end
    end
  end

  def parse(input, options)
    @debug = []
    graph = RDF::Repository.new
    RDF::RDFXML::Reader.new(input, options.merge(debug: @debug, :library => @library)).each do |statement|
      graph << statement
    end
    graph
  end
end

