# frozen_string_literal: true

require 'uri'
require 'yaml'

module Jekyll
  # Filters for working with `links` front matter entries: identifying which
  # brand/service a link belongs to, and deriving the right URL to show for
  # it in different contexts.
  module LinkFilters
    LINK_BRAND_PATTERNS = {
      /bandcamp\.com/i => 'bandcamp',
      /soundcloud\.com/i => 'soundcloud',
      /music\.apple\.com/i => 'apple-music',
      /open\.spotify\.com/i => 'spotify',
      /listen\.tidal\.com/i => 'tidal',
      /music\.amazon\.com/i => 'amazon-music',
      /(?:www\.)?deezer\.com/i => 'deezer',
      /(?:www\.)?pandora\.com/i => 'pandora',
      /mirlo\.space/i => 'mirlo',
      /demozoo\.org/i => 'demozoo',
      /youtube\.com|youtu\.be/i => 'youtube',
      /modarchive\.org/i => 'modarchive',
      /amp\.dascene\.net/i => 'amp',
      /scenestream\.net/i => 'nectarine'
    }.freeze

    def link_url(input)
      input.is_a?(Hash) ? input.values.first.to_s : input.to_s
    end

    def link_brand(input)
      url = link_url(input)
      _pattern, brand = LINK_BRAND_PATTERNS.find { |pattern, _brand| pattern.match?(url) }
      brand || 'unknown'
    end

    def link_by_brand(input, brand)
      Array(input).find { |item| link_brand(item) == brand }
    end

    # Some services (e.g. ModArchive, AMP) only store a direct-download URL in
    # `links`, but linking to that URL from anywhere other than the dedicated
    # Download button should instead point at the service's HTML page for the
    # module. This maps a stored link to that page URL, falling back to the
    # original URL for brands with no such distinction.
    def link_page_url(input)
      url = link_url(input)
      case link_brand(input)
      when 'modarchive'
        moduleid = URI.parse(url).query.to_s[/(?:^|&)moduleid=(\d+)/, 1]
        moduleid ? "https://modarchive.org/index.php?request=view_by_moduleid&query=#{moduleid}" : url
      when 'amp'
        index = URI.parse(url).query.to_s[/(?:^|&)index=(\d+)/, 1]
        index ? "https://amp.dascene.net/analyzer2.php?idx=#{index}" : url
      else
        url
      end
    rescue URI::InvalidURIError, URI::InvalidComponentError
      url
    end

    def link_host(input)
      uri = URI.parse(link_url(input))
      host = uri.host.to_s.sub(/\Awww\./i, '')
      host = "#{host}:#{uri.port}" if uri.port && ![80, 443].include?(uri.port)
      host
    rescue URI::InvalidURIError, URI::InvalidComponentError
      link_url(input)
    end

    # Cached, on-disk map of unknown-link URL => the remote page's <title>,
    # populated by `rake fetch-link-titles` (see lib/link_title_fetcher.rb) and
    # committed to the repo. Loaded lazily and memoized so builds stay offline
    # and deterministic; only the manual fetch task ever touches the network.
    LINK_TITLES_PATH = File.expand_path('_data/link_titles.yml', Dir.pwd)
    LEFT_DOUBLE_QUOTE = "\u201C"
    RIGHT_DOUBLE_QUOTE = "\u201D"

    def link_titles
      return @link_titles if defined?(@link_titles_loaded) && @link_titles_loaded

      @link_titles = if File.exist?(LINK_TITLES_PATH)
                       YAML.safe_load_file(LINK_TITLES_PATH) || {}
                     else
                       {}
                     end
      @link_titles_loaded = true
      @link_titles
    end

    # Description for an unknown-brand link: the remote page title wrapped in
    # smart quotes, followed by the host ("<title>" at host), falling back to
    # just the host when no cached title is available.
    def link_title(input)
      url = link_url(input)
      cached = link_titles[url]
      if cached.to_s.strip.empty?
        link_host(input)
      else
        "#{LEFT_DOUBLE_QUOTE}#{cached.strip}#{RIGHT_DOUBLE_QUOTE} at #{link_host(input)}"
      end
    end

    # Describes a tracker module format abbreviation, reusing the same
    # tracker software names introduced in music/legacy/index.md ("tracker
    # modules in software such as ProTracker, Scream Tracker, Fast Tracker
    # II, and Impulse Tracker").
    def format_description(format)
      case format.to_s.upcase
      when 'MOD'  then 'ProTracker module'
      when 'S3M'  then 'Scream Tracker 3 module'
      when 'FST'  then 'Fast Tracker module'
      when 'XM'   then 'Fast Tracker II module'
      when 'IT'   then 'Impulse Tracker module'
      when 'XRNS' then 'Renoise song'
      else format.to_s
      end
    end
  end
end

Liquid::Template.register_filter Jekyll::LinkFilters
