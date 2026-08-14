# frozen_string_literal: true

module Jekyll
  # Synthesizes a page at /music/genres/<tag>/ for every tag used across the
  # site's posts (site.tags), giving every tag the same URL structure
  # regardless of whether it's backed by a hand-written page or not.
  #
  # If a physical page already exists at that URL (e.g. music/genres/chip/
  # index.md, which is Bitbear's chiptunes page with its own hand-written
  # description), that page takes precedence and no page is generated for
  # that tag.
  class TagPageGenerator < Generator
    safe true
    priority :low

    def generate(site)
      existing_urls = site.pages.to_set(&:url)

      site.tags.each_key do |tag|
        next if existing_urls.include?(tag_url(tag))

        site.pages << TagPage.new(site, tag)
      end
    end

    private

    def tag_url(tag)
      "/#{File.join('music', 'genres', tag)}/"
    end
  end

  # A generated page listing every post tagged with a given tag, rendered
  # with the `tag` layout at /music/genres/<tag>/.
  class TagPage < Page
    # Deliberately does not call super: Jekyll::Page#initialize reads
    # front matter from a backing file on disk, but this page is
    # synthesized in memory and has no such file.
    # rubocop:disable Lint/MissingSuper
    def initialize(site, tag)
      @site = site
      @base = site.source
      @dir  = File.join('music', 'genres', tag)
      @name = 'index.html'

      process(@name)

      self.data = {
        'layout' => 'tag',
        'title' => "Bitbear's #{tag.split(/[\s-]+/).map(&:capitalize).join(' ')} Tracks",
        'tag' => tag
      }
    end
    # rubocop:enable Lint/MissingSuper
  end
end
