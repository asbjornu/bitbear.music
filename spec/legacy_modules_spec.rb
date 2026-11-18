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

  it 'plays SoundCloud when a track has it, and the module player otherwise' do
    soundcloud = 0
    modules = 0

    track_posts.each do |file, data|
      slug = file.sub(/\A\d{4}-\d{2}-\d{2}-/, '').sub(/\.md\z/, '')
      page = read_utf8(File.join(source_root, '_site', 'music', 'legacy', "#{slug}.html"))

      # libopenmpt must never be loaded eagerly — only when play is pressed.
      expect(page).not_to include('libopenmpt.js')

      if soundcloud?(data)
        soundcloud += 1
        expect(page).to include('w.soundcloud.com/player')
        expect(page).not_to include('class="module-player"')
        expect(page).not_to include(%(src="/assets/scripts/module-player.js"))
      else
        modules += 1
        expect(page).to include('class="module-player"')
        expect(page).to include(%(data-module="/assets/modules/#{data.dig('media', 'module')}"))
        expect(page).to include(%(data-title="#{CGI.escapeHTML(data['title'])}"))
        expect(page).to include(%(src="/assets/scripts/module-player.js"))
        expect(page).not_to include('w.soundcloud.com/player')
      end
    end

    expect(soundcloud).to be > 0
    expect(modules).to be > 0
  end
end
