# AGENTS.md

Guidance for AI agents working in this repository.

## Environment setup (REQUIRED first step)

The agent shell runs with a minimal PATH (`/usr/bin:/bin:/usr/sbin:/sbin`) that does
**not** include Homebrew. Every tool described below lives in Homebrew and is invisible
until the PATH is exported. Run this preamble at the start of every session and before
any command that touches git, gpg, or Ruby:

```sh
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/ruby/bin:$PATH"
```

Never probe for tools with bare names (e.g. `git lfs version`, `gpg --version`,
`ruby --version`) until this PATH is in effect, or you will falsely conclude they are
missing.

## Ruby & Jekyll

- The Gemfile requires Ruby `>= 3.2`. The system Ruby at `/usr/bin/ruby` is 2.6.10 and
  **must never be used**.
- Use the Homebrew Ruby at `/opt/homebrew/opt/ruby/bin/ruby` (currently 4.0.6).
- Build the site exactly as CI does (see `.github/workflows/_build.yml`):
  ```sh
  bundle exec rake build
  ```
  Other valid tasks: `bundle exec rake spec`, `bundle exec rake htmlproofer`,
  `bundle exec rake clean`.
- Self-check: `ruby --version` must report `4.x`.
- **Stale build artifacts can make a correct change look broken**: if a rebuilt
  `_site` page doesn't reflect a source/layout/`_config.yml` change you just made
  (e.g. an old layout, old wording, or a link that shouldn't exist), don't assume
  your change is wrong before ruling out two culprits:
  1. A leftover background `jekyll serve`/`--watch` process from earlier in the
     session, silently regenerating `_site` from its own in-memory state whenever
     it notices a filesystem change, racing with and clobbering your foreground
     `rake build`/`rake spec`/`rake htmlproofer` runs. Check with
     `ps aux | grep jekyll` and `kill` any stray `jekyll serve` process before
     trusting a build.
  2. A stale `.jekyll-cache/` (or `.jekyll-metadata`) directory. When debugging
     generator/layout/defaults behavior, wipe both before rebuilding:
     `rm -rf .jekyll-cache _site`.
  Note `spec/spec_helper.rb`'s `before(:suite)` hook rebuilds `_site` itself
  (via `Jekyll::Commands::Build.process`), so `bundle exec rake spec` and
  `bundle exec rake htmlproofer` each implicitly trigger a rebuild — a stray
  `jekyll serve` process can still race with those, too.

## Rubocop

- Run `bundle exec rubocop` (add `-A` to auto-correct safe/correctable
  offenses) before considering `_plugins/**/*.rb` work done; it's not part of
  the `rake` tasks above and won't be caught by `rake spec`/`rake build`.
- **Generated in-memory `Jekyll::Page` subclasses trigger
  `Lint/MissingSuper`** (e.g. `TagPage`/`FormatPage` in
  `_plugins/tag_page_generator.rb`/`_plugins/format_pages.rb`).
  `Jekyll::Page#initialize` calls `read_yaml` to read front matter off disk,
  but these pages are synthesized purely in memory and have no backing
  file — calling `super` would need a nonexistent file path (Jekyll would
  log a benign-but-noisy warning per generated page rather than fail, since
  `strict_front_matter` defaults to off, but it's still wrong). The
  established fix here is a targeted
  `# rubocop:disable Lint/MissingSuper` / `# rubocop:enable` pair around
  `initialize`, with a one-line comment explaining why — not calling `super`
  with a dummy path. This mirrors how `jekyll-archives`' own
  `Archive < Jekyll::Page` class handles the identical situation upstream.
- **Prefer refactoring over raising `Metrics` limits.** When a `Metrics/*`
  cop (AbcSize, CyclomaticComplexity, MethodLength, PerceivedComplexity) trips
  on a filter in `_plugins/liquid_filters/*.rb`, extract private helper
  methods (or a data-driven lookup table, as `LinkFilters::LINK_BRAND_PATTERNS`
  replaced a long `case`/`when` in `link_brand`) rather than bumping the
  limit in `.rubocop.yml`. `Metrics/MethodLength` already has one deliberate,
  repo-wide override (`Max: 20`) — that's the exception, not the pattern to
  follow per-offense.
- **`Metrics/ModuleLength` was deliberately rejected as a config override**:
  a from-scratch fix bumped `Max` in `.rubocop.yml` when
  `_plugins/liquid_filters.rb` grew past 100 lines, but the actual fix
  (reverted) was to split the single module into focused files under
  `_plugins/liquid_filters/` (`collection_filters.rb`, `link_filters.rb`,
  `youtube_filters.rb`, `format_filters.rb`, `remix_kit_filters.rb`), each
  its own `Jekyll::*Filters` module independently registered via
  `Liquid::Template.register_filter`. Jekyll's plugin loader globs
  `_plugins/**/*.rb` recursively, so nested files need no manual `require`
  wiring. Liquid mixes every registered filter module into the same
  `Strainer` instance, so a public method in one file (e.g.
  `YoutubeFilters#youtube_id` calling `LinkFilters#link_url`) resolves fine
  across module boundaries at runtime — split by cohesive concern freely,
  cross-file calls aren't a concern. `spec/liquid_filters_spec.rb` mixes all
  five modules into one anonymous test class for the same reason.

## Node.js & Pico CSS

- Pico CSS (`@picocss/pico` 2.x) IS the styling framework, used in **classless mode** —
  its compiled rules style bare semantic HTML elements (`button`, `a[role=button]`,
  `table`, `body`, etc.) directly, so layouts should rely on semantic markup rather than
  Pico utility classes. Only your own site-specific classes/ids (e.g. `.iterator`,
  `#cover`) are added on top; site overrides customize Pico's tokens, they don't replace
  its role.
- It is pulled from `node_modules` via npm and compiled into the stylesheet, not served
  externally:
  - The Sass load path is set in `_config.yml`; the theme overrides (`--pico-*`) and the
    enabled-module list live in `assets/scss/bitbear.scss`.
  - `_plugins/npm_deps.rb` auto-runs `npm ci` at `:after_init` when `node_modules` is
    missing, so a fresh build failure usually means Node v20+ / `npm` were not available.
- When changing design tokens or enabled modules, update `assets/scss/bitbear.scss` and
  keep `spec/style_spec.rb` expectations in sync.
- **Never restyle or override Pico's own component styles** (e.g. the modal's `dialog`,
  `> article`, `> header`, close-button rules). If aggregation looks right but Pico's
  built-in output is being distorted, the cause is almost always the site's own greedy
  element selectors (bare `header`, `footer`, `main h1-h6`/`p`) bleeding into Pico
  components and other markup. Fix that by **re-scoping the greedy styles to be more
  precise** with direct parent/child selectors (e.g. `header` → `body > header`,
  `footer` → `section.footer footer`) rather than by adding chrome classes or layering
  custom overrides on top of Pico. Prefer enabling a Pico module
  (e.g. `components/card` for modal `article` styling) over hand-rolling the same rules.
- The cover-art enlargement is a pure-CSS `:target` modal (no JS to open/close): its
  static HTML lives in the `_includes/cover.html` template as a Pico `<dialog>` with the
  `#cover-art` id, opened by `#cover-art:target { display: flex }` (Pico's own
  `dialog:not([open]) { display: none }` keeps it closed by default). Only the inner
  `article` is sized to hug the cover art (`padding: 0`, `width: auto`); everything else
  is Pico's `components/modal` + `components/card` output. Reposition or scope it as
  `#cover-art`, not by overriding Pico's `dialog`.
- Cover thumbnails live at `assets/images/covers/<name>.jpg` (1080×1080; LFS-tracked)
  with a high-res twin at `assets/images/covers/<name>@2x.jpg` (2160×2160).
  `_includes/cover.html` derives the twin purely by filename
  (`| replace: '.jpg', '@2x.jpg'`) and always emits a `srcset` (`1080w`, `2160w`) on the
  modal `<img>` — there is no runtime existence check. The invariant is instead enforced
  in CI by `spec/cover_spec.rb`, which fails when a cover lacks its `@2x` twin or a
  post's front matter references a cover file that does not exist. Generate the twins
  from git-ignored 2160² masters with `bundle exec rake covers:2x` (see `Rakefile`);
  masters live in the repo-root `covers-master/` directory.

## Content authoring (music posts)

- **Never fabricate biographical or background prose** for a track, release, or person.
  Every descriptive claim in a post must come from an actual source (a SoundCloud track
  description, a Demozoo production/credit, a FILE_ID.DIZ info file, etc.) — paraphrase
  and link the source rather than inventing narrative filler. If no real source exists,
  keep the post factual and minimal (front matter + release links) instead of guessing.
- **Known scener aliases** — always reuse the same Demozoo scener link for the same
  person rather than creating inconsistent ones per post:
  - Miu = MAGNUS = MONOMAGNUS = Mono Magnus → `https://demozoo.org/sceners/4221/`
  - PAcMan = Waldemar Doppelzimmer = Modulo One = Anders Knatten →
    `https://demozoo.org/sceners/4306/`
  - Puma = Fulgore → `https://demozoo.org/sceners/106369/`
- **Greeting-list linking convention**: only link a greeted handle to a Demozoo scener
  page when there's a confident match; leave ambiguous/generic handles (e.g. "Trigger",
  single common English words) as plain text rather than risk linking to the wrong
  person. Reuse resolved link mappings across posts once established.
