---
name: music-metadata-verification
description: Use when verifying or auditing recorded song metadata on music posts — checking that front-matter `media.isrc` (and title/duration) match the authoritative streaming catalogue before or after adding/editing a track, or when a post's ISRC looks suspect.
---

# Music metadata verification

Checks that the metadata recorded on track posts matches what the streaming
catalogues actually publish. ISRC is the anchor: a wrong ISRC silently emits
a bogus `isrcCode` in the MusicRecording JSON-LD and pollutes
`spec/json_ld_spec.rb`.

## Run the checker

From the repo root, with Homebrew's Ruby on PATH:

```sh
BREW_PREFIX="/usr/local"; [ "$(uname -m)" = "arm64" ] && BREW_PREFIX="/opt/homebrew"
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/opt/ruby/bin:$PATH"

ruby .agents/skills/music-metadata-verification/verify_music_metadata.rb
```

It exits non-zero on any hard failure. Read the summary line:

- `ok` — ISRC confirmed by Tidal.
- `FAIL` — invalid ISRC shape, or a recorded ISRC that disagrees with the
  catalogue. Fix the front matter.
- `WARN` — cosmetic title/length difference or a post that has no Tidal
  link to confirm against. Warnings don't fail the run but should be eyeballed.

The two files are `verify_music_metadata.rb` (the audit) and
`streaming_catalog.rb` (catalogue access/parsing); keep both.

## What "correct" can mean for an ISRC

An ISRC (`CC-XXX-YY-NNNNN`) has **no check digit**, so it cannot be proven
valid by arithmetic. A 12-character code is correct only if the registrant
actually assigned it to that recording — which requires looking it up.

Two tiers of checking, both done by the script:

1. **Structural** — `^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$`: two-letter country/
   registrant prefix, three alphanumeric registrant chars, then a two-digit
   year and five-digit designation (so the last seven characters are always
   digits). This catches typos in shape but not a wrong-but-well-formed code.
2. **Catalogue cross-check** — compare the recorded value to the ISRC the
   service publishes for the same recording. This is the only reliable check.

## Reliable sources

| Source | Endpoint | Notes |
| --- | --- | --- |
| **Tidal** (primary) | `https://tidal.com/track/<id>` page JSON-LD | Every distributed track post links to its Tidal track page; the `MusicRecording` JSON-LD carries `isrcCode`, `name`, `duration`. No token. |
| **Deezer** (secondary) | `https://api.deezer.com/track/isrc:<ISRC>` | Independent cross-check. Does **not** carry every release — a miss is not a failure. |

Not usable for these tracks (verified while writing this skill):

- **iTunes lookup API** no longer returns `isrc`.
- **MusicBrainz** has no coverage for this catalogue (`/ws/2/isrc/<ISRC>`
  returns "Not Found").
- **Odesli/song.link** resolves nothing for these ISRCs.
- **Apple Music** exposes no public ISRC field.

The Tidal page JSON-LD is the key trick — spot-check one manually with:

```sh
curl -s -A "Mozilla/5.0" https://tidal.com/track/<id> \
  | grep -o '"isrcCode":"[^"]*"'
```

## Workflow when adding/editing a track

1. Source the ISRC from a real release, per the `music-post-authoring` skill
   (Deezer track API, or the Tidal JSON-LD above). Never fabricate one.
2. Add the Tidal track link to `links:` (all distributed tracks have one) so
   the checker can confirm the value later.
3. Run the checker. Investigate every `FAIL` before committing.
4. For a new post, also update the `expected` map in
   `spec/json_ld_spec.rb`, then run `rake spec`.

## Pitfalls

- A `WARN` on title is usually a representation difference, not an error —
  e.g. `"Modulo One - The Touch (Bitbear Remix)"` vs the catalogue's
  `"The Touch (feat. Bitbear) (Bitbear Remix)"`. Confirm manually that it is
  the same recording; don't "fix" the post title to match the catalogue.
- A `WARN` on length is a `m:ss` vs ISO-8601 rounding difference; one second
  of drift is tolerated.
- A missing Tidal link means no confirmation is possible — add the link
  rather than trusting the value.
- Deezer's ISRC endpoint returns `{"error": ...}` for anything it doesn't
  carry; that is expected for tracker-era releases, not a failure.

## Scope

The checker currently validates ISRC (hard) plus title and duration (soft).
Extend `verify_*` methods in `verify_music_metadata.rb` for other fields —
Tidal JSON-LD also exposes `byArtist`, `inAlbum` and, on the album page,
release date — but keep ISRC mismatches as hard failures.
