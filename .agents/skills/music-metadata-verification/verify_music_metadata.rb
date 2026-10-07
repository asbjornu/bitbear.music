# frozen_string_literal: true

# Verifies the metadata recorded on music posts (primarily ISRC, but also
# title and duration) against an external streaming catalogue.
#
# Primary source: Tidal. Every distributed track post links to its Tidal
# track page, whose JSON-LD MusicRecording carries the authoritative
# `isrcCode`, `name` and `duration`. No API key is required.
#
# Secondary source: Deezer (https://api.deezer.com/track/isrc:<ISRC>), used
# as an extra cross-check when a track is on Deezer. Deezer does not carry
# every release, so a miss is not a failure.
#
# Usage:
#   ruby .agents/skills/music-metadata-verification/verify_music_metadata.rb [repo-root]
#
# Exit status is non-zero when any hard check fails (bad ISRC shape or an
# ISRC that disagrees with the catalogue). Title/duration differences are
# reported as warnings, not failures.

require_relative 'streaming_catalog'

# Audits every track post's recorded metadata against Tidal and Deezer.
class MusicMetadataVerifier
  ISRC_PATTERN = /\A[A-Z]{2}[A-Z0-9]{3}[0-9]{7}\z/
  TIDAL_TRACK_PATTERN = %r{tidal\.com/track/(\d+)}

  def initialize(root)
    @root = root
    @failures = 0
    @warnings = 0
    @checked = 0
  end

  def run
    posts.sort.each { |path| check(path) }
    puts "\nchecked=#{@checked} failures=#{@failures} warnings=#{@warnings}"
    exit(@failures.zero? ? 0 : 1)
  end

  private

  def posts
    Dir.glob(File.join(@root, 'music', '{,legacy/}albums/_posts', '*.md')) +
      Dir.glob(File.join(@root, 'music', '{,legacy/}_posts', '*.md'))
  end

  def check(path)
    data = StreamingCatalog.front_matter(path)
    isrc = data&.dig('media', 'isrc')
    return if isrc.nil? || isrc.to_s.strip.empty?

    @checked += 1
    slug = data['slug'] || File.basename(path, '.md')

    unless isrc.to_s.match?(ISRC_PATTERN)
      failure("#{slug}: ISRC #{isrc.inspect} is not a valid 12-character ISRC")
      return
    end

    check_tidal(data, slug, isrc)
    check_deezer(slug, isrc)
    sleep 0.4
  end

  def check_tidal(data, slug, isrc)
    link = Array(data['links']).find { |l| l =~ TIDAL_TRACK_PATTERN }
    recording = link && StreamingCatalog.tidal_recording(link[TIDAL_TRACK_PATTERN, 1])

    unless recording
      warn_about("#{slug}: no Tidal link / JSON-LD to confirm #{isrc}")
      return
    end

    matched = confirm_isrc?(slug, isrc, recording['isrcCode'], 'Tidal')
    verify_title(slug, data['title'], recording['name'])
    verify_length(slug, data.dig('media', 'length'), recording['duration'])
    puts "ok    #{slug}: ISRC #{isrc} confirmed by Tidal" if matched
  end

  def check_deezer(slug, isrc)
    deezer = StreamingCatalog.deezer_track(isrc)
    return unless deezer

    confirm_isrc?(slug, isrc, deezer['isrc'], 'Deezer')
  end

  def confirm_isrc?(slug, recorded, sourced, service)
    return true if sourced.to_s.strip.upcase == recorded.to_s.strip.upcase

    failure("#{slug}: recorded #{recorded} but #{service} says #{sourced}")
    false
  end

  def verify_title(slug, recorded, sourced)
    return if StreamingCatalog.normalize(recorded) == StreamingCatalog.normalize(sourced)

    warn_about("#{slug}: title #{recorded.inspect} vs catalogue #{sourced.inspect}")
  end

  def verify_length(slug, recorded, duration)
    seconds = StreamingCatalog.iso8601_seconds(duration)
    expected = recorded.to_s.match(/\A(\d+):(\d{2})\z/)
    return unless seconds && expected

    delta = seconds - (expected[1].to_i * 60) - expected[2].to_i
    warn_about("#{slug}: length #{recorded} vs catalogue #{duration}") if delta.abs > 1
  end

  def failure(message)
    @failures += 1
    puts "FAIL  #{message}"
  end

  def warn_about(message)
    @warnings += 1
    puts "WARN  #{message}"
  end
end

MusicMetadataVerifier.new(ARGV[0] || File.expand_path('../../..', __dir__)).run
