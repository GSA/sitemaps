require 'active_support'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/object/blank'

require 'set'
require 'time'
require 'rexml/document'
require 'net/http'

require 'sitemaps/version'
require 'sitemaps/parser'
require 'sitemaps/fetcher'

# Discover, fetch and parse XML sitemaps as defined by the `http://sitemaps.org` spec.
module Sitemaps

  # @attr loc [URI] the location referred to by this entry. Will never be `nil`.
  # @attr lastmod [Time, nil] the last modification time of this entry, or `nil` if unspecified.
  # @attr changefreq [:always, :hourly, :daily, :weekly, :monthly, :yearly, :never, nil]
  #   the change frequency of this entry, or nil if unspecified.
  # @attr priority [Float] the priority of this entry, a float from 0 to 1. 0.5 if unspecified.
  Entry   = Struct.new(:loc, :lastmod, :changefreq, :priority)

  # @attr loc [URI] the location referred to by this entry. Will never be `nil`.
  # @attr lastmod [Time, nil] the last modification time of this entry, or `nil` if unspecified.
  Submap  = Struct.new(:loc, :lastmod)

  # @attr entries [Enumerable<Entry>] A set of entries that were parsed out of one or more sitemaps, recursively.
  # @attr sitemaps [Enumerable<Sitemap>] A set of sitemaps that were found in a sitemap index.
  Sitemap = Struct.new(:entries, :sitemaps)

  @default_fetcher = ->(u) { Sitemaps::Fetcher.fetch(u) }

  # Parse a sitemap from an XML string. Does not fail on invalid documents, but doesn't include
  # invalid entries in the final set. As such, a non-XML file, or non-sitemap XML file will return
  # an empty sitemap.
  #
  # @param source [String] an XML string to parse as a sitemap.
  # @return [Sitemap] the sitemap represented by the given XML string.
  def self.parse(source)
    Sitemaps::Parser.parse(source)
  end

  # Fetch and parse a sitemap from the given URL.
  #
  # @overload fetch(url, fetcher: nil, max_entries: nil)
  #   @param url [String, URI] the url of the sitemap in question.
  #   @param fetcher [#call] given a URI, fetch an HTTP document. Defaults to using `Fetcher`.
  #   @param max_entries [Integer] the maximum number of entries to include in the sitemap. Once the
  #     sitemap has this many entries, further fetches and parsing will not occur. This is always
  #     a good idea to include, as many sites have _very_ large sitemaps.
  #   @return [Sitemap]
  #
  # @overload fetch(url, fetcher: nil, filter_indexes: nil, max_entries: nil)
  #   If a block is given, it's used as a filter for entries before they're added to the sitemap.
  #
  #   @param url [String, URI] the url of the sitemap in question.
  #   @param fetcher [#call] given a URI, fetch an HTTP document. Defaults to using `Fetcher`.
  #   @param max_entries [Integer] the maximum number of entries to include in the sitemap. Once the
  #     sitemap has this many entries, further fetches and parsing will not occur. This is always
  #     a good idea to include, as many sites have _very_ large sitemaps.
  #   @param filter_indexes [Boolean] if true, Submap instances will be run through the filter block
  #     as well as Entry instances.
  #   @return [Sitemap]
  #   @yield [Entry] Filters the entry from the sitemap if the block returns falsey.
  #   @yieldreturn [Boolean] whether or not to include the entry in the sitemap.
  def self.fetch(url, fetcher: nil, max_entries: nil, filter_indexes: nil, &block)
    fetcher ||= @default_fetcher
    unless url.is_a? URI
      url = "http://#{url}" unless url =~ %r{^https?://}
      url = URI.parse(url)
    end

    _instance.fetch_recursive(url, fetcher, max_entries, filter_indexes, &block)
  end

  # Discover, fetch and parse sitemaps from the given host.
  #
  # Attempts to find and fetch sitemaps at a given host, by examining the `robots.txt` at that
  # host, or if no sitemaps are found via `robots.txt`, checking a small number of common locations,
  # including `sitemap.xml`, `sitemap_index.xml`, and the gzip versions of those same locations.
  #
  # @overload discover(host, fetcher: nil, max_entries: nil)
  #   @param host [String, URI] the url of the host to interrogate for sitemaps.
  #   @param fetcher [#call] given a URI, fetch an HTTP document. Defaults to using `Fetcher`.
  #   @param max_entries [Integer] the maximum number of entries to include in the sitemap. Once the
  #     sitemap has this many entries, further fetches and parsing will not occur. This is always
  #     a good idea to include, as many sites have _very_ large sitemaps.
  #   @return [Sitemap]
  #
  # @overload discover(host, fetcher: nil, max_entries: nil)
  #   If a block is given, it's used as a filter for entries before they're added to the sitemap.
  #
  #   @param host [String, URI] the url of the host to interrogate for sitemaps.
  #   @param fetcher [#call] given a URI, fetch an HTTP document. Defaults to using `Fetcher`.
  #   @param max_entries [Integer] the maximum number of entries to include in the sitemap. Once the
  #     sitemap has this many entries, further fetches and parsing will not occur. This is always
  #     a good idea to include, as many sites have _very_ large sitemaps.
  #   @param filter_indexes [Boolean] if true, Submap instances will be run through the filter block
  #     as well as Entry instances.
  #   @return [Sitemap]
  #   @yield [Entry] Filters the entry from the sitemap if the block returns falsey.
  #   @yieldreturn [Boolean] whether or not to include the entry in the sitemap.
  def self.discover(url, fetcher: nil, max_entries: nil, filter_indexes: nil, &block)
    fetcher ||= @default_fetcher
    unless url.is_a? URI
      url = "http://#{url}" unless url =~ %r{^https?://}
      url = URI.parse(url)
    end

    roots = _instance.discover_roots(url, fetcher)
    _instance.fetch_recursive(roots, fetcher, max_entries, filter_indexes, &block)
  end

  # @return [Instance]
  # @private
  # @api private
  def self._instance
    @instance ||= Sitemaps::Instance.new
  end

  # Holder for methods that shouldn't be exposed as public API
  # @private
  # @api private
  class Instance
    # recursively fetch sitemaps and sitemap indexes from the given urls.
    # @return [Sitemap]
    def fetch_recursive(urls, fetcher, max_entries, filter_indexes, &block)
      queue = urls.is_a?(Array) ? urls : [urls]
      maps  = {}

      # walk the queue, fetching the sitemap requested and adding
      # new sitemaps to the queue as found
      loop do
        begin
          url = queue.pop
          break if url.nil?
          next  unless maps[url].nil?

          # fetch this item in the queue, and queue up any sub maps it found
          source  = fetcher.call(url)
          sitemap = Sitemaps::Parser.parse(source, max_entries: max_entries, filter: block, filter_indexes: filter_indexes)

          # save the results and queue up any submaps it found
          maps[url] = sitemap
          queue.push(*sitemap.sitemaps.map(&:loc))

          # decrement max_entries (since it's max_entries total, not per map)
          unless max_entries.nil?
            max_entries -= maps[url].entries.length
            break if max_entries <= 0
          end
        rescue => ex
          # otherwise keep on going, because we've got something at least
          $stderr.puts "ERROR FETCHING: #{url}, #{ex.message}, ignoring..."
          next
        end
      end

      # collapse the recovered maps into a single one with everything
      maps.each_with_object(Sitemap.new([], [])) do |(_, map), result|
        result.sitemaps.concat(map.sitemaps).uniq! { |e| e.loc.to_s }
        result.entries.concat(map.entries).uniq!   { |e| e.loc.to_s }
      end
    end

    # interrogate a host for sitemaps from robots.txt, or return some potential locations.
    # @return [Array<URI>]
    def discover_roots(url, fetcher)
      robots = begin
        robotsurl      = url.clone
        robotsurl.path = '/robots.txt'
        robotstxt      = fetcher.call(robotsurl)

        discovered = robotstxt.scan(/^Sitemap: (\S+)/).flatten.map do |url|
          URI.parse(url.strip)
        end
        discovered.presence
      rescue
        nil
      end

      # try for files in a handful of known locations
      known_locations = %w(/sitemap_index.xml.gz /sitemap_index.xml /sitemap.xml.gz /sitemap.xml)
      known_locations = known_locations.lazy.map do |path|
        pathurl      = url.clone
        pathurl.path = path
        pathurl
      end

      robots || known_locations.to_a
    end
  end
end
