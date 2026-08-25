# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'nokogiri'

# Handles a single remote page: follows redirects and extracts its <title>.
# Network/parse failures degrade to nil so callers can keep a prior value.
class PageTitleClient
  USER_AGENT = 'bitbear.music link-title fetcher (+https://bitbear.music)'
  TIMEOUT = 10
  MAX_REDIRECTS = 5

  def fetch_title(url)
    title = follow_and_extract_title(URI.parse(url))
    return nil if title.nil?

    stripped = title.to_s.strip.gsub(/\s+/, ' ')
    stripped.empty? ? nil : stripped
  rescue StandardError
    nil
  end

  private

  def follow_and_extract_title(uri, redirects = 0)
    response = http_get(uri)
    case response
    when Net::HTTPSuccess
      extract_title(response.body)
    when Net::HTTPRedirection
      location = response['location']
      return nil if location.nil? || redirects >= MAX_REDIRECTS

      follow_and_extract_title(URI.parse(location), redirects + 1)
    end
  rescue StandardError
    nil
  end

  def http_get(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT
    req = Net::HTTP::Get.new(uri.request_uri)
    req['User-Agent'] = USER_AGENT
    req['Accept'] = 'text/html'
    http.request(req)
  end

  def extract_title(body)
    doc = Nokogiri::HTML(body)
    title = doc.at_css('title')&.text
    return nil if title.nil?

    title.to_s
  end
end
