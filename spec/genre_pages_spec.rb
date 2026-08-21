# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'support/site_fixtures'

module GenrePagesHelpers
  module_function

  def genre_page_path(tag)
    File.join(SiteFixtures.source_root, '_site', 'music', 'genres', tag, 'index.html')
  end
end

include SiteFixtures
include GenrePagesHelpers

post_paths = Dir.glob(File.join(SiteFixtures.source_root, 'music', '**', '_posts', '*.md'))
published_post_paths = post_paths.reject { |path| SiteFixtures.front_matter(path)['published'] == false }
all_tags = published_post_paths.flat_map { |path| SiteFixtures.front_matter(path)['tags'].to_a }.uniq

describe 'genre (tag) pages' do
  include SiteFixtures
  include GenrePagesHelpers

  it 'has at least one tagged track' do
    expect(all_tags).not_to be_empty
  end

  all_tags.each do |tag|
    describe "the #{tag} genre page" do
      let(:page_path) { genre_page_path(tag) }
      let(:page) { read_utf8(page_path) }

      it 'exists' do
        expect(File).to exist(page_path)
      end

      it 'lists only tracks tagged with it' do
        tagged_titles = published_post_paths
                        .map { |path| front_matter(path) }
                        .select { |data| Array(data['tags']).include?(tag) }
                        .map { |data| data['title'] }

        tagged_titles.each do |title|
          expect(page).to have_tag('td a', text: /#{Regexp.escape(title)}/)
        end
      end
    end
  end

  describe 'the chip genre page (physical override)' do
    let(:page_path) { genre_page_path('chip') }
    let(:page) { read_utf8(page_path) }

    it 'uses the hand-written music/genres/chip/index.md content, not the generic title' do
      expect(page).to have_tag('h2', text: "Bitbear's Chiptunes")
      expect(page).not_to have_tag('h2', text: "Bitbear's Chip Tracks")
    end

    it 'renders its own description instead of the generic tag blurb' do
      expect(page).to include('Chiptunes')
      expect(page).not_to include("Here you can find all of Bitbear's chip tracks")
    end

    it 'is only generated once, not duplicated by the synthesized tag page' do
      expect(Dir.glob(File.join(source_root, '_site', 'music', 'genres', 'chip', '*'))).to eq(
        [File.join(source_root, '_site', 'music', 'genres', 'chip', 'index.html')]
      )
    end
  end

  describe 'a synthesized genre page (no physical override)' do
    let(:page_path) { genre_page_path('house') }
    let(:page) { read_utf8(page_path) }

    it 'gets a generic title derived from the tag name' do
      expect(page).to have_tag('h2', text: "Bitbear's House Tracks")
    end
  end

  describe 'a track page tagged with genres' do
    let(:track_path) { File.join(source_root, '_site', 'music', 'vos-sako-rv.html') }
    let(:track) { read_utf8(track_path) }

    it 'exposes each tag as a link to its genre page in a "Genres" row' do
      expect(track).to have_tag('tr') do
        with_tag('th', scope: 'row', text: /Genres/)
        with_tag('a', text: 'House', with: { href: '/music/genres/house/' })
      end
    end
  end

  describe 'a track page tagged with multiple genres' do
    let(:track_path) { File.join(source_root, '_site', 'music', 'legacy', 'blood.html') }
    let(:track) { read_utf8(track_path) }

    it 'lists the genre links in alphabetical order, not front-matter order' do
      tags = front_matter(
        File.join(source_root, 'music', 'legacy', '_posts', '1999-07-12-blood.md')
      )['tags']
      expect(tags).to eq(%w[trance house oldskool])

      genres_cell = track[/<td class="genres">.*?<\/td>/m]
      rendered_order = genres_cell.scan(%r{/music/genres/([\w-]+)/}).flatten
      expect(rendered_order).to eq(tags.sort)
    end
  end
end
