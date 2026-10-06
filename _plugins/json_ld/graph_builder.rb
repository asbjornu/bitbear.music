# frozen_string_literal: true

require_relative 'album_entry'
require_relative 'music_group'
require_relative 'music_recording'
require_relative 'music_album'
require_relative 'power_of_creation'
require_relative 'puma'

module Jekyll
  module JsonLd
    # Assembles the full JSON-LD @graph array for a page: the site-wide
    # MusicGroup entity plus, depending on the page's front matter, a
    # MusicRecording or MusicAlbum entity, a MusicGroup entity for the
    # dedicated Power of Creation page, or a Person entity for the dedicated
    # Puma page.
    class GraphBuilder
      def initialize(site, page, context)
        @site = site
        @page = page
        @context = context
      end

      def graph
        [MusicGroup.for(@site), *page_entities]
      end

      private

      def page_entities
        [
          entity(MusicRecording, track_page?),
          entity(MusicAlbum, album_page?),
          entity(PowerOfCreation, power_of_creation_page?),
          entity(Puma, puma_page?)
        ].compact
      end

      def entity(klass, present)
        klass.new(@site, @page, @context).to_h if present
      end

      def track_page?
        @page['media'] && !album_page?
      end

      def album_page?
        AlbumEntry.for?(@page)
      end

      def power_of_creation_page?
        @page['layout'] == 'power-of-creation'
      end

      def puma_page?
        @page['layout'] == 'puma'
      end
    end
  end
end
