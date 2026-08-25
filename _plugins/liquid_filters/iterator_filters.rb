# frozen_string_literal: true

module Jekyll
  # Filters that resolve the destination, `rel` attribute, visible label
  # and full-title tooltip for the nav.iterator "back" button, plus the
  # tooltip for its prev/next track links.
  #
  # This moves the branching that used to live in nested Liquid
  # `{% if %}`/`{% elsif %}` tags in _includes/iterator.html (is this
  # page's "back" link the site root, an album/single/EP track's
  # release, a release page's music index, or a plain folder index?)
  # into a single Ruby method, which is easier to read, extend and test
  # than deeply-nested Liquid conditionals.
  module IteratorFilters
    # Returns a Hash with 'link', 'rel', 'text' and 'describe' keys
    # describing the iterator's back/index button for the given page.
    def iterator_back(page)
      site = @context.registers[:site]
      album = page['album']
      segments = url_segments(page['url'])

      if segments.size == 1
        home_back(site)
      elsif album && album['slug']
        release_back(site, album['slug'])
      elsif album && album['kind']
        music_index_back(site)
      else
        folder_back(site, segments)
      end
    end

    # Returns the tooltip text for a linked post: `Go to track "Move"`,
    # or `Go to <kind> "..."` (album/single/EP) if the post is itself a
    # release rather than a plain track.
    def describe_link(item, kind = 'track')
      kind = item['album']['kind'].downcase if item['album'] && item['album']['kind']
      %(Go to the “#{item['title']}” #{kind})
    end

    private

    # Mirrors the previous Liquid `page.url | remove: '.html' | split:
    # '/' | pop` pipeline: the URL's path segments with the page's own
    # segment (and any trailing empty one from a trailing slash) dropped.
    def url_segments(url)
      segments = url.to_s.sub(/\.html\z/, '').split('/')
      segments.pop
      segments
    end

    def home_back(site)
      target = site.pages.find { |candidate| candidate.url == '/' }
      {
        'link' => '/',
        'rel' => 'back index',
        'text' => 'Home',
        'describe' => %(Go back to the “#{target && target.data['title']}” home page)
      }
    end

    def release_back(site, slug)
      release = find_release(site, slug)
      kind = release.data.dig('album', 'kind').to_s.downcase
      {
        'link' => release.url,
        'rel' => 'back',
        'text' => "Back to #{kind}",
        'describe' => %(Go back to the “#{release.data['title']}” #{kind})
      }
    end

    # A release's own page and each of its tracks' pages can share the same
    # basename-derived `slug` (e.g. a single named after its one track), so
    # disambiguate by picking the post that has an `album.kind` of its own
    # (the release), rather than merely one whose `slug` matches.
    def find_release(site, slug)
      site.posts.docs.find do |post|
        post.data['slug'] == slug && post.data.dig('album', 'kind')
      end
    end

    def music_index_back(site)
      music_page = site.pages.find { |candidate| candidate.data['title'] == 'Music' }
      {
        'link' => music_page.url,
        'rel' => 'back',
        'text' => 'Back to Music',
        'describe' => %(Go back to the “#{music_page.data['title']}” page)
      }
    end

    def folder_back(site, segments)
      link = "/#{segments.drop(1).join('/')}/"
      text = "Back to #{segments.last}"
      target = site.pages.find { |candidate| candidate.url == link }
      describe = target ? %(Go back to the “#{target.data['title']}” page) : text

      { 'link' => link, 'rel' => 'back', 'text' => text, 'describe' => describe }
    end
  end
end

Liquid::Template.register_filter Jekyll::IteratorFilters
