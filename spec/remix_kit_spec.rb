# frozen_string_literal: true

require_relative 'spec_helper'

require 'yaml'

describe 'remix kit pages' do
  def read_utf8(path)
    File.binread(path).force_encoding(Encoding::UTF_8)
  end

  def source_root
    File.expand_path('..', __dir__)
  end

  def front_matter(path)
    YAML.safe_load(File.read(path).split(/^---\s*$/)[1])
  end

  def body_text(path)
    File.read(path).split(/^---\s*$/)[2].strip.gsub(/\s+/, ' ')
  end

  def kit_posts(slug)
    Dir.glob(File.join(source_root, 'music', '**', '_posts', "*-#{slug}.md"))
       .sort_by { |path| File.basename(path).split('-', 3).first }
       .reverse
       .map { |path| [front_matter(path), path] }
  end

  def kit_release(slug)
    kit_posts(slug).first
  end

  def kit_track(slug)
    kit_posts(slug).find { |data, _path| data.dig('media', 'format') } || kit_release(slug)
  end

  def post_url(post, slug)
    if post.last.include?(File.join('albums', '_posts'))
      "/music/albums/#{slug}"
    else
      "/music/#{slug}"
    end
  end

  def built_page_path(post, slug)
    if post.last.include?(File.join('albums', '_posts'))
      File.join(source_root, '_site', 'music', 'albums', "#{slug}.html")
    else
      File.join(source_root, '_site', 'music', "#{slug}.html")
    end
  end

  def expected_archive(slug)
    title = kit_track(slug).first['title']
    "Bitbear-#{title.gsub(' ', '_')}-Remix_Kit.zip"
  end

  kits = Dir.glob(File.join(File.expand_path('..', __dir__), '_remix_kits', '*.md'))

  it 'has at least one remix kit' do
    expect(kits).not_to be_empty
  end

  kits.each do |kit_file|
    slug = File.basename(kit_file, '.md')

    describe "for the #{slug} kit" do
      let(:kit_page_path) { File.join(source_root, '_site', 'music', slug, 'remix-kit', 'index.html') }
      let(:kit) { read_utf8(kit_page_path) }
      let(:release) { kit_release(slug) }
      let(:track) { kit_track(slug) }
      let(:archive_name) { expected_archive(slug) }

      it 'generates the kit page' do
        expect(File).to exist(kit_page_path)
      end

      it 'uses the kit title from the remix kit file as the page heading' do
        title = front_matter(kit_file)['title']
        expect(kit).to have_tag('h2', text: /#{Regexp.escape(title)}/)
      end

      it 'renders the kit description from the remix kit file' do
        expect(kit).to include(body_text(kit_file))
      end

      it 'shows the track the kit is for' do
        title = track.first['title']
        expect(kit).to have_tag('td a', text: /#{Regexp.escape(title)}/, with: { href: post_url(track, slug) })
      end

      it 'shows the archive filesize' do
        expect(kit).to have_tag('td', with: { class: 'filesize' })
      end

      it 'links the download to the real archive' do
        expect(kit).to have_tag('a', with: { href: "/assets/remix-kits/#{archive_name}", role: 'button' })
        expect(File).to exist(File.join(source_root, 'assets', 'remix-kits', archive_name))
      end

      it 'ships the archive under the hard-coded download pattern' do
        expect(archive_name).to match(%r{\ABitbear-.+-Remix_Kit\.zip\z})
      end

      it 'lists the archive contents' do
        expect(kit).to have_tag('div', with: { class: 'contents' }) do
          with_tag('ul') do
            with_tag('li')
          end
        end
      end

      it 'links back to the track the kit is for' do
        expect(kit).to have_tag('a', with: { href: post_url(track, slug), rel: 'back' })
      end

      it 'points the release page remix kit row at the kit page' do
        release_page = read_utf8(built_page_path(release, slug))
        expect(release_page).to have_tag('tr', with: { class: 'remix-kit-row' }) do
          with_tag('th', scope: 'row', text: /Remix kit/)
          with_tag('a', with: { href: "/music/#{slug}/remix-kit/" })
        end
      end

      it 'explains the license and links to the license page' do
        expect(kit).to have_tag('h3', text: /License/)
        expect(kit).to have_tag('a', with: { href: '/license/', rel: 'license' })
        expect(kit).to have_tag('a', text: /Creative\s+Commons/, with: { href: 'https://creativecommons.org/licenses/by-nc/4.0/', rel: 'license' })
      end
    end
  end
end