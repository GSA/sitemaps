# Sitemaps

[![Gem](https://img.shields.io/gem/v/sitemaps_parser.svg?style=flat-square)](https://rubygems.org/gems/sitemaps_parser)
[![CircleCI](https://circleci.com/gh/GSA/sitemaps.svg?style=svg)](https://circleci.com/gh/GSA/sitemaps)

Discover, retrieve and parse XML sitemaps, according to the spec at [sitemaps.org](http://sitemaps.org).

See [RDOC Documentation](https://gsa.github.io/sitemaps) for detailed documentation.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sitemaps_parser', require: 'sitemaps'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sitemaps_parser

## Usage

```ruby
require 'sitemaps'

# parse a sitemap from a string
Sitemaps.parse("<xml ns=\"...")

# fetch and parse a sitemap from a known url
sitemap = Sitemaps.fetch("http://termscout.com/sitemap.xml")

# fetch and parse sitemaps, excluding paths matching a filter, and limiting to the top 200 
sitemap = Sitemaps.fetch("https://www.digitalocean.com/sitemaps.xml.gz", max_entries: 200) do |entry|
  entry.loc.path !~ /blog/i
end

# attempt to discover sitemaps for a site without a known sitemap location. Checks robots.txt and some common locations.
sitemap = Sitemaps.discover("https://www.digitalocean.com", max_entries: 200) do |entry|
  entry.loc.path !~ /blog/i
end

# sitemap usage
sitemap.entries.first #> Sitemaps::Entry(loc: 'http://example.com/page', lastmod: DateTime.utc, changefreq: :monthly, priority: 0.5)
urls = sitemap.entries.map(&:loc)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/GSA/sitemaps. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
