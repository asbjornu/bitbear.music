# frozen_string_literal: true

require 'open3'

# Ensures npm dependencies are installed before Jekyll builds or serves.
#
# Sass resolves `@use 'pico'` from `node_modules/@picocss/pico/scss` (see the
# `sass.load_paths` in `_config.yml`). This hook runs `npm ci` on the first
# build/serve if those dependencies are not yet present locally.
Jekyll::Hooks.register :site, :after_init do |site|
  next if Dir.exist?(File.join(site.source, 'node_modules', '@picocss', 'pico'))

  Jekyll.logger.info 'npm:', 'Installing dependencies (npm ci)...'
  stdout, stderr, status = Open3.capture3('npm', 'ci', chdir: site.source)

  unless status.success?
    Jekyll.logger.error 'npm:', 'npm ci failed'
    Jekyll.logger.error 'npm:', stdout
    Jekyll.logger.error 'npm:', stderr
    raise 'npm ci failed; required to build the Pico stylesheet'
  end
end