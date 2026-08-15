# frozen_string_literal: true

require_relative 'entity_helpers'

module Jekyll
  module JsonLd
    # Builds a schema.org MusicAlbum Hash for an album page (layout:
    # album), including its track listing and the union of all its tracks'
    # genres, linked back to the site-wide MusicGroup via byArtist.
    class MusicAlbum
      include EntityHelpers

      def initialize(site, page, context)
        @site = site
        @page = page
        @context = context
      end

      def to_h
        album = base
        apply_release_type!(album)
        apply_cover!(album)
        apply_tracks!(album)
        apply_links!(album)
        album
      end

      private

      def base
        {
          '@type' => 'MusicAlbum',
          'name' => @page['title'],
          'byArtist' => { '@id' => 'https://bitbear.music' },
          'url' => absolute_url(@page['url']),
          'datePublished' => format_date(@page['date'])
        }
      end

      def apply_release_type!(album)
        kind = @page['album'] && @page['album']['kind']
        album['albumReleaseType'] = kind if kind
      end

      def apply_cover!(album)
        cover = @page['media'] && @page['media']['cover']
        image = cover_image_url(cover)
        album['image'] = image if image
      end

      def apply_tracks!(album)
        apply_genre!(album)
        return if tracks.empty?

        album['numTracks'] = tracks.size
        album['track'] = tracks.map { |track| track_reference(track) }
      end

      def apply_genre!(album)
        genres = tracks.flat_map { |track| track.data['tags'] || [] }.uniq
        album['genre'] = genres if genres.any?
      end

      def apply_links!(album)
        links = @page['links']
        album['sameAs'] = same_as(links) if links&.any?
      end

      def track_reference(track)
        reference = {
          '@type' => 'MusicRecording',
          'name' => track.data['title'],
          'url' => absolute_url(track.url)
        }

        length = track.data.dig('media', 'length')
        reference['duration'] = iso8601_duration(length) if length
        reference
      end

      def tracks
        return @tracks if defined?(@tracks)

        slug = @page['slug']
        @tracks = @site.posts.docs
                       .select { |doc| doc.data.dig('album', 'slug') == slug }
                       .sort_by { |doc| doc.data.dig('album', 'position') || 0 }
      end
    end
  end
end
