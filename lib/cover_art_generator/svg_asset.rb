# frozen_string_literal: true

module CoverArtGenerator
  # Reads just enough of an image file's own header (never rendering it) to
  # figure out its natural width, height and aspect ratio: an SVG's `<svg>`
  # header (falling back to the `viewBox` when there's no explicit
  # `width`/`height` attribute, as with assets/images/logo.svg), or a
  # raster PNG's IHDR chunk (as with assets/images/bitbear-outlined.png).
  module SvgAsset
    module_function

    # Inkscape-exported SVGs (e.g. assets/images/power-of-creation.svg) embed
    # <sodipodi:namedview>/<inkscape:*> editor metadata (elements and
    # attributes) using namespace prefixes we don't declare on our own
    # generated <svg> root, which rsvg-convert then refuses to parse once
    # inlined there — strip all of it.
    def inline_svg_body(path)
      @inline_svg_body_cache ||= {}
      @inline_svg_body_cache[path] ||= begin
        body = File.read(path)[%r{<svg[^>]*>(.*)</svg>}m, 1].strip
        body = body.gsub(%r{<(sodipodi|inkscape):[^>]*?(/>|>.*?</\1:[^>]*>)}m, '')
        body.gsub(/\s(sodipodi|inkscape):[\w-]+="[^"]*"/, '').strip
      end
    end

    def width(path)
      png?(path) ? png_size(path)[0] : svg_width(path)
    end

    def height(path)
      png?(path) ? png_size(path)[1] : svg_height(path)
    end

    def aspect_ratio(path)
      png?(path) ? png_size(path).then { |w, h| w.to_f / h } : svg_aspect_ratio(path)
    end

    def png?(path)
      File.extname(path).casecmp('.png').zero?
    end

    # A PNG's width/height live as two big-endian uint32s right after the
    # fixed-size IHDR chunk header: 8-byte PNG signature, 4-byte chunk
    # length, 4-byte "IHDR" tag, then width (4 bytes) and height (4 bytes).
    def png_size(path)
      @png_size_cache ||= {}
      @png_size_cache[path] ||= begin
        header = File.binread(path, 24)
        [header[16, 4].unpack1('N'), header[20, 4].unpack1('N')]
      end
    end

    def svg_width(path)
      @svg_width_cache ||= {}
      @svg_width_cache[path] ||= explicit_svg_width(path) || view_box(svg_header(path))[2]
    end

    def svg_height(path)
      @svg_height_cache ||= {}
      @svg_height_cache[path] ||= svg_width(path) / svg_aspect_ratio(path)
    end

    def svg_aspect_ratio(path)
      @svg_aspect_ratio_cache ||= {}
      @svg_aspect_ratio_cache[path] ||= begin
        width, height = explicit_svg_size(path)
        width, height = view_box(svg_header(path))[2, 2] if width.nil? || height.nil? || width.zero? || height.zero?
        width / height
      end
    end

    def svg_header(path)
      @svg_header_cache ||= {}
      @svg_header_cache[path] ||= File.read(path)[/<svg[^>]*>/]
    end

    def explicit_svg_width(path)
      svg_header(path)[/\swidth="([\d.]+)"/, 1]&.to_f
    end

    def explicit_svg_size(path)
      header = svg_header(path)
      [header[/\swidth="([\d.]+)"/, 1]&.to_f, header[/\sheight="([\d.]+)"/, 1]&.to_f]
    end

    def view_box(header)
      header[/\sviewBox="([\d.\s-]+)"/, 1].to_s.split.map(&:to_f)
    end
  end
end
