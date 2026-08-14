# frozen_string_literal: true

module Jekyll
  # Filters for working with arrays of Jekyll::Page/Document objects (posts,
  # pages, etc.), independent of any particular domain (links, media, etc.).
  module CollectionFilters
    def reject(input, key, value = nil)
      if value.nil?
        input.reject { |item| truthy_value?(item, key) }
      else
        input.reject { |item| value_matches?(item, key, value) }
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

    private

    def truthy_value?(item, key)
      val = dig_value(item, key)
      val.respond_to?(:empty?) ? !val.empty? : !val.nil?
    end

    def value_matches?(item, key, value)
      v = item[key]
      return v.include?(value) if v.is_a?(Array)
      return v == value unless v.nil?
      return false unless item.respond_to?(:[])

      plural_value_matches?(item, key, value)
    end

    def plural_value_matches?(item, key, value)
      plural = key.end_with?('y') ? "#{key[0..-2]}ies" : "#{key}s"
      pv = item[plural]
      pv.is_a?(Array) ? pv.include?(value) : pv == value
    end

    def dig_value(item, key)
      key.split('.').reduce(item) { |obj, k| obj.respond_to?(:[]) ? obj[k] : nil }
    end

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

Liquid::Template.register_filter Jekyll::CollectionFilters
