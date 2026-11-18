# frozen_string_literal: true

require 'yaml'
require_relative 'spec_helper'
require_relative 'support/site_fixtures'

describe 'sample source credits' do
  include SiteFixtures

  let(:sources_path) { File.join(source_root, '_data', 'sample_sources.yml') }
  let(:sources) { YAML.safe_load_file(sources_path) }
  let(:post_paths) { Dir.glob(File.join(source_root, 'music', '**', '_posts', '*.md')) }

  def credited_posts
    post_paths.filter_map do |path|
      data = post_front_matter(path)
      next unless data && data['sample_sources']

      [path, data]
    end
  end

  def post_front_matter(path)
    raw = File.binread(path).force_encoding(Encoding::UTF_8)
    YAML.safe_load(raw.split(/^---\s*$/)[1], permitted_classes: [Date, Time, Symbol], aliases: true)
  end

  it 'has a data file with a title for every source' do
    expect(sources).to be_a(Hash)
    expect(sources).not_to be_empty
    sources.each do |key, source|
      expect(source['title']).to be_a(String), "#{key} is missing a title"
      expect(source['title'].strip).not_to be_empty, "#{key} is missing a title"
    end
  end

  it 'only references defined sources and always explains the evidence' do
    credited_posts.each do |path, data|
      credits = data['sample_sources']
      expect(credits).to be_an(Array), "#{path}: sample_sources must be a list"

      seen = []
      credits.each do |credit|
        expect(credit).to be_a(Hash), "#{path}: each sample source must be a mapping"
        expect(credit['source']).to be_a(String), "#{path}: each sample source needs a source key"
        expect(sources).to have_key(credit['source']), "#{path}: unknown sample source #{credit['source'].inspect}"
        expect(credit['evidence']).to be_a(String), "#{path}: #{credit['source']} needs evidence"
        expect(credit['evidence'].strip).not_to be_empty, "#{path}: #{credit['source']} needs evidence"
        expect(seen).not_to include(credit['source']), "#{path}: duplicate source #{credit['source']}"
        if credit['chain_after']
          expect(seen).to include(credit['chain_after']),
                             "#{path}: chain_after must refer to an earlier source"
        end
        seen << credit['source']
      end
    end
  end

  it 'renders the credited sources in the song metadata table' do
    page = Dir.glob(File.join(source_root, '_site', 'music', '**', 'call-of-the-druidz.html')).first
    expect(page).not_to be_nil

    html = read_utf8(page)
    expect(html).to have_tag('th', scope: 'row', text: 'Samples:', with: {
                               'aria-description' => 'The samples in “Call of the Druidz” is sourced as follows',
                               'data-tooltip' => 'The samples in “Call of the Druidz” is sourced as follows'
                             })
    expect(html).to have_tag('td', with: { class: 'samples' }) do
      with_tag('ul', with: { class: 'sample-sources' }) do
        with_tag('a', with: { href: sources['cool-city']['url'] }) do
          with_tag('span', with: { class: 'icon icon-demozoo' })
        end
        with_tag('a', with: { href: sources['cool-city']['msm_url'] }) do
          with_tag('span', with: { class: 'icon icon-msm' })
        end
        with_tag('li', with: { class: 'sample-arrow' }, text: '→')
        with_tag('a', with: { href: sources['outzider-mork-sone-2']['url'] }) do
          with_tag('span', with: { class: 'icon icon-demozoo' })
        end
      end
    end
    expect(html).to match(/data-tooltip="[^"]*Purple Motion[^"]*Nine exact samples/)
  end
end