- **Fetching gotchas**:
  - `demozoo.org` blocks plain `curl` (Cloudflare challenge) but works fine through the
    `webfetch` tool. Its `/api/v1/productions/<id>/` JSON endpoint is a reliable
    structured source for a production's authors, credits, dates, and external links.
  - `soundcloud.com` HTML pages are inconsistently bot-walled; `curl`ing
    `https://soundcloud.com/oembed?url=<track-url>&format=json` is a reliable way to
    check whether a track exists and to grab its title/thumbnail without hitting the
    bot wall. For full (untruncated) track descriptions, fetch the track page via
    `webfetch` and read the `<meta itemprop="description">` inside the `<noscript>`
    block, not the truncated `og:description`.
  - Demozoo's "Info file" (FILE_ID.DIZ) viewer requires login, but the same file is
    almost always bundled in the linked scene.org release `.zip` — download it and
    `unzip -p` the `.zip` instead of trying to view it on Demozoo directly.
- **Layout vs. directory-derived categories**: a post's `main` CSS class and Jekyll
  `categories` are auto-derived from its directory nesting under `_posts` (e.g.
  `music/albums/_posts` → `music albums`). If a post needs a different layout than its
  directory implies (e.g. an "album" page filed under `music/legacy/`), set `layout:`
  explicitly in front matter — don't assume CSS scoped to `main.<category>` will apply,
  and don't assume `site.categories['<x>']` listings will include/exclude it as expected.
