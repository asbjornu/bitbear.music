# frozen_string_literal: true

require 'uri'

module Jekyll
  # Filters for extracting a YouTube video ID from any of the URL shapes
  # YouTube supports (watch, embed, shorts, live, and youtu.be short links).
  module YoutubeFilters
    def youtube_id(input)
      uri = URI.parse(link_url(input))
      youtube_id_from_uri(uri)
    rescue URI::InvalidURIError, URI::InvalidComponentError
      link_url(input)[/\A[\w-]{11}\z/]
    end

    private

    def youtube_id_from_uri(uri)
      youtube_id_from_query(uri) || youtube_id_from_path(uri) || uri.to_s[/\A[\w-]{11}\z/]
    end

    def youtube_id_from_query(uri)
      uri.query.to_s[/(?:^|[?&])v=([\w-]{11})/, 1]
    end

    def youtube_id_from_path(uri)
      path = uri.path.to_s
      match = path[%r{\A/(?:embed|shorts|live)/([\w-]{11})}, 1]
      return match if match

      path[%r{\A/([\w-]{11})}, 1] if uri.host.to_s.include?('youtu.be')
    end
  end
end

Liquid::Template.register_filter Jekyll::YoutubeFilters
