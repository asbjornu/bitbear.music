# frozen_string_literal: true

module CoverArtGenerator
  # Builds the actual 1080×1080 SVG markup for a cover: a random gradient
  # background (GradientBackground), the logo for the given `kind` (Logo),
  # and the track title (TitlePill). See CoverArtGenerator.render! for where
  # the result gets rasterized to JPEGs.
  module SvgDocument
    module_function

    def build(source_dir:, title:, kind:, seed:)
      rng = Random.new(Digest::MD5.hexdigest(seed).to_i(16))
      gradient = GradientBackground.random(rng)

      logo_svg, logo_right_edge, logo_bottom_edge =
        kind == :legacy ? Logo.power_of_creation(source_dir) : Logo.bitbear(source_dir)

      pill_svg = TitlePill.build(title, right_edge: logo_right_edge, top: logo_bottom_edge + LOGO_TO_PILL_GAP)

      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="#{SIZE}" height="#{SIZE}" viewBox="0 0 #{SIZE} #{SIZE}">
          <defs>
            #{gradient[:def]}
          </defs>
          <rect width="#{SIZE}" height="#{SIZE}" fill="url(##{gradient[:id]})"/>
          #{logo_svg}
          #{pill_svg}
        </svg>
      SVG
    end
  end
end
