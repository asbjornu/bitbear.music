---
name: cover-art-workflow
description: Use when adding, generating, or troubleshooting cover art for a music post — covers-master/ sources, rake covers:2x, the @2x pairing enforced by spec/cover_spec.rb, or the auto-generation fallback in lib/cover_art_generator.rb.
---

# Cover art workflow

## Where covers live

- Final covers: `assets/images/covers/<slug>.jpg` at 1080×1080, plus an
  `@2x` twin at 2160×2160 (`assets/images/covers/<slug>@2x.jpg`).
- `spec/cover_spec.rb` enforces that every base cover has its `@2x` twin —
  a missing or orphaned twin fails the spec suite.
- A track post belonging to an album has **no cover of its own**. It
  inherits the album's `media.cover` at render time via `_layouts/post.html`.
  Do not add a redundant `media.cover` to a track's front matter, and don't
  expect a standalone cover file for a track that belongs to an album.

## Generating the @2x twin from a master

Git-ignored master source images live in `covers-master/` (not committed).
Given a master image there:

```sh
rake covers:2x
```

This scans `assets/images/covers/*.jpg` (skipping existing `@2x.jpg` files),
finds the matching master by basename in `covers-master/`, and generates the
2160×2160 twin via `sips` — skipping any twin that's already newer than its
master. If no master file with a matching basename exists, that cover is
silently skipped.

## Auto-generation for standalone tracks with no cover

If a standalone track post doesn't have any cover art at all, the build
auto-generates one at build time via `lib/cover_art_generator.rb`:

```sh
rake covers:generate
```

- Idempotent — safe to re-run; only generates for tracks that don't already
  have cover art.
- Requires `rsvg-convert` and `magick` (ImageMagick) on PATH. If either is
  missing, it skips generation **quietly** rather than failing the build —
  don't assume a missing cover means the generator is broken; check for the
  binaries first.
- This path only applies to **standalone tracks** (no album). Album tracks
  never get a generated cover of their own — see the inheritance rule above.

## Adding a new cover manually

1. Drop the source image in `covers-master/` (basename matching the post's
   `slug`, any common extension).
2. Produce the 1080² base JPEG yourself (or via your own tooling) at
   `assets/images/covers/<slug>.jpg`.
3. Run `rake covers:2x` to generate the paired `@2x` twin.
4. Run `bundle exec rspec spec/cover_spec.rb` to confirm the pairing check
   passes.
