# frozen_string_literal: true

module Jekyll
  module JsonLd
    # An "album entry" is a post whose own front matter describes an album:
    # it has an `album` key, but that key has no nested `slug` value. A
    # track post also carries an `album` key (e.g. `album: { slug: ...,
    # position: ... }`), but there it points *at* its parent album rather
    # than describing itself, so the presence of `slug` is what
    # distinguishes the two - not the page's `layout`, which is only an
    # incidental consequence of _config.yml's `path` defaults and could
    # change independently of what the front matter actually means.
    module AlbumEntry
      def self.for?(data)
        album = data['album']
        !!(album && !album['slug'])
      end
    end
  end
end
