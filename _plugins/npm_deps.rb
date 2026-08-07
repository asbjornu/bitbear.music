# frozen_string_literal: true

require 'fileutils'
require 'open3'

# Ensures npm dependencies are installed before Jekyll builds or serves, and
# copies npm-sourced static assets (fonts) into the generated site.
#
# - Sass resolves `@use 'pico'` from `node_modules/@picocss/pico/scss` via the
#   `sass.load_paths` in `_config.yml`.
# - Fonts are static files, so Jekyll cannot compile them from `node_modules`
#   the way it can SCSS. `@fontsource-variable/roboto` ships
#   `files/roboto-latin-wght-normal.woff2`, which we mirror into
#   `_site/assets/fonts/roboto-latin.woff2` after each build/serve so the
#   `@font-face` in `_typography.scss` can reference it at the fixed path.
Jekyll::Hooks.register :site, :after_init do |site|
  missing = %w[@picocss/pico @fontsource-variable/roboto].any? do |pkg|
    !Dir.exist?(File.join(site.source, 'node_modules', pkg))
  end
  next unless missing

  Jekyll.logger.info 'npm:', 'Installing dependencies (npm ci)...'
  stdout, stderr, status = Open3.capture3('npm', 'ci', chdir: site.source)

  unless status.success?
    Jekyll.logger.error 'npm:', 'npm ci failed'
    Jekyll.logger.error 'npm:', stdout
    Jekyll.logger.error 'npm:', stderr
    raise 'npm ci failed; required to build the Pico stylesheet'
  end
end

Jekyll::Hooks.register :site, :post_write do |site|
  font_source = File.join(
    site.source, 'node_modules', '@fontsource-variable', 'roboto', 'files',
    'roboto-latin-wght-normal.woff2'
  )

  unless File.exist?(font_source)
    Jekyll.logger.warn 'fonts:', 'roboto-latin-wght-normal.woff2 not found; ' \
                                'local Roboto font was not copied to _site'
    next
  end

  font_dest_dir = File.join(site.dest, 'assets', 'fonts')
  FileUtils.mkdir_p(font_dest_dir)
  FileUtils.cp(font_source, File.join(font_dest_dir, 'roboto-latin.woff2'))
end