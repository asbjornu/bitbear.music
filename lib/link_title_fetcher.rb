# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'yaml'
require 'nokogiri'
require 'liquid'
require 'fileutils'
require_relative 'page_title_client'
require_relative '../_plugins/liquid_filters/link_filters'

# Fetches the <title> of pages linked from unknown-brand `links` entries and
# records them in `_data/link_titles.yml`. Builds never call this — only the
# manual `rake fetch-link-titles` task does, so the published site stays
# fully offline and deterministic.
class LinkTitleFetcher
  include Jekyll::LinkFilters

  def self.run(site_root:, force: false, host_filter: nil)
    new(site_root).run(force: force, host_filter: host_filter)
  end

  def initialize(site_root)
    @site_root = site_root
    @cache_path = File.join(site_root, '_data', 'link_titles.yml')
  end

  def run(force: false, host_filter: nil)
    urls = unknown_link_urls
    urls.select! { |u| u.include?(host_filter) } if host_filter && !host_filter.empty?
    cache = load_cache
    pending = pending_urls(urls.uniq, cache, force)
    return finish_with_no_updates if pending.empty?

    puts "Fetching #{pending.size} link title(s)#{' (force)' if force}..."
    updated = fetch_and_record(pending, cache)
    write_cache(cache) if updated.positive?
    updated
  end

  private

  # All unknown-brand link URLs declared across music posts.
  def unknown_link_urls
    Dir.glob(File.join(@site_root, '**', '_posts', '**', '*.{md,markdown}'))
       .flat_map { |post| links_from_post(post) }
       .select { |url| !url.empty? && link_brand(url) == 'unknown' }
  end

  def links_from_post(post)
    Array(front_matter(post)&.fetch('links', nil))
      .filter_map { |link| link.is_a?(Hash) ? link.values.first.to_s : link.to_s }
  end

  def pending_urls(urls, cache, force)
    urls.each_with_object([]) do |url, list|
      cached = cache[url].to_s.strip
      list << url if force || cached.empty?
    end
  end

  def finish_with_no_updates
    puts 'No link titles to fetch.'
    0
  end

  def fetch_and_record(pending, cache)
    updated = 0
    pending.each do |url|
      title = fetch_title(url)
      if title.nil?
        puts "  skip (unreachable): #{url}"
        next
      end
      if cache[url].to_s.strip == title
        puts "  unchanged: #{url}"
      else
        cache[url] = title
        updated += 1
        puts "  ok: #{url} -> #{title}"
      end
    end
    updated
  end

  # Parses a Jekyll post's YAML front matter without booting a full site.
  def front_matter(path)
    raw = File.read(path)
    return nil unless raw.start_with?('---')

    body = raw.sub(/\A---\r?\n/, '')
    fm = body[/\A.*?\n---\r?\n/m]
    return nil if fm.nil?

    YAML.safe_load(fm.sub(/---\r?\n\z/, '')) || {}
  rescue StandardError
    nil
  end

  def load_cache
    File.exist?(@cache_path) ? (YAML.safe_load_file(@cache_path) || {}) : {}
  end

  def write_cache(cache)
    FileUtils.mkdir_p(File.dirname(@cache_path))
    yaml = YAML.dump(cache, line_width: -1)
    File.write(@cache_path, yaml)
  end

  # Fetches a page and returns its stripped <title>, or nil on any failure so
  # the caller can fall back. Redirects are followed up to MAX_REDIRECTS.
  def fetch_title(url)
    PageTitleClient.new.fetch_title(url)
  end
end
