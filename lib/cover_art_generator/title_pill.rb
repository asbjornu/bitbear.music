# frozen_string_literal: true

module CoverArtGenerator
  # The track title pill: white background, black text, a black border 10%
  # as thick as the pill is tall, right-aligned with (and below) the logo.
  # See CoverArtGenerator::SvgDocument.build.
  module TitlePill
    module_function

    INNER_PAD_X = 28
    INNER_PAD_Y = 14
    LINE_GAP = 1.1
    MAX_FONT_SIZE = 44
    MIN_FONT_SIZE = 22
    STROKE_WIDTH_RATIO = 0.1

    # Typical cap-height/x-height ratios (relative to font-size) for
    # Helvetica/Arial-like sans-serifs. A single line of ordinary title-case
    # text is a mix of full-height capitals/ascenders and shorter, x-height
    # lowercase letters, so neither the cap-height box nor the x-height box
    # alone gives the *visually* centered baseline position — the eye reads
    # the "mass" of the line as sitting somewhere in between the two. See
    # https://iamvdo.me/en/blog/css-font-metrics-line-height-and-vertical-align
    # for the derivation this is adapted from: to center a box of a given
    # height within a row, the baseline sits *below* the row's vertical
    # center by half that box's height (glyphs extend upward from the
    # baseline). Averaging the cap-height and x-height boxes' half-heights
    # approximates that in-between optical center:
    #   (CAP_HEIGHT_RATIO + X_HEIGHT_RATIO) / 4 ≈ 0.31
    # That theoretical value still reads as slightly high in practice here
    # (rendered via rsvg-convert/Pango, not a browser, against our own
    # fallback font stack), so it's nudged down empirically to 0.35 — still
    # anchored to the same reasoning, not an arbitrary tweak.
    CAP_HEIGHT_RATIO = 0.716
    X_HEIGHT_RATIO = 0.518
    THEORETICAL_OPTICAL_CENTER_RATIO = (CAP_HEIGHT_RATIO + X_HEIGHT_RATIO) / 4
    OPTICAL_CENTER_RATIO = THEORETICAL_OPTICAL_CENTER_RATIO + 0.04

    # Builds the pill, right-aligned with `right_edge` and starting at `top`.
    def build(title, right_edge:, top:)
      max_width = right_edge - PADDING
      font_size = fit_font_size(title, max_width)
      lines = width(title, font_size) + (2 * INNER_PAD_X) > max_width ? wrap_two_lines(title) : [title]

      geometry = geometry(lines, font_size, right_edge: right_edge, top: top)
      svg(lines, font_size, geometry)
    end

    # Shrinks the font size until the title (on one line) fits max_width, down
    # to a floor where it gets wrapped onto two lines instead (see #build).
    def fit_font_size(title, max_width)
      font_size = MAX_FONT_SIZE
      font_size -= 2 while font_size > MIN_FONT_SIZE && width(title, font_size) + (2 * INNER_PAD_X) > max_width
      font_size
    end

    def geometry(lines, font_size, right_edge:, top:)
      line_height = font_size * LINE_GAP
      height = (2 * INNER_PAD_Y) + (lines.length * line_height)
      content_width = lines.map { |line| width(line, font_size) }.max
      pill_width = [content_width + (2 * INNER_PAD_X), height].max

      { line_height: line_height, height: height, width: pill_width, x: right_edge - pill_width, y: top }
    end

    def svg(lines, font_size, geometry)
      stroke_width = (geometry[:height] * STROKE_WIDTH_RATIO).round(2)

      <<~SVG
        <rect #{rect_attrs(geometry, stroke_width)}/>
        #{text_lines(lines, font_size, geometry)}
      SVG
    end

    def rect_attrs(geometry, stroke_width)
      pos = rect_position(geometry, stroke_width)
      %(x="#{pos[:x]}" y="#{pos[:y]}" width="#{pos[:width]}" height="#{pos[:height]}" rx="#{pos[:rx]}" ) +
        %(fill="#ffffff" stroke="#000000" stroke-width="#{stroke_width}")
    end

    def rect_position(geometry, stroke_width)
      half_stroke = stroke_width / 2
      {
        x: inset(geometry[:x], half_stroke), y: inset(geometry[:y], half_stroke),
        width: shrink(geometry[:width], stroke_width), height: shrink(geometry[:height], stroke_width),
        rx: inset(geometry[:height] / 2, -half_stroke)
      }
    end

    def inset(value, amount)
      (value + amount).round(2)
    end

    def shrink(value, amount)
      (value - amount).round(2)
    end

    def text_lines(lines, font_size, geometry)
      lines.each_with_index.map { |line, i| text_line(line, i, font_size, geometry) }.join("\n")
    end

    def text_line(line, index, font_size, geometry)
      y = text_line_y(index, font_size, geometry)
      x = (geometry[:x] + (geometry[:width] / 2)).round(2)
      font = "'Helvetica Neue', Helvetica, Arial, sans-serif"
      "<text x=\"#{x}\" y=\"#{y}\" text-anchor=\"middle\" font-family=\"#{font}\" " \
        "font-weight=\"700\" font-size=\"#{font_size}\" fill=\"#000000\">#{escape_xml(line)}</text>"
    end

    # Positions the baseline so the line's *optical* center (see
    # OPTICAL_CENTER_RATIO), not its mathematical em-box center, lines up
    # with the vertical center of its row within the pill.
    def text_line_y(index, font_size, geometry)
      row_center = geometry[:y] + INNER_PAD_Y + (geometry[:line_height] * (index + 0.5))
      (row_center + (font_size * OPTICAL_CENTER_RATIO)).round(2)
    end

    # Heuristic text width for a bold sans-serif font, in SVG user units.
    def width(text, font_size)
      text.length * font_size * 0.58
    end

    def wrap_two_lines(title)
      words = title.split
      return [title] if words.length < 2

      best_split = (1...words.length).min_by do |i|
        (words[0...i].join(' ').length - words[i..].join(' ').length).abs
      end

      [words[0...best_split].join(' '), words[best_split..].join(' ')]
    end

    def escape_xml(text)
      text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end
  end
end
