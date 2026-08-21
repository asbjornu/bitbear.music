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
- For the full build/test/troubleshooting workflow (stale `_site`, worktree
  setup, Tidy prettification), use the `jekyll-build-verify` skill.

## 4. Rubocop

- Run `bundle exec rubocop -A` before considering `_plugins/**/*.rb` work
  done — it isn't covered by `rake spec` or `rake build`. For house rules on
  fixing violations (`Lint/MissingSuper`, `Metrics/*`), use the
  `rubocop-plugins-cleanup` skill.

## 5. Node.js & Pico CSS

- Pico CSS runs in classless mode — style semantic HTML, not utility classes.
  Sass config lives in `_config.yml` / `assets/scss/bitbear.scss`
  (keep `spec/style_spec.rb` in sync with token/module changes).
- Never override Pico's own component styles (e.g. modal `dialog`/`article`).
  If Pico's output looks distorted, the cause is almost always this site's own
  greedy selectors (bare `header`, `footer`, `main h1-h6`/`p`) — rescope them
  to be more specific instead of layering overrides on Pico.
- For cover art (generation, `@2x` pairing, auto-generation fallback), use
  the `cover-art-workflow` skill.

## 6. Content authoring (music posts)

For sourcing rules, scener alias links, front-matter conventions, genre/format
pages, and JSON-LD gotchas when adding or editing a post under `music/_posts`,
use the `music-post-authoring` skill.

## 7. Commit conventions

- Header ≤50 chars, plain text, no cropping — if it wouldn't fit, put the
  full sentence as the first line of the body instead. Body wrapped at 72
  chars; backtick code references in the body only.
- Amend a commit already made earlier in this branch when correcting it;
  make a new commit for new/separate content, even in the same file.
- Always `git commit -S` (signing key `C3D5E883`).

## 8. Before finishing

Commit, then `git fetch origin main && git rebase origin/main`.
</content>
