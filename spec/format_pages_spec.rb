# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'support/site_fixtures'

module FormatPagesHelpers
  module_function

  def format_page_path(format)
    File.join(SiteFixtures.source_root, '_site', 'music', 'formats', format.downcase, 'index.html')
  end
end

include SiteFixtures
include FormatPagesHelpers

post_paths = Dir.glob(File.join(SiteFixtures.source_root, 'music', '**', '_posts', '*.md'))
published_post_paths = post_paths.reject { |path| SiteFixtures.front_matter(path)['published'] == false }
all_formats = published_post_paths.filter_map { |path| SiteFixtures.front_matter(path).dig('media', 'format') }
                                   .uniq

describe 'format pages' do
  include SiteFixtures
  include FormatPagesHelpers

  it 'has at least one track with a format' do
    expect(all_formats).not_to be_empty
  end

  all_formats.each do |format|
    describe "the #{format} format page" do
      let(:page_path) { format_page_path(format) }
      let(:page) { read_utf8(page_path) }

      it 'exists' do
        expect(File).to exist(page_path)
      end

      it 'explains the format rather than falling back to the generic blurb' do
        expect(page).not_to include("Here you can find all of Bitbear's #{format} tracks")
      end

      it 'lists only tracks produced in that format' do
        format_titles = published_post_paths
                         .map { |path| front_matter(path) }
                         .select { |data| data.dig('media', 'format') == format }
                         .map { |data| data['title'] }

        format_titles.each do |title|
          expect(page).to have_tag('td a', text: /#{Regexp.escape(title)}/)
        end
      end

      it 'is only generated once, not duplicated by the synthesized format page' do
        dir = File.join(source_root, '_site', 'music', 'formats', format.downcase)
        expect(Dir.glob(File.join(dir, '*'))).to eq([File.join(dir, 'index.html')])
      end
    end
  end

  describe 'a track page with a format' do
    let(:track_path) { File.join(source_root, '_site', 'music', 'vos-sako-rv.html') }
    let(:track) { read_utf8(track_path) }

    it 'links the format abbreviation to its format page' do
      expect(track).to have_tag('tr') do
        with_tag('th', scope: 'row', text: /Format/)
        with_tag('a', text: 'XRNS', with: { href: '/music/formats/xrns/' })
      end
    end
  end

  describe 'a song table listing tracks with formats' do
    let(:index_path) { File.join(source_root, '_site', 'music', 'index.html') }
    let(:index_page) { read_utf8(index_path) }

    it 'links the format abbreviation shown in the "Kind" column to its format page' do
      expect(index_page).to have_tag('a', text: 'XRNS', with: { href: '/music/formats/xrns/' })
    end
  end
end
