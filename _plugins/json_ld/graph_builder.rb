# frozen_string_literal: true

require_relative 'album_entry'
require_relative 'music_group'
require_relative 'music_recording'
require_relative 'music_album'

module Jekyll
  module JsonLd
    # Assembles the full JSON-LD @graph array for a page: the site-wide
    # MusicGroup entity plus, depending on the page's front matter, a
    # MusicRecording or MusicAlbum entity.
    class GraphBuilder
      def initialize(site, page, context)
        @site = site
        @page = page
        @context = context
      end

      def graph
        entities = [MusicGroup.for(@site)]
        entities << MusicRecording.new(@site, @page, @context).to_h if track_page?
        entities << MusicAlbum.new(@site, @page, @context).to_h if album_page?
        entities
      end

      private

      def track_page?
        @page['media'] && !album_page?
      end

      def album_page?
        AlbumEntry.for?(@page)
      end
    end
  end
end
