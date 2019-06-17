$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'webmock/rspec'
require 'vcr'
require 'byebug'
require 'simplecov'

SimpleCov.minimum_coverage 100
SimpleCov.start do
  add_filter '/spec/'
end

# Must be required after SimpleCov is started
require 'sitemaps'

VCR.configure do |c|
  c.cassette_library_dir = File.join(File.dirname(__FILE__), './fixtures/vcr')
  c.hook_into :webmock
  c.configure_rspec_metadata!
end

RSpec.configure do |c|
end

# helpers for accessing local file fixtures
module SitemapFixtures
  def sitemap_file
    @sitemap_file ||= begin
      path = File.join(File.dirname(__FILE__), "./fixtures/sitemap.valid.xml")
      File.read(path).freeze
    end
  end

  def sitemap_fixture
    @sitemap_fixture ||= Sitemaps.parse(sitemap_file)
  end

  def invalid_file
    @invalid_file ||= begin
      path = File.join(File.dirname(__FILE__), "./fixtures/sitemap.invalid.xml")
      File.read(path).freeze
    end
  end

  def invalid_fixture
    @invalid_fixture ||= Sitemaps.parse(invalid_file)
  end

  def sitemap_index_file
    @sitemap_file ||= begin
      path = File.join(File.dirname(__FILE__), "./fixtures/sitemap_index.valid.xml")
      File.read(path).freeze
    end
  end

  def sitemap_index_fixture
    @sitemap_index_fixture ||= Sitemaps.parse(sitemap_index_file)
  end
end
