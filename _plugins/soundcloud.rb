# frozen_string_literal: false

require 'nokogiri'
require 'open-uri'

SOUNDCLOUD_BASE_URL = 'https://soundcloud.com'.freeze

module Jekyll
  # Implements the 'soundcloud' Liquid tag.
  class SoundCloudTag < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      super

      # rubocop:disable Style/ClassVars
      @@cache ||= Jekyll::Cache.new(self.class.name)
      # rubocop:enable Style/ClassVars

      @tracks = parse_tracks
    end

    def render(_context)
      html = ''

      Jekyll.logger.error 'Empty list of tracks fetched from SoundCloud.' if @tracks.empty?

      @tracks.each do |track|
        params = build_params(track)
        src = "https://w.soundcloud.com/player/?#{params}"
        html << "<article itemprop='track' itemscope itemtype='http://schema.org/MusicRecording'>"
        html << "<h3 itemprop='name'><a itemprop='url' href='#{track[:url]}'>#{track[:name]}</a></h3>"
        html << "<iframe src='#{src}' width='100%' height='100' scrolling='no' frameborder='no'></iframe>"
        html << '</article>'
      end

      html
    end

    private

    def fetch_tracks
      tracks_uri = URI.join(SOUNDCLOUD_BASE_URL, '/bitbear/tracks')
      tracks_source = tracks_uri.open
      @@cache['tracks'] = tracks_source
    rescue OpenURI::HTTPError => e
      Jekyll.logger.error "Error fetching #{tracks_uri}", e

      return @@cache['tracks'] if @@cache.key?('tracks')

      Jekyll.logger.error 'No cached tracks could be found.', e

      nil
    end

    def parse_tracks
      tracks_source = fetch_tracks
      if tracks_source.nil?
        Jekyll.logger.error 'Empty list of tracks fetched from SoundCloud.'
        return []
      end

      tracks_doc = Nokogiri::HTML(tracks_source)
      tracks_doc.css('section > article > h2 > a:first-of-type').map(&:track)
    end

    def build_params(track)
      track_id = track[:id]
      params = {
        url: "https://api.soundcloud.com/tracks/#{track_id}",
        color: '#ff5500',
        auto_play: false,
        hide_related: false,
        show_comments: true,
        show_user: true,
        show_reposts: false,
        show_teaser: true,
        visual: true
      }

      URI.encode_www_form(params)
    end
  end
end

module Nokogiri
  module XML
    # Nokogiri's Element class, extended with a few SoundCloud-specific methods.
    class Element
      def track_id
        ios_app_regex = /sounds:(\d+)/
        ios_link_href = self['href']
        match = ios_app_regex.match(ios_link_href)
        match.captures.first
      end

      def track
        track_name = content
        track_href = self['href']
        track_uri = URI.join(SOUNDCLOUD_BASE_URL, track_href)
        track_source = track_uri.open
        track_doc = Nokogiri::HTML(track_source)
        track_id = track_doc.css('link[href^="ios-app://"]').map(&:track_id).first

        {
          id: track_id,
          name: track_name,
          url: track_uri
        }
      end
    end
  end
end

Liquid::Template.register_tag('soundcloud', Jekyll::SoundCloudTag)
