# frozen_string_literal: true

require 'date'
require 'json'
require 'net/http'
require 'uri'
require 'yaml'

# Reads and parses track pages and the external streaming catalogues (Tidal
# and Deezer) used to verify recorded music metadata.
module StreamingCatalog
  module_function

  def fetch(url, accept = 'text/html')
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ' \
                            'AppleWebKit/605.1.15 (KHTML, like Gecko) ' \
                            'Version/17.0 Safari/605.1.15'
    request['Accept'] = accept
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 30) do |http|
      http.request(request).body
    end
  end

  # Tidal exposes a schema.org MusicRecording JSON-LD block (with `isrcCode`)
  # on every track page; parse it without needing an API token.
  def tidal_recording(track_id)
    html = fetch("https://tidal.com/track/#{track_id}")
    json = html[%r{<script[^>]*application/ld\+json[^>]*>(.*?)</script>}m, 1]
    data = json && JSON.parse(json)
    data if data.is_a?(Hash) && data['@type'] == 'MusicRecording'
  end

  # Returns nil when Deezer does not carry the ISRC (it does not list every
  # release), so callers treat a miss as "not verifiable here", not a failure.
  def deezer_track(isrc)
    data = JSON.parse(fetch("https://api.deezer.com/track/isrc:#{isrc}", 'application/json'))
    data unless data.is_a?(Hash) && data['error']
  end

  def front_matter(path)
    match = File.read(path).match(/\A---\s*\n(.*?)\n---/m)
    return nil unless match

    YAML.safe_load(match[1], permitted_classes: [Date, Time, Symbol], aliases: true)
  end

  # Collapse cosmetic differences (case, punctuation, "(feat. …)", "Pt." vs
  # "Part", curly quotes) so only genuine mismatches are reported.
  def normalize(str)
    str.to_s
       .unicode_normalize(:nfkd)
       .downcase
       .gsub(/\(\s*(?:feat|featuring|ft)\b\.?[^)]*\)/, ' ')
       .gsub(/\bft\b|\bfeat\b|\bfeaturing\b/, ' ')
       .gsub(/\bpt\b/, 'part')
       .gsub(/[^a-z0-9]+/, ' ')
       .strip
  end

  def iso8601_seconds(duration)
    match = duration.to_s.match(/\APT(?:(\d+)M)?(?:(\d+)S)?\z/)
    return nil unless match

    (match[1].to_i * 60) + match[2].to_i
  end
end
