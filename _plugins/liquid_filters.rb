# frozen_string_literal: false

require 'bytesize'
require 'date'
require 'open3'
require 'uri'

module Jekyll
  # Filters for working with Jekyll::Page objects
  module LiquidFilters
    def reject(input, key, value = nil)
      if value.nil?
        input.reject do |item|
          parts = key.split('.')
          val = parts.reduce(item) { |obj, k| obj.respond_to?(:[]) ? obj[k] : nil }
          val.respond_to?(:empty?) ? !val.empty? : !!val
        end
      else
        input.reject do |item|
          v = item[key]
          if v.is_a?(Array)
            v.include?(value)
          elsif !v.nil?
            v == value
          elsif item.respond_to?(:[])
            plural = key.end_with?('y') ? "#{key[0..-2]}ies" : "#{key}s"
            pv = item[plural]
            pv.is_a?(Array) ? pv.include?(value) : pv == value
          else
            false
          end
        end
      end
    end

    def sort_by(input, key)
      input.sort_by do |item|
        parts = key.split('.')
        parts.reduce(item) { |obj, k| obj.respond_to?(:[]) ? obj[k] : nil } || 0
      end
    end

    def children_of(all_pages, parent)
      all_pages.select { |p| child_of?(p, parent) }
    end

    def link_url(input)
      input.is_a?(Hash) ? input.values.first.to_s : input.to_s
    end

    def link_brand(input)
      case link_url(input)
      when %r{bandcamp\.com}i   then 'bandcamp'
      when %r{soundcloud\.com}i then 'soundcloud'
      when %r{music\.apple\.com}i then 'apple-music'
      when %r{open\.spotify\.com}i then 'spotify'
      when %r{mirlo\.space}i    then 'mirlo'
      when %r{demozoo\.org}i  then 'demozoo'
      when %r{youtube\.com|youtu\.be}i then 'youtube'
      when %r{modarchive\.org}i then 'modarchive'
      when %r{amp\.dascene\.net}i then 'amp'
      when %r{scenestream\.net}i then 'nectarine'
      else 'unknown'
      end
    end

    def link_by_brand(input, brand)
      Array(input).find { |item| link_brand(item) == brand }
    end

    # Describes a tracker module format abbreviation, reusing the same
    # tracker software names introduced in music/legacy/index.md ("tracker
    # modules in software such as ProTracker, Scream Tracker, Fast Tracker
    # II, and Impulse Tracker").
    def format_description(format)
      case format.to_s.upcase
      when 'MOD'  then 'ProTracker module'
      when 'S3M'  then 'Scream Tracker 3 module'
      when 'FST'  then 'Fast Tracker module'
      when 'XM'   then 'Fast Tracker II module'
      when 'IT'   then 'Impulse Tracker module'
      when 'XRNS' then 'Renoise song'
      else format.to_s
      end
    end

    # Some services (e.g. ModArchive, AMP) only store a direct-download URL in
    # `links`, but linking to that URL from anywhere other than the dedicated
    # Download button should instead point at the service's HTML page for the
    # module. This maps a stored link to that page URL, falling back to the
    # original URL for brands with no such distinction.
    def link_page_url(input)
      url = link_url(input)
      case link_brand(input)
      when 'modarchive'
        moduleid = URI.parse(url).query.to_s[/(?:^|&)moduleid=(\d+)/, 1]
        moduleid ? "https://modarchive.org/index.php?request=view_by_moduleid&query=#{moduleid}" : url
      when 'amp'
        index = URI.parse(url).query.to_s[/(?:^|&)index=(\d+)/, 1]
        index ? "https://amp.dascene.net/analyzer2.php?idx=#{index}" : url
      else
        url
      end
    rescue URI::InvalidURIError, URI::InvalidComponentError
      url
    end

    def youtube_id(input)
      uri = URI.parse(link_url(input))
      return Regexp.last_match(1) if uri.query.to_s =~ /(?:^|[?&])v=([\w-]{11})/

      path = uri.path.to_s
      return Regexp.last_match(1) if path =~ %r{\A/(?:embed|shorts|live)/([\w-]{11})}
      return Regexp.last_match(1) if uri.host.to_s.include?('youtu.be') && path =~ %r{\A/([\w-]{11})}

      uri.to_s[/\A[\w-]{11}\z/]
    rescue URI::InvalidURIError, URI::InvalidComponentError
      link_url(input)[/\A[\w-]{11}\z/]
    end

    def link_host(input)
      uri = URI.parse(link_url(input))
      host = uri.host.to_s.sub(/\Awww\./i, '')
      host = "#{host}:#{uri.port}" if uri.port && ![80, 443].include?(uri.port)
      host
    rescue URI::InvalidURIError, URI::InvalidComponentError
      link_url(input)
    end

    def file_size(input)
      ByteSize.new(input).to_s
    end

    def thousands_separated(input, separator = '.')
      input.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{separator}")
    end

    def zip_size(input)
      path = remix_kit_path(input)
      File.file?(path) ? File.size(path) : 0
    end

    def zip_date(input)
      path = remix_kit_path(input)
      File.file?(path) ? File.mtime(path).to_date : Date.today
    end

    def zip_contents(input)
      path = remix_kit_path(input)
      return [] unless File.file?(path)

      stdout, stderr, status = Open3.capture3('unzip', '-l', path)
      unless status.success?
        Jekyll.logger.warn 'remix-kits:', "Could not list #{path}: #{stderr.strip}"
        return []
      end

      stdout.lines.filter_map do |line|
        tokens = line.split
        next if tokens.size < 4 || tokens[0] !~ /\A\d+\z/

        name = tokens[3..].join(' ')
        next if name.end_with?('/') || name.empty?

        segments = name.split('/')
        segments.drop(1).join('/') if segments.size > 1
      end
    end

    private

    def child_of?(child, parent)
      parent_path = parent['path']
      child_path = child.path

      # Exclude 'index.md' from becoming a child of itself
      return false if parent_path == child_path

      # Remove 'index.md' from the parent path
      parent_path = parent_path.split('index.md', 2).first

      child_path.start_with? parent_path
    end

    def remix_kit_path(input)
      site = @context && @context.registers[:site]
      source = site&.source || Dir.pwd
      File.join(source, 'assets', 'remix-kits', input)
    end
  end
end

Liquid::Template.register_filter Jekyll::LiquidFilters
