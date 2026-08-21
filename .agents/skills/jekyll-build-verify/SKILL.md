---
name: jekyll-build-verify
description: Use when building, testing, or troubleshooting this Jekyll site — running rake build/spec/htmlproofer/clean, diagnosing a rebuilt _site page that doesn't reflect a change, or setting up a Git worktree before starting work.
---

# Jekyll build & verify workflow

## Environment setup (do this first, every session)

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

## Always work in a Git worktree — never in the primary checkout

`/Users/bitbear/Dev/bitbear.music` may be in use by other concurrent agent
sessions. Before making any change, create your own worktree and branch:

```sh
git worktree add ../bitbear.music-<agent-name> -b <agent-name>/work
```

Do all edits, builds, and commits inside that worktree. Remove it when done:
`git worktree remove ../bitbear.music-<agent-name>`.

Notes:
- `.git` (incl. the LFS object cache) is shared across worktrees;
  `node_modules` is not — either let `npm ci` run per worktree or symlink one
  in from `/Users/bitbear/Dev/bitbear.music/node_modules`.
- Use a distinct `--port` if running `jekyll serve` in more than one worktree.

## Build & test commands

- Build like CI: `bundle exec rake build`. Also available: `rake spec`,
  `rake htmlproofer`, `rake clean`.
- `rake build`'s final step runs HTML Tidy (`prettify`) to reformat output;
  this requires `tidy` on PATH (`brew install tidy-html5` if missing).
  `rake spec` / `rake htmlproofer` rebuild `_site` via
  `Jekyll::Commands::Build.process` directly and **skip** `prettify`, so
  don't expect Tidy-formatted output from those.
- Run `bundle exec rubocop -A` on any `_plugins/**/*.rb` changes — it is
  **not** covered by `rake spec` or `rake build`. See the
  `rubocop-plugins-cleanup` skill for house rules on fixing violations.

## Troubleshooting a stale/wrong `_site` page

If a rebuilt `_site` page doesn't reflect your change, check both of these
before assuming the build is broken:

1. A stray background `jekyll serve` process may be racing your build and
   overwriting `_site` concurrently — check with `ps aux | grep jekyll` and
   kill it, or point your work at a different worktree/port.
2. A stale cache — clear it with `rm -rf .jekyll-cache _site` and rebuild.

## Before finishing

1. Run the appropriate `rake spec` / `rake build` / `rake htmlproofer` for
   the change you made.
2. Commit (see commit conventions below), then rebase on latest main:
   `git fetch origin main && git rebase origin/main`.

## Commit conventions

- Header ≤50 chars, plain text, no cropping — if it wouldn't fit, put the
  full sentence as the first line of the body instead. Body wrapped at 72
  chars; backtick code references in the body only.
- Amend a commit already made earlier in this branch when correcting it;
  make a new commit for new/separate content, even in the same file.
- Always `git commit -S` (signing key `C3D5E883`).