- **No trailing slash on page URLs**: the site-wide `permalink: /:categories/:title`
  pattern (in `_config.yml`) produces a bare file per page (e.g. `license.md` →
  `/license.html`, served at `/license`), not a directory with an `index.html`. Linking
  to `/license/` (with a trailing slash) 404s — always link to `/license` without one.
  This applies to any root-level or top-level page using the default permalink, not just
  `/license`.
- **Same-day post ordering**: Jekyll breaks ties between same-date posts by filename,
  not insertion order. When an album and one of its tracks share a release date, give
  the album an explicit `date: YYYY-MM-DD 01:00:00 +0000` (an hour past midnight) so it
  reliably sorts above the track in `song_table.html` — don't rely on filename
  alphabetical tie-break.
- **Spec YAML safe-loading**: some specs (`remix_kit_spec.rb`, `cover_spec.rb`) parse
  front matter directly with `YAML.safe_load`. Adding a non-string front matter value
  (e.g. an explicit `date:`) can break specs that don't permit that class. When adding
  new front matter types, grep `spec/*.rb` for `YAML.safe_load` and make sure every call
  site includes `permitted_classes: [Date, Time, Symbol], aliases: true`.

## Genre/tag pages

- Every track post is tagged via a `tags:` front matter array (e.g.
  `tags: [house, dance]`) with lowercase, hyphenated genre/style slugs (e.g.
  `drum-and-bass`, `oldskool`). This is Jekyll's built-in tags mechanism
  (`site.tags`), not a custom concept — a single-tag post may alternatively use
  the singular `tag: <name>` key (Jekyll pluralizes it automatically), but
  prefer the plural array form once a post has more than one tag.
- `_plugins/tag_page_generator.rb` (`TagPageGenerator`) synthesizes a page at
  `/music/genres/<tag>/` for every tag in `site.tags`, rendered with the `tag`
  layout (`_layouts/tag.html`), which lists all posts carrying that tag via the
  same `song_year_nav.html`/`song_table.html` includes used elsewhere.
- **Physical pages take precedence over synthesized ones**: before generating
  a page for a tag, the generator checks whether a real page already resolves
  to that same `/music/genres/<tag>/` URL (via `site.pages.map(&:url)`) and
  skips generation if so. This is how `music/genres/chip/index.md` (Bitbear's
  hand-written chiptunes page, with its own prose) overrides the otherwise
  auto-generated `chip` genre page — there is no special front-matter marker
  for this, it's purely a URL collision check, so **any physical page placed
  at `music/genres/<tag>/index.md` automatically takes over that tag's page**.
- The `tag` layout itself is applied via a `_config.yml` front-matter default
  scope (`path: music/genres` → `layout: tag`), **not** hard-coded in
  `music/genres/chip/index.md`'s own front matter — keep it that way so every
  page under `music/genres/` (physical or synthesized) gets the layout
  uniformly. `_layouts/tag.html` renders `{{ content }}` when a physical page
  has a body, falling back to a generic "Bitbear's `<tag>` tracks" blurb when
  it doesn't (synthesized pages have no body) — don't reintroduce a hard-coded
  heading like `Bitbear's {{ page.title }} tracks` in the layout, since a
  physical page's `title` is already a complete phrase (e.g. "Bitbear's
  Chiptunes") and would get wrapped/duplicated; instead, generator-produced
  titles (`TagPage#initialize` in `_plugins/tag_page_generator.rb`) are
  already complete strings, and the layout just renders `page.title` as-is.
