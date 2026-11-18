# frozen_string_literal: true

module Jekyll
  # Filters for formatting plain text for display.
  module TextFilters
    # Wraps text in typographic (smart) double quotes: “like this”.
    def smart_quotes(input)
      "“#{input}”"
    end
  end
end

Liquid::Template.register_filter Jekyll::TextFilters
