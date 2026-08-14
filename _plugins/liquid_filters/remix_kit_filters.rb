# frozen_string_literal: true

require 'date'
require 'open3'

module Jekyll
  # Filters for inspecting the remix kit ZIP archives in
  # assets/remix-kits/: their size, modification date, and contents.
  module RemixKitFilters
    def zip_size(input)
      path = remix_kit_path(input)
      File.file?(path) ? File.size(path) : 0
    end

    def zip_date(input)
      path = remix_kit_path(input)
      File.file?(path) ? File.mtime(path).to_date : Date.today
    end

    def zip_contents(input)
      path = remix_kit_path(input)
      return [] unless File.file?(path)

      stdout, stderr, status = Open3.capture3('unzip', '-l', path)
      return warn_and_return_empty(path, stderr) unless status.success?

      stdout.lines.filter_map { |line| zip_entry_relative_path(line) }
    end

    private

    def remix_kit_path(input)
      site = @context && @context.registers[:site]
      source = site&.source || Dir.pwd
      File.join(source, 'assets', 'remix-kits', input)
    end

    def warn_and_return_empty(path, stderr)
      Jekyll.logger.warn 'remix-kits:', "Could not list #{path}: #{stderr.strip}"
      []
    end

    def zip_entry_relative_path(line)
      tokens = line.split
      return if tokens.size < 4 || tokens[0] !~ /\A\d+\z/

      name = tokens[3..].join(' ')
      return if name.end_with?('/') || name.empty?

      segments = name.split('/')
      segments.drop(1).join('/') if segments.size > 1
    end
  end
end

Liquid::Template.register_filter Jekyll::RemixKitFilters