- `_includes/genres_table_row.html` renders each post's `page.tags` as links
  to `/music/genres/<tag>/` in a "Genres" row in the track page's media table
  (wired into `_layouts/post.html`).
- `spec/genre_pages_spec.rb` covers this: every tag has a generated page, the
  `chip` override isn't duplicated, and the "Genres" row links correctly.
  When adding new tags, no new spec examples need writing — the spec derives
  its list of tags straight from post front matter. Tags used only by an
  unpublished post (`published: false`) are excluded from that derivation,
  matching Jekyll's own exclusion of unpublished posts from `site.tags` (no
  genre page is generated for a tag with no published posts).

## Format pages

- The same physical-page-overrides-synthesized-page pattern used for genres
  is mirrored for track formats (`page.media.format`, e.g. `MOD`, `S3M`,
  `IT`, `FST`, `XRNS`) via `_plugins/format_pages.rb`
  (`FormatPageGenerator`/`FormatPage`) and `_layouts/format.html`, at
  `/music/formats/<format>/` (lowercased in the URL; the `format:` front
  matter/data value itself stays uppercase to match `media.format` values
  verbatim). Unlike tags, Jekyll has no built-in `site.tags`-equivalent
  grouping for arbitrary front matter fields, so the generator computes and
  exposes the format → posts mapping itself as `site.data['formats']`
  (`_layouts/format.html` reads it as `site.data.formats[page.format]`).
- Every format currently in use (`MOD`, `S3M`, `IT`, `FST`, `XRNS`) has a
  **hand-written physical page** at `music/formats/<format>/index.md`
  explaining the format's history and sourcing, per this feature's
  requirement that every format page explains the format — there is
  currently no format left to the generic auto-generated fallback. If a new
  format value is introduced without a matching physical page, the generator
  will still synthesize a minimal page for it automatically.
- Every place a format abbreviation is displayed is a link to its format
  page: the "Format" row in the track media table (`_layouts/post.html`),
  the `(MOD)`/`(IT)`/etc. suffix in the "Kind" column of every song table row
  (`_includes/song_table_row.html`), and the remix kit page's "Format" row
  (`_layouts/remix_kit.html`). If a new spot renders `media.format` in the
  future, link it the same way (`/music/formats/{{ format | downcase }}/`)
  rather than rendering it as plain/abbr-only text.
- `spec/format_pages_spec.rb` covers this the same way
  `spec/genre_pages_spec.rb` covers genres.

## JSON-LD structured data

- The site's JSON-LD (`_plugins/json_ld_tag.rb`, `_plugins/json_ld/`) is built
  as a Ruby `Hash` and serialized with `to_json`, not assembled as a Liquid
  string — keep doing that for any future structured data.
- **A post is an "album" if it has an `album` key with no nested `slug`**
  (`AlbumEntry.for?` in `album_entry.rb`) — not if `layout == 'album'`. A
  track post also has an `album` key, but pointing *at* its parent via
  `slug`, so `slug`'s presence/absence is the real distinguisher.
  Album and track posts can share the same filename slug (e.g. an album and
  its title track), so any `site.posts.docs.find` by slug must also check
  `AlbumEntry.for?`, or it may match the track instead of its album.
- Use `doc.data['slug']`, not `doc.slug` — the latter is deprecated and logs
  a noisy warning on every build.
- Liquid Drops (`page` in a tag/template) don't support `Hash#dig`, only
  `[]` — `page.dig('media', 'length')` raises `NoMethodError`.
- Jekyll's and this repo's Liquid filter modules are plain Ruby modules —
  `include` them directly into a plugin class (set `@context = context`
  first) to reuse filters like `absolute_url` outside of Liquid.

## Git LFS

- Git LFS **is installed** (`/opt/homebrew/bin/git-lfs`, v3.x). Any "not installed"
  detection is a PATH artifact.
- Large files (`.flac`, `.mp3`, `.wav`, `.zip`, cover images) are LFS-tracked per
  `.gitattributes`. Use `git lfs track`, `git lfs ls-files`, and `git lfs migrate`
  normally after exporting PATH.
- Verify with: `git lfs version`.

## GPG-signed commits

- Always sign commits with `git commit -S`. `commit.gpgsign=true` is set globally;
  pass `-S` explicitly regardless.
- Signing key: `C3D5E883` (Asbjørn Ulsberg <asbjorn@ulsberg.no>).
- `gpg.program=gpg` resolves to `/opt/homebrew/bin/gpg` once Homebrew is on PATH.
- Verify the key is available with: `gpg --list-secret-keys --keyid-format LONG`.

## Quick self-check

Run before any commit or build:

```sh
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/ruby/bin:$PATH"
ruby --version              # must be 4.x, not 2.6
git lfs version             # must print git-lfs/3.x
gpg --list-secret-keys --keyid-format LONG   # must show C3D5E883
```
