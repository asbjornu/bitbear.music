# frozen_string_literal: true

require_relative '../liquid_filters/link_filters'
require_relative '../liquid_filters/format_filters'

module Jekyll
  module JsonLd
    # Shared helpers for building schema.org entity Hashes: absolute URLs
    # (via Jekyll's own URLFilters), ISO 8601 durations, and normalized link
    # URLs (both reused from the site's existing Liquid filter modules).
    module EntityHelpers
      include Jekyll::Filters::URLFilters
      include Jekyll::LinkFilters
      include Jekyll::FormatFilters

      def format_date(date)
        date.respond_to?(:strftime) ? date.strftime('%Y-%m-%d') : date.to_s
      end

      def same_as(links)
        links.map { |item| link_url(item) }
      end

      def cover_image_url(cover)
        return nil unless cover

        absolute_url("/assets/images/covers/#{cover}")
      end
    end
  end
end
