require 'spec_helper'

describe Sitemaps do
  include SitemapFixtures

  # aliases
  SE = Sitemaps::Entry
  SM = Sitemaps::Submap

  # gem level specs
  it 'has a version number' do
    expect(Sitemaps::VERSION).not_to be nil
  end

  # document level parser specs
  context "parser" do
    it "can parse a valid sitemap" do
      sitemap = sitemap_fixture
      expect(sitemap).not_to be_nil
    end

    it "can present a list of entries" do
      entries = [
        SE.new(URI.parse("http://www.example.com/"), Time.parse("2005-01-01"), :monthly, 0.8),
        SE.new(URI.parse("http://www.example.com/c?item=12&desc="), nil, :weekly, 0.5),
        SE.new(URI.parse("http://www.example.com/c?item=73&desc="), Time.parse("2004-12-23"), :weekly, 0.5),
        SE.new(URI.parse("http://www.example.com/c?item=74&desc="), Time.parse("2004-12-23T18:00:15+00:00"), nil, 0.3),
        SE.new(URI.parse("http://www.example.com/c?item=83&desc="), Time.parse("2004-11-23"), nil, 0.5)
      ]

      expect(sitemap_fixture.entries).to eql(entries)
    end

    it "skips entries with a malformed or missing `loc`" do
      entries = [
        SE.new(URI.parse("http://www.example.com/"), Time.parse("2005-01-01"), :monthly, 0.8)
      ]

      # there are 3 entries defined in the file, but two have unparsable locations
      expect(invalid_fixture.entries).to eql(entries)
    end

    it "can parse a valid sitemap index" do
      sitemap = sitemap_index_fixture
      expect(sitemap).not_to be_nil
    end

    it "can present a list of entries" do
      entries = [
        SM.new(URI.parse("http://www.example.com/sitemap1.xml.gz"), Time.parse("2004-10-01T18:23:17+00:00")),
        SM.new(URI.parse("http://www.example.com/sitemap2.xml.gz"), Time.parse("2005-01-01"))
      ]

      expect(sitemap_index_fixture.sitemaps).to eql(entries)
    end
  end

  # URL level fetching specs
  context "fetching", vcr: { record: :new_episodes } do
    let :category_entries do
      [SE.new(URI.parse("http://www.termscout.com/category/business/"),      Time.parse("2015-04-03T21:17:05-06:00"), :weekly, 0.2),
       SE.new(URI.parse("http://www.termscout.com/category/intelligence/"),  Time.parse("2015-04-03T21:19:25-06:00"), :weekly, 0.2),
       SE.new(URI.parse("http://www.termscout.com/category/sales-tips/"),    Time.parse("2015-04-03T21:18:27-06:00"), :weekly, 0.2),
       SE.new(URI.parse("http://www.termscout.com/category/uncategorized/"), Time.parse("2015-05-01T09:13:11-06:00"), :weekly, 0.2)]
    end

    let :page_partial_entries do
      [SE.new(URI.parse("http://www.termscout.com/company-overview/"), Time.parse("2015-09-23T12:08:06-06:00"), :weekly, 0.8),
       SE.new(URI.parse("http://www.termscout.com/team/"),             Time.parse("2016-02-11T17:22:30-07:00"), :weekly, 0.8),
       SE.new(URI.parse("http://www.termscout.com/careers/"),          Time.parse("2015-12-04T13:09:39-07:00"), :weekly, 0.8),
       SE.new(URI.parse("http://www.termscout.com/schedule-demo/"),    Time.parse("2015-07-28T13:36:28-06:00"), :weekly, 0.8)]
    end

    let :index_entries do
      [SM.new(URI.parse("http://www.termscout.com/post-sitemap.xml"),     Time.parse("2015-05-01T09:13:11-06:00")),
       SM.new(URI.parse("http://www.termscout.com/page-sitemap.xml"),     Time.parse("2016-03-07T16:21:48-07:00")),
       SM.new(URI.parse("http://www.termscout.com/product-sitemap.xml"),  Time.parse("2015-07-13T16:33:24-06:00")),
       SM.new(URI.parse("http://www.termscout.com/industry-sitemap.xml"), Time.parse("2015-07-02T10:50:41-06:00")),
       SM.new(URI.parse("http://www.termscout.com/category-sitemap.xml"), Time.parse("2015-05-01T09:13:11-06:00"))]
    end

    it "can fetch an xml sitemap from a url, using default options" do
      sitemap = Sitemaps.fetch("http://www.termscout.com/category-sitemap.xml")
      expect(sitemap.entries).to match_array(category_entries)
    end

    it "can fetch an xml sitemap from a url, using a custom fetch proc" do
      called = false
      fetch  = lambda do |uri|
        called = true
        Net::HTTP.get(uri)
      end

      sitemap = Sitemaps.fetch("http://www.termscout.com/category-sitemap.xml", fetch: fetch)
      expect(called).to be(true)
      expect(sitemap.entries).to match_array(category_entries)
    end

    it "can fetch a sitemap index (sitemap indexes, see sitemaps.org)" do
      sitemap = Sitemaps.fetch("http://www.termscout.com/sitemap_index.xml", recurse: false)

      # we fetched the index
      expect(sitemap.sitemaps).to match_array(index_entries)
      expect(sitemap.entries).to be_empty
    end

    it "can fetch a sitemap index recursively" do
      sitemap = Sitemaps.fetch("http://www.termscout.com/sitemap_index.xml", recurse: true)

      # we fetched the index
      expect(sitemap.sitemaps).to match_array(index_entries)

      # and also a bunch of individual sitemaps
      category_entries.each     { |e| expect(sitemap.entries).to include(e) }
      page_partial_entries.each { |e| expect(sitemap.entries).to include(e) }
    end
  end

  # URL level discovery specs
  context "discover" do
    xit "can find and fetch a sitemap from a domain" do
      Sitemaps.discover("http://example.com") #=> xml content
    end

    xit "returns nil if no sitemap could be found" do
      Sitemaps.discover("http://exampleno.com") #=> nil
    end
  end
end
