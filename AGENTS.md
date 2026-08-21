# AGENTS.md

Guidance for AI agents working in this repository.

## 1. Environment setup (do this first, every session)

The shell's default PATH excludes Homebrew. Its prefix depends on the Mac's
CPU — `/opt/homebrew` on Apple Silicon, `/usr/local` on Intel. Export it
before any git, gpg, or Ruby command:

```sh
BREW_PREFIX="/usr/local"; [ "$(uname -m)" = "arm64" ] && BREW_PREFIX="/opt/homebrew"
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/opt/ruby/bin:$PATH"
```

Verify: `ruby --version` (must be `4.x`, not the system `/usr/bin/ruby`
2.6.10), `git lfs version` (`3.x`), `gpg --list-secret-keys --keyid-format LONG`
(must show key `C3D5E883`).

## 2. Always work in a Git worktree — never in the primary checkout

`/Users/bitbear/Dev/bitbear.music` may be in use by other concurrent agent
sessions. Before making any change, create your own worktree and branch:

```sh
git worktree add ../bitbear.music-<agent-name> -b <agent-name>/work
```

Do all edits, builds, and commits inside that worktree. Remove it when done:
`git worktree remove ../bitbear.music-<agent-name>`.

Notes:
- `.git` (incl. the LFS object cache) is shared across worktrees; `node_modules`
  is not — either let `npm ci` run per worktree or symlink one in from
  `/Users/bitbear/Dev/bitbear.music/node_modules`.
- Use a distinct `--port` if running `jekyll serve` in more than one worktree.

## 3. Ruby & Jekyll

- Build like CI: `bundle exec rake build`. Also: `rake spec`, `rake htmlproofer`,
  `rake clean`.
- If a rebuilt `_site` page doesn't reflect your change, rule out (1) a stray
  background `jekyll serve` process racing your build (`ps aux | grep jekyll`),
  and (2) a stale cache: `rm -rf .jekyll-cache _site`.
- `rake build`'s final step runs HTML Tidy (`prettify`) to reformat output;
  requires `tidy` on PATH. `rake spec`/`htmlproofer` rebuild `_site` via
  `Jekyll::Commands::Build.process` directly and skip `prettify`.

## 4. Rubocop

- Run `bundle exec rubocop -A` before considering `_plugins/**/*.rb` work
  done — it isn't covered by `rake spec`/`rake build`.
- In-memory `Jekyll::Page` subclasses with no backing file (`TagPage`,
  `FormatPage`) legitimately skip `super` in `initialize`; disable
  `Lint/MissingSuper` locally with a comment rather than faking a file path.
- Fix `Metrics/*` cop violations by refactoring (extract helpers, data-driven
  lookup tables) instead of raising limits in `.rubocop.yml`, and prefer
  splitting an oversized module into focused files under its own directory
  over bumping `Metrics/ModuleLength`.

## 5. Node.js & Pico CSS

- Pico CSS runs in classless mode — style semantic HTML, not utility classes.
  Sass config lives in `_config.yml` / `assets/scss/bitbear.scss`
  (keep `spec/style_spec.rb` in sync with token/module changes).
- Never override Pico's own component styles (e.g. modal `dialog`/`article`).
  If Pico's output looks distorted, the cause is almost always this site's own
  greedy selectors (bare `header`, `footer`, `main h1-h6`/`p`) — rescope them
  to be more specific instead of layering overrides on Pico.
- Covers: `assets/images/covers/<slug>.jpg` (1080²) + `@2x` twin (2160²),
  generated from `covers-master/` via `rake covers:2x`; `spec/cover_spec.rb`
  enforces the pairing. A track belonging to an album has **no cover of its
  own** — it inherits the album's `media.cover` (`_layouts/post.html`).
- Missing cover art for standalone tracks is auto-generated at build time by
  `lib/cover_art_generator.rb` (`rake covers:generate` to run standalone);
  it's idempotent and requires `rsvg-convert` + `magick` on PATH, skipping
  quietly (not failing the build) if they're absent.

## 6. Content authoring (music posts)

- Never fabricate biographical/background prose. Every claim must trace to a
  real source (SoundCloud description, Demozoo credit, `FILE_ID.DIZ`, etc.) —
  paraphrase and link it. No source → keep the post minimal and factual.
- Known scener aliases — reuse the same Demozoo link, don't create new ones:
  - Miu = MAGNUS = MONOMAGNUS = Mono Magnus → `https://demozoo.org/sceners/4221/`
  - PAcMan = Waldemar Doppelzimmer = Modulo One = Anders Knatten →
    `https://demozoo.org/sceners/4306/`
  - Puma = Fulgore → `https://demozoo.org/sceners/106369/`
- Only link a greeted handle to a Demozoo scener page when the match is
  confident; leave ambiguous/generic handles as plain text.
- Fetching: `demozoo.org` blocks plain `curl` (use `webfetch`; its
  `/api/v1/productions/<id>/` JSON is a reliable structured source).
  `soundcloud.com/oembed?url=<track-url>&format=json` checks a track exists
  without hitting SoundCloud's bot wall; for full descriptions, `webfetch`
  the track page and read `<meta itemprop="description">` inside `<noscript>`.
  A production's `FILE_ID.DIZ` is usually in its scene.org release `.zip`
  rather than viewable on Demozoo directly.
- A post's layout/`categories` default from its directory under `_posts`; set
  `layout:` explicitly in front matter when a post needs a different one.
- Page URLs never have a trailing slash (`permalink: /:categories/:title` in
  `_config.yml` produces bare files) — link to `/license`, not `/license/`.
- Jekyll breaks same-date post ties by filename. Give an album an explicit
  `date: YYYY-MM-DD 01:00:00 +0000` so it sorts above its title track.
- Front matter parsed directly with `YAML.safe_load` in specs
  (`remix_kit_spec.rb`, `cover_spec.rb`) needs `permitted_classes: [Date,
  Time, Symbol], aliases: true` — check both call sites when adding new
  non-string front matter types.

## 7. Genre/format pages

- Tags (`tags: [house, dance]`, lowercase-hyphenated) synthesize pages at
  `/music/genres/<tag>/`; formats (`media.format`) at `/music/formats/<format>/`.
  A physical page at that URL (e.g. `music/genres/chip/index.md`) always wins
  over the generator's synthesized one — no front-matter marker needed.
  Covered by `spec/genre_pages_spec.rb` / `spec/format_pages_spec.rb`.
- Every place `media.format` is displayed must link to its format page
  (`/music/formats/{{ format | downcase }}/`).

## 8. JSON-LD & data gotchas

- Build JSON-LD as a Ruby `Hash` + `to_json`, not a Liquid string.
- A post is an "album" iff it has an `album` key with no nested `slug`
  (`AlbumEntry.for?`) — a track's `album` key points at its parent via `slug`.
- Use `doc.data['slug']`, not the deprecated `doc.slug`.
- Liquid Drops don't support `Hash#dig`, only `[]`.

## 9. Commit conventions

- Header ≤50 chars, plain text, no cropping — if it wouldn't fit, put the
  full sentence as the first line of the body instead. Body wrapped at 72
  chars; backtick code references in the body only.
- Amend a commit already made earlier in this branch when correcting it;
  make a new commit for new/separate content, even in the same file.
- Always `git commit -S` (signing key `C3D5E883`).

## 10. Before finishing

Commit, then `git fetch origin main && git rebase origin/main`.
</content>
