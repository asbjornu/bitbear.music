# frozen_string_literal: true

require 'yaml'
require_relative '../_plugins/liquid_filters/link_filters'

RSpec.describe 'link_titles data coverage' do # rubocop:disable RSpec/DescribeClass
  include Jekyll::LinkFilters

  let(:site_root) { File.expand_path('..', __dir__) }
  let(:cache_path) { File.join(site_root, '_data', 'link_titles.yml') }

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

  def unknown_links
    Dir.glob(File.join(site_root, '**', '_posts', '**', '*.{md,markdown}')).flat_map do |post|
      links_in(post).reject { |url| url.empty? || link_brand(url) != 'unknown' }
    end
  end

  def links_in(post)
    Array(front_matter(post)&.fetch('links', nil)).filter_map do |link|
      link.is_a?(Hash) ? link.values.first.to_s : link.to_s
    end
  end

  def uncached_unknown_links
    cache = YAML.safe_load_file(cache_path) || {}
    unknown_links.select { |url| cache[url].to_s.strip.empty? }
  end

  it 'records a non-empty title for every unknown-brand link' do
    skip '_data/link_titles.yml missing' unless File.exist?(cache_path)
    expect(uncached_unknown_links).to be_empty,
                                      "Unknown links without a cached title (run `rake fetch-link-titles`):\n" \
                                      "#{uncached_unknown_links.join("\n")}"
  end
end
