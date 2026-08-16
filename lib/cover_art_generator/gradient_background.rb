# frozen_string_literal: true

module CoverArtGenerator
  # A random linear-gradient background, seeded by an RNG so a given seed
  # always produces the same gradient (see CoverArtGenerator::SvgDocument.build).
  module GradientBackground
    module_function

    def random(rng)
      light1 = 0.28 + (rng.rand * 0.12)
      light2 = 0.14 + (rng.rand * 0.12)
      c1, c2 = colors(rng, light1, light2)
      x1, y1, x2, y2 = line(rng.rand(360))

      {
        id: 'bg',
        light1: light1,
        def: <<~SVG
          <linearGradient id="bg" x1="#{x1}%" y1="#{y1}%" x2="#{x2}%" y2="#{y2}%">
            <stop offset="0%" stop-color="##{c1}"/>
            <stop offset="100%" stop-color="##{c2}"/>
          </linearGradient>
        SVG
      }
    end

    def colors(rng, light1, light2)
      base_hue = rng.rand(360)
      hue2 = (base_hue + 40 + rng.rand(80)) % 360
      [
        hsl_to_hex(base_hue, 0.55 + (rng.rand * 0.25), light1),
        hsl_to_hex(hue2, 0.55 + (rng.rand * 0.25), light2)
      ]
    end

    # The endpoints (as percentages of the canvas) of a gradient line through
    # its center, at the given angle.
    def line(angle)
      angle_rad = angle * Math::PI / 180.0
      [angle_rad + Math::PI, angle_rad].flat_map { |rad| point(rad) }
    end

    def point(angle_rad)
      [(50 + (50 * Math.cos(angle_rad))).round(2), (50 + (50 * Math.sin(angle_rad))).round(2)]
    end

    def hsl_to_hex(hue, saturation, lightness)
      red, green, blue = hsl_to_rgb_ratios(hue, saturation, lightness)
      [red, green, blue].map { |v| (v * 255).round.clamp(0, 255) }
                        .map { |v| format('%02x', v) }.join
    end

    def hsl_to_rgb_ratios(hue, saturation, lightness)
      chroma = (1 - ((2 * lightness) - 1).abs) * saturation
      mid = chroma * (1 - (((hue / 60.0) % 2) - 1).abs)
      offset = lightness - (chroma / 2)
      hue_rgb(hue, chroma, mid).map { |v| v + offset }
    end

    def hue_rgb(hue, chroma, mid)
      case hue
      when 0...60 then [chroma, mid, 0]
      when 60...120 then [mid, chroma, 0]
      when 120...180 then [0, chroma, mid]
      when 180...240 then [0, mid, chroma]
      when 240...300 then [mid, 0, chroma]
      else [chroma, 0, mid]
      end
    end
  end
end
