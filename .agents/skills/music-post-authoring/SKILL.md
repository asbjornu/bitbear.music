---
name: music-post-authoring
description: Use when adding, editing, or reviewing a music post (track or album) under music/_posts — sourcing biographical/background claims, linking scener aliases to Demozoo, fetching SoundCloud/Demozoo data, setting front matter (dates, layout, categories, slug), and permalink conventions.
---

# Music post authoring

## Sourcing rule (non-negotiable)

Never fabricate biographical or background prose. Every factual claim must
trace to a real source — a SoundCloud track description, a Demozoo credit, a
`FILE_ID.DIZ`, a scene.org release note, etc. Paraphrase the source and link
it. **If there is no source, keep the post minimal and factual** rather than
inventing color.

## Fetching sources

- `demozoo.org` blocks plain `curl`/bot requests — always use the `webfetch`
  tool, never raw `curl`, against Demozoo pages.
- Demozoo's `/api/v1/productions/<id>/` JSON endpoint is a reliable
  structured source for a production's credits, release date, and files —
  prefer it over scraping the HTML page when you just need facts.
- `https://soundcloud.com/oembed?url=<track-url>&format=json` is a cheap way
  to confirm a SoundCloud track exists without tripping SoundCloud's bot wall.
- For a track's full description text, `webfetch` the track page itself and
  read the `<meta itemprop="description">` tag inside the `<noscript>` block
  (SoundCloud renders the real description there for crawlers).
- A production's `FILE_ID.DIZ` is usually bundled inside its scene.org
  release `.zip`, not viewable directly on the Demozoo page — fetch the zip
  from the scene.org mirror linked from the Demozoo production page if you
  need it.

## Known scener aliases

Reuse the **same** Demozoo scener link for these known aliases — do not
create a second/duplicate link for a different spelling of the same person:

| Aliases | Demozoo link |
| --- | --- |
| Miu = MAGNUS = MONOMAGNUS = Mono Magnus | `https://demozoo.org/sceners/4221/` |
| PAcMan = Waldemar Doppelzimmer = Modulo One = Anders Knatten | `https://demozoo.org/sceners/4306/` |
| Puma = Fulgore | `https://demozoo.org/sceners/106369/` |

Only link a greeted/credited handle to a Demozoo scener page when the match
is confident. Leave ambiguous or generic-sounding handles as plain text
rather than guessing at a scener page.

## Front matter conventions

- A post's layout and `categories` default from its directory under
  `_posts` — only set `layout:` explicitly in front matter when a post needs
  something different from that default.
- Page URLs never have a trailing slash (`permalink: /:categories/:title` in
  `_config.yml` produces bare files) — link to `/license`, never `/license/`,
  and the same applies to any post/page URL you reference.
- Jekyll breaks same-date post ties by filename. When an album and its title
  track share a date, give the **album** an explicit
  `date: YYYY-MM-DD 01:00:00 +0000` so it sorts above the track.
- A post is an "album" iff it has an `album` key with **no** nested `slug`
  key (see `AlbumEntry.for?`); a track's `album` key instead points at its
  parent album via `slug`. Get this key shape right or genre/format/JSON-LD
  logic that depends on `AlbumEntry.for?` will misclassify the post.
- A track belonging to an album has **no cover of its own** in front matter —
  it inherits the album's `media.cover` at render time
  (`_layouts/post.html`). Don't add a redundant `media.cover` to a track post.
- `media.isrc` (string) on a track post emits schema.org `isrcCode` in the
  MusicRecording JSON-LD. Only set it when the ISRC is sourced from a real
  release (Deezer's `api.deezer.com/track/<id>` exposes `isrc`; the iTunes
  lookup API no longer does). Omit it for tracker modules / Bandcamp-only
  tracks that were never assigned an ISRC — never fabricate one.
- If you add a new non-string front-matter type (beyond what's already
  handled), check `YAML.safe_load` call sites in specs
  (`remix_kit_spec.rb`, `cover_spec.rb`) — they need
  `permitted_classes: [Date, Time, Symbol], aliases: true` or parsing breaks.

## Tags and formats

- Tags (e.g. `tags: [house, dance]`) must be lowercase-hyphenated; they
  synthesize genre pages at `/music/genres/<tag>/`.
- `media.format` synthesizes a format page at `/music/formats/<format>/`.
  Every place `media.format` is displayed in a template must link to
  `/music/formats/{{ format | downcase }}/`.
- A physical page at a genre/format URL (e.g. `music/genres/chip/index.md`)
  always wins over the generator's synthesized page — no front-matter marker
  needed to opt out of the generator.

## JSON-LD gotchas

- Build JSON-LD as a Ruby `Hash` + `to_json`, never assemble it as a Liquid
  string — string-built JSON is fragile against quoting/escaping bugs.
- Use `doc.data['slug']`, not the deprecated `doc.slug`.
- Liquid Drops don't support `Hash#dig`, only `[]` — don't reach for `dig` in
  templates that operate on post/page drops.

## Verifying your work

After adding or editing a post, run the relevant specs before considering the
change done — see the `jekyll-build-verify` skill for the full build/test
workflow (`rake spec`, `rake htmlproofer`, cover pairing checks, etc.).
