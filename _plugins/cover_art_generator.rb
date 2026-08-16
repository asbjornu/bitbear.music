# frozen_string_literal: true

require_relative '../lib/cover_art_generator'

# Generates cover art for any track post that doesn't have any yet, before
# each Jekyll build/serve. See lib/cover_art_generator.rb for how covers are
# built; this hook just wires it into the Jekyll build lifecycle so writing
# a new post without cover art (and building or running `jekyll serve`) is
# enough to get one, without a separate manual step.
#
# Runs at :after_init (before posts are read into Document objects), the
# same point npm_deps.rb installs npm packages at, since the generated
# images and front matter need to be on disk before Jekyll reads the site.
#
# Set SKIP_COVER_ART_GENERATION=true to opt out (the test suite does this,
# since spec/spec_helper.rb deliberately strips one post's `cover:` front
# matter for the duration of the build to exercise post.html's no-cover
# fallback path in style_spec.rb, and this hook would otherwise "fix" that
# post right back before the fixture spec runs).
Jekyll::Hooks.register :site, :after_init do |site|
  next if ENV['SKIP_COVER_ART_GENERATION'] == 'true'

  CoverArtGenerator.generate!(source_dir: site.source, logger: Jekyll.logger)
end
