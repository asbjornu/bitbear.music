# frozen_string_literal: true

module CoverArtGenerator
  # The logo for a cover: either the "Power of Creation" wordmark (legacy
  # tracks, an SVG) or the Bitbear bear-icon + text lockup (everything else,
  # a PNG — see assets/images/bitbear-outlined.png, trimmed from the GitHub
  # repository's own OpenGraph image, which already has a white outline
  # around its black shapes for contrast against any background), top-aligned
  # and filling LOGO_WIDTH_RATIO (90%) of the canvas width, with the same
  # whitespace on its left, top and right sides. See
  # CoverArtGenerator::SvgDocument.build for how it's combined with the
  # gradient background and title pill.
  module Logo
    module_function

    # The "Power of Creation" wordmark's leftmost "P" has a long descender
    # tail that dips well below where every other letter (including the
    # rightmost "N") actually ends, so the SVG's own viewBox — and thus its
    # naive bottom edge — is taller than where the wordmark *visually* ends.
    # Measured from the rendered glyphs directly (ignoring that one outlier
    # tail): the real letters stop around 77% of the way down the asset.
    VISUAL_BOTTOM_RATIO = 0.77

    # "Power of Creation" logo. Returns [svg, right_edge, bottom_edge] (the
    # bounds the title pill aligns to — see #bitbear). `bottom_edge` is
    # adjusted for the "P" tail (see VISUAL_BOTTOM_RATIO above) so the title
    # pill sits close to where the wordmark actually visually ends.
    def power_of_creation(source_dir)
      svg, right_edge, bottom_edge = image(File.join(source_dir, POWER_OF_CREATION_LOGO))
      visual_bottom_edge = bottom_edge - ((bottom_edge - PADDING) * (1 - VISUAL_BOTTOM_RATIO))

      [svg, right_edge, visual_bottom_edge]
    end

    # Bitbear bear-icon + text lockup. Returns [svg, right_edge, bottom_edge].
    def bitbear(source_dir)
      image(File.join(source_dir, BITBEAR_LOGO))
    end

    # Sizes `path` to LOGO_WIDTH_RATIO of the canvas, top-aligned with even
    # padding on its left, top and right, embedding it as an `<image>` (PNG)
    # or an inlined, scaled `<g>` (SVG) as appropriate.
    def image(path)
      width = SIZE - (2 * PADDING)
      height = width / SvgAsset.aspect_ratio(path)
      element = SvgAsset.png?(path) ? png_element(path, width, height) : svg_group(path, width)

      [element, PADDING + width, PADDING + height]
    end

    def png_element(path, width, height)
      data = Base64.strict_encode64(File.binread(path))
      %(<image href="data:image/png;base64,#{data}" x="#{PADDING}" y="#{PADDING}" ) +
        %(width="#{width.round(2)}" height="#{height.round(2)}"/>)
    end

    def svg_group(path, width)
      scale = (width / SvgAsset.svg_width(path)).round(6)
      <<~SVG
        <g transform="translate(#{PADDING}, #{PADDING}) scale(#{scale})">
          #{SvgAsset.inline_svg_body(path)}
        </g>
      SVG
    end
  end
end
