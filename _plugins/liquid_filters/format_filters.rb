# frozen_string_literal: true

require 'bytesize'

module Jekyll
  # Filters for formatting numeric/media values (file sizes, thousands
  # separators) and building URLs for Git LFS-tracked assets.
  module FormatFilters
    def file_size(input)
      ByteSize.new(input).to_s
    end

    def thousands_separated(input, separator = '.')
      input.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{separator}")
    end

    # Builds a URL for a Git LFS-tracked file. In production, this points at
    # media.githubusercontent.com, which serves LFS objects directly without
    # requiring them to be included in the (1 GB-capped) GitHub Pages
    # deployment artifact. Everywhere else (local dev, htmlproofer, specs) it
    # falls back to the normal on-site path, so the file must be present on
    # disk (e.g. via `git lfs pull`) to be linked/read locally.
    def lfs_media_url(path)
      site = @context && @context.registers[:site]
      return "/#{path}" unless site && Jekyll.env == 'production'

      repository = site.config['repository']
      branch = site.config['repository_branch'] || 'main'
      return "/#{path}" unless repository

      "https://media.githubusercontent.com/media/#{repository}/#{branch}/#{path}"
    end
  end
end

Liquid::Template.register_filter Jekyll::FormatFilters
