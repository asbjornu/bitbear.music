# frozen_string_literal: true

require_relative 'entity_helpers'

module Jekyll
  module JsonLd
    # Builds a schema.org Person Hash describing "Puma", the Norwegian
    # demoscene musician and early Bitbear collaborator, for his profile
    # page (layout: puma). Unlike Power of Creation - a named act modeled as
    # a MusicGroup - Puma is a person with several production aliases and
    # group memberships, so those are modeled as `alternateName` and
    # `memberOf` on a Person entity.
    class Puma
      include EntityHelpers

      ALTERNATE_NAMES = %w[Fulgore CHiMERA Ordeux Uranus adMiXTURE].freeze

      GROUPS = [
        { '@type' => 'Organization', 'name' => 'Dupe', 'url' => 'https://demozoo.org/groups/23250/' },
        { '@type' => 'Organization', 'name' => 'Digiton', 'url' => 'https://demozoo.org/groups/135824/' },
        { '@type' => 'Organization', 'name' => 'ULTiMATE', 'url' => 'https://demozoo.org/groups/106371/' },
        { '@type' => 'Organization', 'name' => 'XeNoBlast', 'url' => 'https://demozoo.org/groups/106370/' }
      ].freeze

      SAME_AS = [
        'https://demozoo.org/sceners/106369/',
        'https://open.spotify.com/artist/4dwnpqWrbPkERMO7CxH4xk'
      ].freeze

      def initialize(site, page, context)
        @site = site
        @page = page
        @context = context
      end

      def to_h
        {
          '@type' => 'Person',
          'name' => @page['title'],
          'alternateName' => ALTERNATE_NAMES,
          'description' => description,
          'url' => absolute_url(@page['url']),
          'homeLocation' => {
            '@type' => 'PostalAddress',
            'addressLocality' => 'Oslo',
            'addressCountry' => 'NO'
          },
          'memberOf' => GROUPS,
          'sameAs' => SAME_AS
        }
      end

      private

      def description
        @page['description'].to_s.gsub(/\s+/, ' ').strip
      end
    end
  end
end
