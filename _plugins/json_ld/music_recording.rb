# frozen_string_literal: true

require_relative 'album_entry'
require_relative 'entity_helpers'

module Jekyll
  module JsonLd
    # Builds a schema.org MusicRecording Hash for a track page (layout:
    # post), linking back to its parent album (if any) and to the site-wide
    # MusicGroup via byArtist.
    class MusicRecording
      include EntityHelpers

      def initialize(site, page, context)
        @site = site
        @page = page
        @context = context
      end

      def to_h
        recording = base
        apply_media!(recording)
        apply_genre!(recording)
        apply_album!(recording)
        apply_links!(recording)
        recording
      end

      private

      def base
        {
          '@type' => 'MusicRecording',
          'name' => @page['title'],
          'byArtist' => { '@id' => 'https://bitbear.music' },
          'url' => absolute_url(@page['url']),
          'datePublished' => format_date(@page['date'])
        }
      end

      def apply_media!(recording)
        length = @page['media'] && @page['media']['length']
        recording['duration'] = iso8601_duration(length) if length

        image = cover_image_url(cover)
        recording['image'] = image if image
      end

      def cover
        (@page['media'] && @page['media']['cover']) || album_post&.data&.dig('media', 'cover')
      end

      def apply_genre!(recording)
        recording['genre'] = @page['tags'] if @page['tags']&.any?
      end

      def apply_album!(recording)
        return unless album_post

        recording['inAlbum'] = {
          '@type' => 'MusicAlbum',
          'name' => album_post.data['title'],
          'url' => absolute_url(album_post.url)
        }
      end

      def apply_links!(recording)
        links = @page['links']
        recording['sameAs'] = same_as(links) if links&.any?
      end

      # Album and track posts can share the same filename slug (e.g. both
      # music/albums/_posts/2026-06-11-sunset-through-the-rain.md and
      # music/_posts/2020-07-11-sunset-through-the-rain.md have the slug
      # "sunset-through-the-rain"), so disambiguate via AlbumEntry as well.
      def album_post
        return @album_post if defined?(@album_post)

        slug = @page['album'] && @page['album']['slug']
        @album_post = slug && @site.posts.docs.find do |doc|
          doc.data['slug'] == slug && AlbumEntry.for?(doc.data)
        end
      end
    end
  end
end
