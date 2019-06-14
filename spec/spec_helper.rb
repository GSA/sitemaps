$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'sitemaps'
require 'webmock/rspec'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = File.join(File.dirname(__FILE__), './fixtures/vcr')
  c.hook_into :webmock
  c.configure_rspec_metadata!
end

RSpec.configure do |c|
end

# helpers for accessing local file fixtures
module SitemapFixtures
  def sitemap_file(filename)
    path = File.join(File.dirname(__FILE__), "./fixtures/#{filename}")
    File.read(path).freeze
  end
end
