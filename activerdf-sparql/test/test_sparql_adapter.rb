# Author:: Eyal Oren
# Copyright:: (c) 2005-2006
# License:: LGPL

require "rubygems"
require 'active_rdf'
require 'test/unit'
require 'active_rdf/storage/federated_store'
require 'active_rdf/query/query'


class TestSparqlAdapter < Test::Unit::TestCase
  include ActiveRDF

  def setup
    ConnectionPool.clear
    @adapter = ConnectionPool.add(:type => :sparql, :url => 'http://dbpedia.org/sparql', :engine => :virtuoso)
  end

  def teardown
  end

  def test_registration
    assert_instance_of SparqlAdapter, @adapter
  end

  def test_limit_offset
    one = Query.new.select(:s).where(:s,:p,:o).limit(10).execute
    assert_equal 10, one.size

    one.all? do |r|
      assert_instance_of RDFS::Resource, r
    end

    two = Query.new.select(:s).where(:s,:p,:o).limit(10).offset(1).execute
    assert_equal 10, two.size
    assert_equal one[1], two[0]

    three = Query.new.select(:s).where(:s,:p,:o).limit(10).offset(0).execute
    assert_equal one, three
  end

  def test_regex_filter
    Namespace.register :yago, 'http://dbpedia.org/class/yago/'
    Namespace.register :dbpedia, 'http://dbpedia.org/property/'
    Namespace.register :dbresource, 'http://dbpedia.org/resource/'

    movies = Query.new.
      distinct(:title).
      where(DBRESOURCE::Kill_Bill, RDFS.label, :title).
      filter_regex(:title, /^Kill/).limit(10).execute

    assert !movies.empty?, "regex query returns empty results"
    assert movies.all? {|m| m =~ /^Kill/ }, "regex query returns wrong results"
  end

  def test_query_with_block
    reached_block = false
    Query.new.select(:s, :p).where(:s,:p,:o).limit(1).execute do |s, p|
      reached_block = true
      assert_equal RDFS::Resource, s.class
      assert_equal RDFS::Resource, p.class
    end
    assert reached_block, "querying with a block does not work"

    reached_block = false
    Query.new.select(:s, :p).where(:s,:p,:o).limit(3).execute do |s, p|
      reached_block = true
      assert_equal RDFS::Resource, s.class
      assert_equal RDFS::Resource, p.class
    end
    assert reached_block, "querying with a block does not work"

    reached_block = false
    Query.new.select(:s).where(:s,:p,:o).limit(3).execute do |s|
      reached_block = true
      assert_equal RDFS::Resource, s.class
    end

    assert reached_block, "querying with a block does not work"
  end

  def test_refuse_to_write
    eyal = RDFS::Resource.new 'http://activerdf.org/test/eyal'
    age = RDFS::Resource.new 'foaf:age'
    test = RDFS::Resource.new 'test'

    # NameError gets thown if the method is unknown
    assert_raises NoMethodError do
      @adapter.add(eyal, age, test)
    end
  end

  def test_literal_conversion
    # test literal conversion
    label = Query.new.distinct(:label).where(:s, RDFS::label, :label).limit(1).execute(:flatten)
    assert_instance_of String, label
  end
end
