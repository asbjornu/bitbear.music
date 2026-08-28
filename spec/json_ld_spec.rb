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

describe 'JSON-LD MusicRecording isrcCode' do
  let(:site_root) { File.expand_path('..', __dir__) }

  # Track posts that carry an `isrc` front-matter value (sourced from the
  # matching Deezer release). Each one must surface as `isrcCode` on its own
  # MusicRecording entity.
  let(:expected) do
    {
      'rise' => 'QM4DW1796505',
      'raise-the-dead' => 'QM4DW1796502',
      'move' => 'QM4DW1796500',
      'move-atroxitys-disco-donkey-remix' => 'QM4DW1796501',
      'raise-the-dead-knofle-remix' => 'QM4DW1796504',
      'raise-the-dead-modulo-ones-flying-dead-remix' => 'QM4DW1796503',
      'the-touch' => 'QZBRF1847721',
      'that-flateby-feeling' => 'QZMHN2462053',
      'sunset-through-the-rain' => 'QZMHL2450245',
      'the-king-and-the-priest' => 'QZK6H2181109',
      'sunset-through-the-rain-modulo-ones-night-drive' => 'QZHPJ2689090'
    }
  end

  def read_utf8(path)
    File.binread(path).force_encoding(Encoding::UTF_8)
  end

  def track_html(slug)
    candidates = [
      File.join(site_root, '_site', 'music', "#{slug}.html"),
      File.join(site_root, '_site', 'music', slug, 'index.html')
    ]
    candidates.find { |path| File.exist?(path) }
  end

  def recording_for(slug)
    html = read_utf8(track_html(slug))
    json = html[%r{<script type="application/ld\+json">(.*?)</script>}m, 1]
    graph = JSON.parse(json)['@graph']
    graph.find { |entity| entity['@type'] == 'MusicRecording' }
  end

  it 'emits the sourced isrcCode on every track that has one' do
    expected.each do |slug, isrc|
      recording = recording_for(slug)
      expect(recording).not_to be_nil, "no MusicRecording JSON-LD for #{slug}"
      expect(recording['isrcCode']).to eq(isrc)
    end
  end

  it 'omits isrcCode on track pages that do not declare one' do
    # Planeswalker is a track post without a sourced ISRC.
    recording = recording_for('planeswalker')
    expect(recording).not_to be_nil
    expect(recording).not_to have_key('isrcCode')
  end
end
