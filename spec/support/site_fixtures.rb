# frozen_string_literal: true

require 'yaml'

# Shared helpers for reading built `_site` output and source post front
# matter, used by specs that inspect generated pages (format_pages_spec.rb,
# genre_pages_spec.rb, remix_kit_spec.rb).
module SiteFixtures
  module_function

  def source_root
    File.expand_path('../..', __dir__)
  end

  def read_utf8(path)
    File.binread(path).force_encoding(Encoding::UTF_8)
  end

  def front_matter(path)
    YAML.safe_load(File.read(path).split(/^---\s*$/)[1], permitted_classes: [Date, Time, Symbol], aliases: true)
  end
end
