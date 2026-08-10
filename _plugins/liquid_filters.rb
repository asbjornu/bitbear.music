# frozen_string_literal: false

require 'bytesize'
require 'date'
require 'open3'

module Jekyll
  # Filters for working with Jekyll::Page objects
  module LiquidFilters
    def reject(input, key, value = nil)
      if value.nil?
        input.reject do |item|
          parts = key.split('.')
          val = parts.reduce(item) { |obj, k| obj.respond_to?(:[]) ? obj[k] : nil }
          val.respond_to?(:empty?) ? !val.empty? : !!val
        end
      else
        input.reject do |item|
          v = item[key]
          if v.is_a?(Array)
            v.include?(value)
          elsif !v.nil?
            v == value
          elsif item.respond_to?(:[])
            plural = key.end_with?('y') ? "#{key[0..-2]}ies" : "#{key}s"
            pv = item[plural]
            pv.is_a?(Array) ? pv.include?(value) : pv == value
          else
            false
          end
        end
      end
    end

    def sort_by(input, key)
      input.sort_by do |item|
        parts = key.split('.')
        parts.reduce(item) { |obj, k| obj.respond_to?(:[]) ? obj[k] : nil } || 0
      end
    end

    def children_of(all_pages, parent)
      all_pages.select { |p| child_of?(p, parent) }
    end

    def file_size(input)
      ByteSize.new(input).to_s
    end

    def thousands_separated(input, separator = '.')
      input.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{separator}")
    end

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
      unless status.success?
        Jekyll.logger.warn 'remix-kits:', "Could not list #{path}: #{stderr.strip}"
        return []
      end

      stdout.lines.filter_map do |line|
        tokens = line.split
        next if tokens.size < 4 || tokens[0] !~ /\A\d+\z/

        name = tokens[3..].join(' ')
        next if name.end_with?('/') || name.empty?

        segments = name.split('/')
        segments.drop(1).join('/') if segments.size > 1
      end
    end

    def high_res(input)
      return nil if input.nil? || input.empty?

      match = input.match(/\A(.*?)(\.(?:jpe?g|png|webp))\z/i)
      return nil if match.nil?

      candidate = "#{match[1]}@2x#{match[2]}"
      site = @context && @context.registers[:site]
      return nil if site.nil? || site.static_files.nil?

      exists = site.static_files.any? { |file| file.url == candidate }
      exists ? candidate : nil
    end

    private

    def child_of?(child, parent)
      parent_path = parent['path']
      child_path = child.path

      # Exclude 'index.md' from becoming a child of itself
      return false if parent_path == child_path

      # Remove 'index.md' from the parent path
      parent_path = parent_path.split('index.md', 2).first

      child_path.start_with? parent_path
    end

    def remix_kit_path(input)
      site = @context && @context.registers[:site]
      source = site&.source || Dir.pwd
      File.join(source, 'assets', 'remix-kits', input)
    end
  end
end

Liquid::Template.register_filter Jekyll::LiquidFilters
