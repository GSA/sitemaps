module Sitemaps
  # Parse XML Sitemaps
  module Parser
    VALID_CHANGEFREQ = %w(always hourly daily weekly monthly yearly never).freeze

    # Given a source string, returns a sitemap containing all valid url entries, or all valid sub-sitemaps.
    # See `http://sitemaps.org` for information on the spec.
    #
    # @param source [String] an XML string to parse.
    # @param max_entries [Integer, nil] the maximum number of entries to add to the sitemap.
    # @param filter [#call, nil] if provided, called per entry to filter the entry out of the sitemap.
    # @param filter_indexes [Boolean, nil] if truthy, filter is called per submap as well as entries.
    # @return [Sitemap] the sitemap parsed from the XML string. If the XML string given is invalid,
    #   a sitemap will still be returned, but the entries and sitemaps keys will be empty.
    def self.parse(source, max_entries: nil, filter: nil, filter_indexes: nil)
      document = REXML::Document.new(source)
      entries  = document.elements.to_a("/urlset/url").map do |root|
        loc  = parse_loc(root) || next
        mod  = parse_lastmod(root)
        freq = parse_changefreq(root)
        pri  = parse_priority(root)

        entry = Sitemaps::Entry.new(loc, mod, freq, pri)
        (!filter || filter.call(entry)) ? entry : nil
      end.reject(&:nil?)
      entries = entries.uniq(&:loc)
      entries = entries.take(max_entries) unless max_entries.nil?

      sitemaps = document.elements.to_a("/sitemapindex/sitemap").map do |root|
        loc  = parse_loc(root) || next
        mod  = parse_lastmod(root)

        submap = Sitemaps::Submap.new(loc, mod)
        (!filter || !filter_indexes || filter.call(submap)) ? submap : nil
      end.reject(&:nil?)

      Sitemaps::Sitemap.new(entries, sitemaps)
    end

    # @api private
    # @private
    def self.parse_loc(root)
      loc = get_text(root, 'loc')
      loc && URI.parse(loc) rescue nil
    end

    # @api private
    # @private
    def self.parse_lastmod(root)
      mod = get_text(root, 'lastmod')
      mod && Time.parse(mod) rescue nil
    end

    # @api private
    # @private
    def self.parse_changefreq(root)
      freq = get_text(root, 'changefreq')
      freq && VALID_CHANGEFREQ.include?(freq) ? freq.to_sym : nil
    end

    # @api private
    # @private
    def self.parse_priority(root)
      priority = get_text(root, 'priority') || '0.5'
      priority && Float(priority) rescue 0.5 # default priority according to spec
    end

    def self.get_text(root, key)
      root.get_text(key)&.value&.strip
    end
  end
end
