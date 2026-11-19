# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'support/site_fixtures'

require 'cgi'

# Every legacy post ships its tracker module under assets/modules/ so that
# Cowbell + libopenmpt can play it in the browser (see
# assets/scripts/module-player.js). The modules are Git LFS-tracked, so the
# specs below only inspect the actual bytes when they are checked out (local
# runs); in CI the working tree contains LFS pointer files.
describe 'legacy tracker modules' do
  include SiteFixtures

  LFS_POINTER = 'version https://git-lfs.github.com/spec/v1'

  FORMAT_MAGIC = {
    'IT' => ->(bytes) { bytes.start_with?('IMPM') },
    'S3M' => ->(bytes) { bytes.byteslice(44, 4) == 'SCRM' },
    'MOD' => ->(bytes) { bytes.byteslice(1080, 4).to_s.match?(/\A(M\.K\.|M!K!|\dCHN|FLT[48])/) }
  }.freeze

  def legacy_posts
    Dir.glob(File.join(source_root, 'music', 'legacy', '_posts', '*.md')).sort.map do |path|
      [File.basename(path), front_matter(path)]
    end
  end

  def track_posts
    legacy_posts.select { |_file, data| data.dig('media', 'format') }
  end

  def module_path(module_name)
    File.join(source_root, 'assets', 'modules', module_name)
  end

  def real_bytes?(path)
    !File.binread(path, LFS_POINTER.length).start_with?(LFS_POINTER)
  end

  it 'publishes a module for every legacy track' do
    expect(track_posts).not_to be_empty

    track_posts.each do |file, data|
      slug = file.sub(/\A\d{4}-\d{2}-\d{2}-/, '').sub(/\.md\z/, '')
      expected = "poc_#{slug}.#{data.dig('media', 'format').downcase}"

      expect(data.dig('media', 'module')).to eq(expected), "#{file} should point at #{expected}"
      expect(File).to exist(module_path(expected)), "missing #{expected}"
    end
  end

  it 'records the size of the shipped module' do
    track_posts.each do |file, data|
      path = module_path(data.dig('media', 'module'))
      next unless real_bytes?(path)

      expect(data.dig('media', 'filesize')).to eq(File.size(path)),
                                               "#{file} filesize should match #{data.dig('media', 'module')}"
    end
  end

  it 'only ships modules whose contents match their declared format' do
    track_posts.each do |file, data|
      path = module_path(data.dig('media', 'module'))
      next unless real_bytes?(path)

      format = data.dig('media', 'format')
      matcher = FORMAT_MAGIC.fetch(format)
      expect(matcher.call(File.binread(path, 1084))).to be(true),
                                                      "#{file} is not a #{format} file"
    end
  end

  it 'stores every module in Git LFS' do
    patterns = File.readlines(File.join(source_root, '.gitattributes')).map(&:strip)
    extensions = track_posts.map { |_file, data| data.dig('media', 'module').split('.').last }.uniq

    extensions.each do |extension|
      expect(
        patterns.any? { |line| line.start_with?("**/*.#{extension} ") && line.include?('filter=lfs') }
      ).to be(true), "**/*.#{extension} is not Git LFS-tracked"
    end
  end

  def soundcloud?(data)
    Array(data['links']).any? { |link| link.to_s.match?(/soundcloud\.com/i) }
  end

  def soundcloud_url(data)
    Array(data['links']).find { |link| link.to_s.match?(/soundcloud\.com/i) }.to_s
  end

  def youtube?(data)
    Array(data['links']).any? do |link|
      url = link.to_s
      url.match?(/youtube\.com|youtu\.be/i) && !url.match?(/music\.youtube\.com/i)
    end
  end

  it 'puts the available sources behind the play button on the cover art' do
    track_posts.each do |file, data|
      slug = file.sub(/\A\d{4}-\d{2}-\d{2}-/, '').sub(/\.md\z/, '')
      page = read_utf8(File.join(source_root, '_site', 'music', 'legacy', "#{slug}.html"))

      # The play button replaces the old inline players.
      expect(page).not_to include('class="module-player"')
      expect(page).not_to include(%(src="/assets/scripts/module-player.js"))

      # libopenmpt must never be loaded eagerly — only when play is pressed.
      expect(page).not_to include('libopenmpt.js')

      # The tracker module is always an option, and the player script is
      # loaded up front so the click can open an AudioContext.
      expect(page).to include(%(data-module="/assets/modules/#{data.dig('media', 'module')}"))
      expect(page).to include(%(src="/assets/scripts/cover-audio.js"))

      if page.include?('<dialog id="cover-art">')
        expect(page).to include('id="cover-play"')
        expect(page).not_to include('>Listen<')

        if soundcloud?(data)
          expect(page).to include(%(data-soundcloud="#{CGI.escapeHTML(soundcloud_url(data))}"))
          expect(page).to include('data-default="soundcloud"')
          expect(page).to include('data-source="soundcloud" aria-pressed="true"')
          expect(page).not_to include('w.soundcloud.com/player')
        else
          expect(page).not_to include('data-soundcloud=')
        end

        if youtube?(data)
          expect(page).to include('data-source="video"')
        else
          expect(page).not_to include('data-video=')
        end
      else
        # No cover art to hang the player on (see cover_art_generator.rb).
        expect(page).to include('class="inline-audio"')
        expect(page).not_to include('id="cover-play"')
      end
    end
  end
end
