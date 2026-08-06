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
  element selectors (bare `header`, `footer`) bleeding into Pico components. Fix that by
  **re-scoping the greedy site styles to be more precise** (e.g. `header` → `header.site-header`,
  `footer` → `footer.site-footer`, plus matching classes in `_layouts/*.html`) rather than
  by layering custom overrides on top of Pico. Prefer enabling a Pico module
  (e.g. `components/card` for modal `article` styling) over hand-rolling the same rules.

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
