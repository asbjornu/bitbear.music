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
