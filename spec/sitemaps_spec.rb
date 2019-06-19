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
  describe '.parse' do
    subject(:sitemap) { Sitemaps.parse(raw_sitemap) }

    context 'when the sitemap is valid' do
      let(:raw_sitemap) { sitemap_file('sitemap.valid.xml') }

      it 'can parse the sitemap' do
        expect(sitemap).not_to be_nil
      end

      it 'can present a list of entries' do
        entries = [
          SE.new(URI.parse('http://www.example.com/'),
                 Time.parse('2005-01-01'),
                 :monthly,
                 0.8),
          SE.new(URI.parse('http://www.example.com/c?item=12&desc='), nil, :weekly, 0.5),
          SE.new(URI.parse('http://www.example.com/c?item=73&desc='),
                 Time.parse('2004-12-23'),
                 :weekly,
                 0.5),
          SE.new(URI.parse('http://www.example.com/c?item=74&desc='),
                 Time.parse('2004-12-23T18:00:15+00:00'),
                 nil,
                 0.3),
          SE.new(URI.parse('http://www.example.com/c?item=83&desc='),
                 Time.parse('2004-11-23'),
                 nil,
                 0.5)
        ]

        expect(sitemap.entries).to eql(entries)
      end
    end

    context 'when the sitemap is invalid' do
      let(:raw_sitemap) { sitemap_file('sitemap.invalid.xml') }

      it 'skips entries with a malformed or missing `loc`' do
        entries = [
          SE.new(URI.parse('http://www.example.com/'), Time.parse('2005-01-01'), :monthly, 0.8)
        ]

        # there are 3 entries defined in the file, but two have unparsable locations
        expect(sitemap.entries).to eql(entries)
      end
    end

    context 'when the sitemap is a sitemap index' do
      let(:raw_sitemap) { sitemap_file('sitemap_index.valid.xml') }

      it 'can parse the sitemap index' do
        expect(sitemap).not_to be_nil
      end

      it 'can present a list of entries' do
        entries = [
          SM.new(URI.parse('http://www.example.com/sitemap1.xml.gz'),
                 Time.parse('2004-10-01T18:23:17+00:00')),
          SM.new(URI.parse('http://www.example.com/sitemap2.xml.gz'),
                 Time.parse('2005-01-01'))
        ]

        expect(sitemap.sitemaps).to eql(entries)
      end
    end



    context 'when a sitemap contains whitespace around the elements' do
      let(:raw_sitemap) { sitemap_file('sitemap_with_whitespace.xml') }

      it 'can parse the sitemap' do
        entries = [SE.new(URI.parse('http://www.example.com/whitespace'),
                          Time.parse('2005-01-01'),
                          :monthly,
                          0.8)]

        expect(sitemap.entries).to eq entries
      end
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

    it "throws an exception when the incoming url is invalid" do
      expect do
        Sitemaps.fetch("blah blah blah")
      end.to raise_error URI::InvalidURIError
    end

    it "can fetch an xml sitemap from a url, using default options" do
      sitemap = Sitemaps.fetch("http://www.termscout.com/category-sitemap.xml")
      expect(sitemap.entries).to match_array(category_entries)
    end

    it "can fetch an xml sitemap from a url, using a custom fetch proc" do
      called = false
      fetch  = lambda do |uri|
        called = true
        Sitemaps::Fetcher.fetch(uri)
      end

      sitemap = Sitemaps.fetch("http://www.termscout.com/category-sitemap.xml", fetcher: fetch)
      expect(called).to be(true)
      expect(sitemap.entries).to match_array(category_entries)
    end

    it "can fetch a sitemap, and supports a max entry parameter" do
      sitemap = Sitemaps.fetch("http://www.digitalocean.com/sitemap.xml.gz", max_entries: 10)
      expect(sitemap.entries.length).to eq(10)
    end

    it "can fetch a sitemap, and supports a filter block" do
      sitemap = Sitemaps.fetch("http://www.digitalocean.com/sitemap.xml.gz") do |entry|
        entry.loc.path !~ /blog/
      end

      expect(sitemap.entries.length).to be > 0
      expect(sitemap.entries.any? { |e| e.loc.path =~ /blog/ }).to be false
    end

    it "can fetch a sitemap, and supports both a filter block and a max_entries parameter" do
      sitemap = Sitemaps.fetch("http://www.digitalocean.com/sitemap.xml.gz", max_entries: 10) do |entry|
        entry.loc.path !~ /blog/
      end

      expect(sitemap.entries.length).to eq(10)
      expect(sitemap.entries.any? { |e| e.loc.path =~ /blog/ }).to be false
    end

    it "can fetch a sitemap index recursively" do
      sitemap = Sitemaps.fetch("http://www.termscout.com/sitemap_index.xml")

      # we fetched the index
      expect(sitemap.sitemaps).to match_array(index_entries)

      # and also a bunch of individual sitemaps
      category_entries.each     { |e| expect(sitemap.entries).to include(e) }
      page_partial_entries.each { |e| expect(sitemap.entries).to include(e) }
    end

    it "can fetch a sitemap index recursively with filters" do
      sitemap = Sitemaps.fetch("http://www.termscout.com/sitemap_index.xml") do |entry|
        entry.loc.path =~ /blog/i
      end

      # we fetched the index
      expect(sitemap.sitemaps).to match_array(index_entries)

      # we limited to 10 total entries
      expect(sitemap.entries.length).to eq(1)
      expect(sitemap.entries.first.loc.path).to eq("/blog/")
    end

    it "can fetch a sitemap index recursively with max_entries and filters" do
      sitemap = Sitemaps.fetch("http://www.termscout.com/sitemap_index.xml", max_entries: 10) do |entry|
        entry.loc.path !~ /category/i
      end

      # we fetched the index
      expect(sitemap.sitemaps).to match_array(index_entries)

      # we limited to 10 total entries
      expect(sitemap.entries.length).to eq(10)

      # and none are the category urls
      category_entries.each { |e| expect(sitemap.entries).not_to include(e) }
    end
  end

  # URL level discovery specs
  describe '.discover', vcr: { record: :new_episodes } do
    subject(:discover) { Sitemaps.discover('www.example.com', max_entries: 10) }

    context 'when a sitemap is mentioned in a robots.txt' do
      let(:robots) { 'Sitemap: http://www.example.com/example_sitemap.xml' }

      before do
        stub_request(:get, 'http://www.example.com/robots.txt').
          to_return(status: [200, 'OK'],
                    body: robots,
                    headers: { content_type: 'text/plain' })
        stub_request(:get, 'http://www.example.com/example_sitemap.xml').
          to_return(body: sitemap_file('sitemap.valid.xml'))
      end

      it 'can find and fetch the sitemap' do
        expect(discover.entries.length).to eq(5)
      end

      context 'when the sitemap is followed by a comment' do
        let(:robots) do
          'Sitemap: http://www.example.com/example_sitemap.xml #sitemap'
        end

        it 'can find and fetch the sitemap' do
          expect(discover.entries.length).to eq(5)
        end
      end
    end

    context 'when no sitemap is mentioned in robots.txt' do
      before { stub_request(:get, %r{www.example.com}).to_return(status: 404) }

      it 'looks for sitemaps in a few common locations' do
        locations = %w[http://www.example.com/sitemap.xml
                       http://www.example.com/sitemap_index.xml
                       http://www.example.com/sitemap.xml.gz
                       http://www.example.com/sitemap_index.xml.gz]
        discover

        locations.each do |location|
          expect(a_request(:get, location)).to have_been_made
        end
      end
    end
  end
end
