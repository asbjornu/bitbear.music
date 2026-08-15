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

    # Converts a `media.length` value such as "4:03" or "1:04:03" into an
    # ISO 8601 duration ("PT4M3S"/"PT1H4M3S") as required by schema.org's
    # MusicRecording#duration property.
    def iso8601_duration(input)
      hours, minutes, seconds = hours_minutes_seconds(input)
      return nil if hours.nil?

      duration = 'PT'
      duration += "#{hours}H" if hours.positive?
      duration += "#{minutes}M" if minutes.positive?
      duration += "#{seconds}S" if seconds.positive? || (hours.zero? && minutes.zero?)
      duration
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

    private

    # Parses a "M:SS" or "H:MM:SS" string into an [hours, minutes, seconds]
    # triple of integers, or [nil, nil, nil] if the input has an unsupported
    # number of segments.
    def hours_minutes_seconds(input)
      segments = input.to_s.split(':').map(&:to_i)

      case segments.length
      when 1 then [0, 0, segments[0]]
      when 2 then [0, segments[0], segments[1]]
      when 3 then segments
      else [nil, nil, nil]
      end
    end
  end
end

Liquid::Template.register_filter Jekyll::FormatFilters
