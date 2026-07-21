# frozen_string_literal: false

require 'bytesize'

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

    def ordinalize(input)
      v = input.to_i % 100
      return "#{input}th" if (11..13).include?(v)

      suffix = %w[th st nd rd][v % 10] || 'th'
      "#{input}#{suffix}"
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
  end
end

Liquid::Template.register_filter Jekyll::LiquidFilters
