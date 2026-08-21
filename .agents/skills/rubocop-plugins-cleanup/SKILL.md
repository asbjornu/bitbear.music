---
name: rubocop-plugins-cleanup
description: Use when running or fixing bundle exec rubocop -A violations in _plugins/**/*.rb — house rules for Lint/MissingSuper on in-memory Jekyll::Page subclasses and for resolving Metrics/* cop violations without raising limits in .rubocop.yml.
---

# Rubocop cleanup for `_plugins`

## When to run this

Run `bundle exec rubocop -A` before considering any `_plugins/**/*.rb` change
done. This is **not** covered by `rake spec` or `rake build` — those tasks
will pass even with outstanding Rubocop violations, so don't rely on them as
a signal here.

## `Lint/MissingSuper` on in-memory page subclasses

In-memory `Jekyll::Page` subclasses that have no backing file on disk (e.g.
`TagPage`, `FormatPage`) legitimately skip calling `super` in `initialize`,
because the standard `Jekyll::Page#initialize` expects a real file to read.

For these, disable the cop locally with a comment explaining why, rather
than fabricating a fake file path just to satisfy `super`:

```ruby
class TagPage < Jekyll::Page
  # rubocop:disable Lint/MissingSuper -- no backing file to read; this page
  # is generated entirely in memory.
  def initialize(site, tag)
    ...
  end
  # rubocop:enable Lint/MissingSuper
end
```

## `Metrics/*` violations

Fix `Metrics/*` cop violations (`MethodLength`, `ClassLength`,
`ModuleLength`, `AbcSize`, etc.) by **refactoring**, not by raising the limit
in `.rubocop.yml`:

- Extract private helper methods for distinct steps within a long method.
- Replace long `case`/`if` chains with data-driven lookup tables (a `Hash`
  constant mapping input to behavior/value) where the branches are really
  just data.
- If a whole module is oversized (`Metrics/ModuleLength`), prefer **splitting
  it into focused files under its own directory** (e.g.
  `lib/foo/bar.rb`, `lib/foo/baz.rb` under a `Foo` namespace) over bumping
  the `ModuleLength` limit in `.rubocop.yml`.

Only touch `.rubocop.yml` limits as an absolute last resort, and never as the
first fix attempted for a new violation.
