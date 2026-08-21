# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'digest'
require 'base64'
require_relative 'cover_art_generator/svg_asset'
require_relative 'cover_art_generator/gradient_background'
require_relative 'cover_art_generator/logo'
require_relative 'cover_art_generator/title_pill'
require_relative 'cover_art_generator/svg_document'

# Generates 1080×1080 (+ 2160×2160 @2x) cover-art JPEGs for any track post
# that doesn't yet have one, and wires the generated file into the post's
# `media.cover` front matter.
#
# A track that belongs to an album (has `album.slug` in its front matter,
# see AGENTS.md's "album cover inheritance" note) gets its cover art from the
# album and is skipped here — only the album post itself (which has an
# `album` key with no nested `slug`) gets its own generated cover.
#
# Every cover has a background of a randomly generated linear gradient (see
# CoverArtGenerator::SvgDocument), and is otherwise built from the site's own
# logo assets:
#
# - Legacy tracks (anything under music/legacy/) use the "Power of Creation"
#   wordmark (assets/images/power-of-creation.svg).
# - Everything else uses the Bitbear bear-icon + text lockup
#   (assets/images/bitbear-outlined.png).
#
# Either way the logo fills 90% of the canvas width (LOGO_WIDTH_RATIO), with
# the same whitespace on its left, top and right sides.
#
# Either way, the track title is rendered in a pill: white background, black
# text, a black border 10% as thick as the pill is tall, right-aligned with
# the logo above it.
#
# Runs idempotently: a post is only touched if its `cover.jpg`/`@2x.jpg`
# files don't already exist on disk (see .generate!).
module CoverArtGenerator
  SIZE = 1080
  # The logo fills 90% of the canvas width, with the same whitespace on its
  # left, top and right sides — i.e. 5% of the canvas on each side.
  LOGO_WIDTH_RATIO = 0.9
  PADDING = (SIZE * (1 - LOGO_WIDTH_RATIO) / 2).round
  # How far below the logo's bottom edge the title pill starts.
  LOGO_TO_PILL_GAP = 12

  IMAGES_DIR = File.join('assets', 'images')
  COVERS_DIR = File.join(IMAGES_DIR, 'covers')

  POWER_OF_CREATION_LOGO = File.join(IMAGES_DIR, 'power-of-creation.svg')
  BITBEAR_LOGO = File.join(IMAGES_DIR, 'bitbear-outlined.png')

  Post = Data.define(:path, :slug, :title, :kind, :front_matter)

  module_function

  # Finds every post under music/**/_posts that needs cover art generated:
  # no `media.cover` of its own, and not a track inheriting one from its
  # album. Returns an array of Post structs.
  def candidates(source_dir)
    Dir.glob(File.join(source_dir, 'music', '**', '_posts', '*.md')).filter_map do |path|
      content = File.read(path)
      next unless content =~ /\A---\n(.*?)\n---\n/m

      front_matter = YAML.safe_load(::Regexp.last_match(1), permitted_classes: [Date, Time, Symbol], aliases: true)
      next if front_matter.dig('media', 'cover') # already has its own cover
      next if front_matter.dig('album', 'slug') # inherits cover art from its album

      relative = path.sub("#{source_dir}/", '')
      slug = File.basename(path, '.md').sub(/\A\d{4}-\d{2}-\d{2}-/, '')
      kind = relative.start_with?('music/legacy/') ? :legacy : :bitbear

      Post.new(path: path, slug: slug, title: front_matter['title'], kind: kind, front_matter: front_matter)
    end
  end

  # Generates cover art (if missing on disk) and front matter (if missing)
  # for every candidate post. Returns the list of slugs it generated image
  # files for (an empty array if everything was already up to date).
  def generate!(source_dir:, logger: nil)
    log = logger || Logger.new
    posts = candidates(source_dir)
    return [] if posts.empty?

    unless tools_available?
      log.warn('cover-art:', 'rsvg-convert and/or magick not found on PATH; skipping cover art generation')
      return []
    end

    FileUtils.mkdir_p(File.join(source_dir, COVERS_DIR))
    posts.filter_map { |post| generate_one!(post, source_dir: source_dir, log: log) }
  end

  # Renders the cover (if its files don't already exist) and adds the front
  # matter reference for a single candidate post. Returns its slug if a new
  # image was rendered, or nil if the image already existed.
  def generate_one!(post, source_dir:, log:)
    jpg = File.join(source_dir, COVERS_DIR, "#{post.slug}.jpg")
    jpg_2x = File.join(source_dir, COVERS_DIR, "#{post.slug}@2x.jpg")
    already_rendered = File.exist?(jpg) && File.exist?(jpg_2x)

    unless already_rendered
      log.info('cover-art:', "Generating #{post.slug}.jpg (#{post.kind}) for #{post.path}")
      render!(source_dir: source_dir, slug: post.slug, title: post.title, kind: post.kind)
    end

    add_front_matter_reference!(post)
    post.slug unless already_rendered
  end

  def tools_available?
    system('which', 'rsvg-convert', out: File::NULL, err: File::NULL) &&
      system('which', 'magick', out: File::NULL, err: File::NULL)
  end

  # Inserts `cover: <slug>.jpg` as the first key of the `media:` block, if
  # the post's front matter doesn't already reference a cover.
  def add_front_matter_reference!(post)
    content = File.read(post.path)
    return if content =~ /^\s*cover:\s/

    updated = content.sub(/^media:\n/, "media:\n  cover: #{post.slug}.jpg\n")
    File.write(post.path, updated) unless updated == content
  end

  # Renders a cover's SVG (via SvgDocument), rasterizes it to a 1080×1080
  # JPEG and a 2160×2160 @2x twin, and deletes the intermediate SVG.
  def render!(source_dir:, slug:, title:, kind:)
    svg = SvgDocument.build(source_dir: source_dir, title: title, kind: kind, seed: slug)
    svg_path = File.join(source_dir, COVERS_DIR, "#{slug}.svg")
    File.write(svg_path, svg)

    jpg = File.join(source_dir, COVERS_DIR, "#{slug}.jpg")
    jpg_2x = File.join(source_dir, COVERS_DIR, "#{slug}@2x.jpg")

    rasterize!(svg_path, jpg, SIZE)
    rasterize!(svg_path, jpg_2x, SIZE * 2)
  ensure
    File.delete(svg_path) if svg_path && File.exist?(svg_path)
  end

  def rasterize!(svg_path, jpg_path, size)
    png_path = "#{jpg_path}.png"
    system('rsvg-convert', '-w', size.to_s, '-h', size.to_s, '-o', png_path, svg_path) ||
      raise("rsvg-convert failed for #{svg_path}")
    system('magick', png_path, '-background', 'black', '-flatten', '-quality', '92', jpg_path) ||
      raise("magick failed for #{png_path}")
  ensure
    File.delete(png_path) if png_path && File.exist?(png_path)
  end

  # A tiny logger fallback so this module can run outside of Jekyll/Rake
  # (both of which pass in their own logger).
  class Logger
    def info(tag, message)
      puts "#{tag} #{message}"
    end

    # Calls Kernel.warn explicitly (not a bare `warn`) since a bare call here
    # would resolve to this same method (`self.warn`), recursing forever.
    def warn(tag, message)
      Kernel.warn "#{tag} #{message}"
    end
  end
end
