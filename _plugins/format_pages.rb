# frozen_string_literal: true

module Jekyll
  # Synthesizes a page at /music/formats/<format>/ for every distinct track
  # format (page.media.format, e.g. "MOD", "S3M", "IT", "XRNS") used across
  # the site's posts, giving every format the same URL structure regardless
  # of whether it's backed by a hand-written page or not.
  #
  # If a physical page already exists at that URL (e.g. music/formats/mod/
  # index.md, explaining the MOD format with its own hand-written
  # description), that page takes precedence and no page is generated for
  # that format.
  class FormatPageGenerator < Generator
    safe true
    priority :low

    def generate(site)
      site.data['formats'] = formats_by_post(site)

      existing_urls = site.pages.to_set(&:url)

      site.data['formats'].each_key do |format|
        next if existing_urls.include?(format_url(format))

        site.pages << FormatPage.new(site, format)
      end
    end

    private

    def formats_by_post(site)
      formats = Hash.new { |hash, key| hash[key] = [] }

      site.posts.docs.each do |post|
        format = post.data.dig('media', 'format')
        formats[format] << post if format
      end

      formats.each_value { |posts| posts.sort!.reverse! }
      formats
    end

    def format_url(format)
      "/#{File.join('music', 'formats', format.downcase)}/"
    end
  end

  # A generated page listing every post produced in a given format, rendered
  # with the `format` layout at /music/formats/<format>/.
  class FormatPage < Page
    # Deliberately does not call super: Jekyll::Page#initialize reads
    # front matter from a backing file on disk, but this page is
    # synthesized in memory and has no such file.
    # rubocop:disable Lint/MissingSuper
    def initialize(site, format)
      @site = site
      @base = site.source
      @dir  = File.join('music', 'formats', format.downcase)
      @name = 'index.html'

      process(@name)

      self.data = {
        'layout' => 'format',
        'title' => "Bitbear's #{format} Tracks",
        'format' => format
      }
    end
    # rubocop:enable Lint/MissingSuper
  end
end
