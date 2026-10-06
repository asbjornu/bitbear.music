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
      'sunset-through-the-rain-modulo-ones-night-drive' => 'QZHPJ2689090',
      'intro' => 'QZTH82517193',
      'adrenaline' => 'QT6Y22559339',
      'life-without-love' => 'QZYB42544682',
      'project-millennium' => 'QZH5E2584985',
      'one-ring' => 'QZT852517906',
      'halloween' => 'QZFP52531848',
      'rage' => 'QZT852582045',
      'sweat' => 'QZYB32576664',
      'uncherrished-bitch' => 'QZYB22528758',
      'behind-the-curtains' => 'QZRPB2530933',
      'walking-part-1' => 'QZMHM2641217',
      'walking-part-2' => 'QZKDK2609692',
      'walking-part-3' => 'QZMHL2692121',
      'united-in-power' => 'QZRPB2568554',
      'back-in-the-shire' => 'QZT852585918',
      'medieval-orphanage' => 'QZS642445772',
      'the-army' => 'QZMHM2400493',
      'open-your-heart' => 'QZTH92518817',
      'lykke-liten' => 'QZS652620702',
      'spiteful-experiments' => 'QZS632455843',
      'veronica' => 'QZS632439502',
      'below-the-surface' => 'QZMHP2448353',
      'horizon' => 'QZS652411390',
      'beveled-edges' => 'QZMHK2496763',
      'blood' => 'QZS652436877',
      'out-of-range' => 'QZS652468315',
      'helium' => 'QM42K2433508',
      'soaked-in-orange' => 'QZNRS2560359',
      'soluble-temper' => 'QZYB42548774',
      'tears' => 'QZFP52565697',
      'the-prey' => 'QZT862597275',
      'portentous-aid' => 'QZYB32524211',
      'manhattan' => 'QT6Y32533858'
    }
  end

  def read_utf8(path)
    File.binread(path).force_encoding(Encoding::UTF_8)
  end

  def track_html(slug)
    candidates = [
      File.join(site_root, '_site', 'music', "#{slug}.html"),
      File.join(site_root, '_site', 'music', slug, 'index.html'),
      File.join(site_root, '_site', 'music', 'legacy', "#{slug}.html"),
      File.join(site_root, '_site', 'music', 'legacy', slug, 'index.html')
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

describe 'JSON-LD Puma Person' do
  let(:site_root) { File.expand_path('..', __dir__) }

  def read_utf8(path)
    File.binread(path).force_encoding(Encoding::UTF_8)
  end

  let(:puma_html) { read_utf8(File.join(site_root, '_site', 'music', 'legacy', 'puma.html')) }

  let(:person) do
    json = puma_html[%r{<script type="application/ld\+json">(.*?)</script>}m, 1]
    JSON.parse(json)['@graph'].find { |entity| entity['@type'] == 'Person' }
  end

  it 'emits a Person entity named Puma on the scener profile page' do
    expect(person).not_to be_nil
    expect(person['name']).to eq('Puma')
  end

  it 'lists Puma’s production aliases as alternateName' do
    expect(person['alternateName']).to include('Fulgore', 'adMiXTURE')
  end

  it 'lists Puma’s group memberships as memberOf organizations' do
    names = person['memberOf'].map { |group| group['name'] }
    expect(names).to include('Dupe', 'ULTiMATE')
  end

  it 'links to Puma’s Demozoo scener profile as sameAs' do
    expect(person['sameAs']).to include('https://demozoo.org/sceners/106369/')
  end
end
