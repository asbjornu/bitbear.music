# frozen_string_literal: true

module Jekyll
  module JsonLd
    # The site-wide schema.org MusicGroup entity describing the artist. Most
    # of it is identical on every page and so is a frozen constant, but
    # `genre` is computed from the union of every track's `tags` front
    # matter, the same source of truth used for the /music/genres/ pages,
    # and `sameAs` is computed from `site.data.social_links` (the same data
    # backing the rel="me" links in the "Harass" section of index.md) plus a
    # few additional profiles that aren't rendered there.
    module MusicGroup
      # Profiles that are valid `sameAs` targets but aren't rendered as
      # rel="me" links on the homepage (e.g. because they predate the
      # current Bitbear alias, or are secondary/mirror accounts).
      EXTRA_SAME_AS = [
        'https://www.mixcloud.com/bitbearmusic/',
        'https://urort.p3.no/artist/Bitbear',
        'https://mastodon.social/@bitbear',
        'https://modarchive.org/index.php?request=view_profile&query=84875'
      ].freeze

      STATIC = {
        '@type' => 'MusicGroup',
        '@id' => 'https://bitbear.music',
        'name' => 'Bitbear',
        'description' => "Bitbear is Asbjørn Ulsberg's tone-hammering, beat-juggling and " \
                         'demoscene-participating alter ego.',
        'logo' => {
          '@type' => 'ImageObject',
          'url' => 'https://bitbear.music/assets/images/logo.svg'
        },
        'url' => 'https://bitbear.music',
        'member' => [
          {
            '@type' => 'OrganizationRole',
            'member' => {
              '@type' => 'Person',
              'name' => 'Artist',
              'givenName' => 'Asbjørn Ulsberg',
              'sameAs' => [
                'https://asbjor.nu/',
                'https://twitter.com/asbjornu',
                'https://www.last.fm/user/asbjornu'
              ]
            },
            'roleName' => ['producer']
          }
        ]
      }.freeze

      def self.for(site)
        STATIC.merge('genre' => genres(site), 'sameAs' => same_as(site))
      end

      def self.genres(site)
        site.posts.docs.flat_map { |doc| doc.data['tags'] || [] }.uniq.sort
      end

      def self.same_as(site)
        rel_me = Array(site.data['social_links']).map { |link| link['url'] }
        (rel_me + EXTRA_SAME_AS).uniq
      end
    end
  end
end
