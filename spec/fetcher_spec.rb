require 'spec_helper'

describe Sitemaps::Fetcher, vcr: { record: :new_episodes } do
  subject(:fetch) { Sitemaps::Fetcher.fetch(uri) }

  let(:uri) { URI('http://www.example.com') }

  context 'when the request is successful' do
    before do
      stub_request(:get, 'http://www.example.com').
        to_return(status: 200, body: 'response body')
    end

    it 'returns the response body' do
      expect(fetch).to eq 'response body'
    end

    it 'can take a string as an argument' do
      expect(Sitemaps::Fetcher.fetch('www.example.com')).to eq 'response body'
    end
  end

  it "can download a file" do
    uri    = URI.parse("http://httpbin.org/")
    source = Sitemaps::Fetcher.fetch(uri)

    expect(source).not_to be_nil
    expect(source.length).to be > 0
  end

  it "handles a 4xx error by raising" do
    uri = URI.parse("http://httpbin.org/status/405")
    expect do
      Sitemaps::Fetcher.fetch(uri)
    end.to raise_error Sitemaps::Fetcher::FetchError
  end

  it "handles absolute redirects" do
    uri    = URI.parse("http://httpbin.org/absolute-redirect/1")
    source = Sitemaps::Fetcher.fetch(uri)

    expect(source).not_to be_nil
    expect(source.length).to be > 0
  end

  it "handles relative redirects" do
    uri    = URI.parse("http://httpbin.org/relative-redirect/1")
    source = Sitemaps::Fetcher.fetch(uri)

    expect(source).not_to be_nil
    expect(source.length).to be > 0
  end

  it "handles too many redirects by raising" do
    uri = URI.parse("http://httpbin.org/relative-redirect/11")
    expect do
      Sitemaps::Fetcher.fetch(uri)
    end.to raise_error Sitemaps::Fetcher::MaxRedirectError
  end

  context "gzip encoding" do
    it "can fetch a resource that's gzip encoded according to the url, even if the server doesn't return a Content-Encoding header" do
      uri    = URI.parse("https://www.digitalocean.com/sitemap.xml.gz")
      source = Sitemaps::Fetcher.fetch(uri)
      expect(source).to match(/\?xml version/)
    end

    it "can fetch a resource that the server claims is gziped" do
      uri    = URI.parse("https://httpbin.org/gzip")
      source = Sitemaps::Fetcher.fetch(uri)
      expect(source).to match(/"gzipped": true/)
    end
  end
end
