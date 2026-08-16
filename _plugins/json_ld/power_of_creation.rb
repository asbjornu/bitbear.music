# frozen_string_literal: true

require_relative 'entity_helpers'
require_relative 'album_entry'
require_relative 'music_group'

module Jekyll
  module JsonLd
    # Builds a schema.org MusicGroup Hash describing "Power of Creation",
    # Bitbear's 1990s demoscene alter ego, for its dedicated page (layout:
    # power-of-creation). It's modeled as its own MusicGroup entity - active
    # 1995-2000, `sameAs` the site-wide Bitbear MusicGroup - rather than as
    # a property tacked onto the modern Bitbear entity, since it was a
    # distinctly named act with its own logo, releases, and active period.
    class PowerOfCreation
      include EntityHelpers

      SAME_AS = [
        'https://bitbear.music',
        'https://power-of-creation.bandcamp.com/',
        'https://demozoo.org/sceners/30400/',
        'https://demozoo.org/groups/23250/',
        'https://demozoo.org/groups/106371/'
      ].freeze

      def initialize(site, page, context)
        @site = site
        @page = page
        @context = context
      end

      def to_h
        {
          '@type' => 'MusicGroup',
          'name' => @page['title'],
          'alternateName' => 'PoC',
          'description' => description,
          'url' => absolute_url(@page['url']),
          'logo' => {
            '@type' => 'ImageObject',
            'url' => absolute_url('/assets/images/power-of-creation.svg')
          },
          'foundingDate' => '1995',
          'dissolutionDate' => '2000',
          'genre' => genres,
          'album' => albums,
          'member' => MusicGroup::STATIC['member'],
          'sameAs' => SAME_AS
        }
      end

      private

      def description
        @page['description'].to_s.gsub(/\s+/, ' ').strip
      end

      def legacy_posts
        @legacy_posts ||= @site.posts.docs.select { |doc| doc.data['categories']&.include?('legacy') }
      end

      def genres
        legacy_posts.flat_map { |doc| doc.data['tags'] || [] }.uniq.sort
      end

      def albums
        legacy_posts.select { |doc| AlbumEntry.for?(doc.data) }
                    .sort_by { |doc| doc.data['date'] }
                    .map { |doc| album_reference(doc) }
      end

      def album_reference(doc)
        {
          '@type' => 'MusicAlbum',
          'name' => doc.data['title'],
          'url' => absolute_url(doc.url)
        }
      end
    end
  end
end
