# frozen_string_literal: true

module Jekyll
  module JsonLd
    # The site-wide schema.org MusicGroup entity describing the artist. Most
    # of it is identical on every page and so is a frozen constant, but
    # `genre` is computed from the union of every track's `tags` front
    # matter, the same source of truth used for the /music/genres/ pages.
    module MusicGroup
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
        'sameAs' => [
          'https://www.facebook.com/bitbearmusic',
          'https://twitter.com/bitbearmusic',
          'https://www.instagram.com/bitbearmusic',
          'https://www.youtube.com/channel/UC9wb6OrUrugGg6-q9805RDQ',
          'https://soundcloud.com/bitbear',
          'http://dj.beatport.com/bitbear',
          'https://www.mixcloud.com/bitbearmusic/',
          'https://bitbearmusic.bandcamp.com',
          'https://urort.p3.no/artist/Bitbear',
          'https://icosahedron.website/@bitbear',
          'https://mastodon.social/@bitbear',
          'https://modarchive.org/index.php?request=view_profile&query=84875'
        ],
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
        STATIC.merge('genre' => genres(site))
      end

      def self.genres(site)
        site.posts.docs.flat_map { |doc| doc.data['tags'] || [] }.uniq.sort
      end
    end
  end
end
