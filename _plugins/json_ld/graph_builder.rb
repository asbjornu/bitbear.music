# frozen_string_literal: true

require_relative 'album_entry'
require_relative 'music_group'
require_relative 'music_recording'
require_relative 'music_album'
require_relative 'power_of_creation'

module Jekyll
  module JsonLd
    # Assembles the full JSON-LD @graph array for a page: the site-wide
    # MusicGroup entity plus, depending on the page's front matter, a
    # MusicRecording or MusicAlbum entity, or - for the dedicated Power of
    # Creation page - a MusicGroup entity describing that alter ego.
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
        entities << PowerOfCreation.new(@site, @page, @context).to_h if power_of_creation_page?
        entities
      end

      private

      def track_page?
        @page['media'] && !album_page?
      end

      def album_page?
        AlbumEntry.for?(@page)
      end

      def power_of_creation_page?
        @page['layout'] == 'power-of-creation'
      end
    end
  end
end
