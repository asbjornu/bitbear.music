# frozen_string_literal: true

require_relative 'spec_helper'

require 'json'
require 'yaml'

describe 'JSON-LD MusicGroup sameAs' do
  def read_utf8(path)
    File.binread(path).force_encoding(Encoding::UTF_8)
  end

  let(:site_root) { File.expand_path('..', __dir__) }

  let(:index_html) { read_utf8(File.join(site_root, '_site', 'index.html')) }

  let(:music_group) do
    json = index_html[%r{<script type="application/ld\+json">(.*?)</script>}m, 1]
    JSON.parse(json)['@graph'].find { |entity| entity['@type'] == 'MusicGroup' }
  end

  let(:social_links) do
    YAML.safe_load_file(File.join(site_root, '_data', 'social_links.yml'))
  end

  it 'includes every rel="me" link from social_links.yml as a sameAs entry' do
    social_links.each do |link|
      expect(music_group['sameAs']).to include(link['url'])
    end
  end

  it 'renders every social_links.yml entry as a rel="me" link on the homepage' do
    social_links.each do |link|
      expect(index_html).to match(/<a href="#{Regexp.escape(link['url'])}"[^>]*rel="me"/)
    end
  end
end
