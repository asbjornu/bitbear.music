---
title: Bitbear's Remix Kits
description: |
    Remix kits are downloadable stems, projects and assets for a selection of
    Bitbear's tracks, released for anyone who wants to remix, sample or study
    how the track was made.
---

{:.jumbotron}
Remix kits bundle up the stems, project files or other production assets
behind a track so you can remix, sample or study how it was made. Each kit
is released under the same [CC BY-NC 4.0 license][cc-by-nc] as the rest of
Bitbear's music.

## Why remix?

First of all, remixing is a great way to learn new production techniques,
put your own spin on a track, and share your creativity with the world.

Remixes made from these kits are always welcome, and any remix I like
gets the following treatment:

- **Mixing feedback.** I'll listen closely and share notes on the mix,
  arrangement and mastering, whatever I think will help improve the track.
- **Distribution to all streaming platforms, at my cost.** I'll release
  the remix wherever Bitbear's own music is available, and I cover the
  distribution costs myself.
- **50/50 revenue sharing.** Any revenue the remix earns is split evenly
  between me and the remixer.

None of this is required to make or share a remix under [the
license][license], it's simply what I offer for remixes I want to help
bring to a wider audience.

{% assign kits = site.remix_kits | sort: 'title' %}
{% if kits.size > 0 %}

## Remix kits

  <table class="songs">
    <thead>
      <tr>
        <th>Track</th>
        <th class="kind">Format</th>
        <th>Remix kit</th>
      </tr>
    </thead>
    <tbody>
      {% for kit in kits %}
        {% assign candidates = site.posts | where: 'slug', kit.slug %}
        {% assign track = nil %}
        {% for candidate in candidates %}
          {% if candidate.media.format %}
            {% assign track = candidate %}
          {% endif %}
        {% endfor %}
        {% unless track %}
          {% assign track = candidates.first %}
        {% endunless %}
        <tr>
          <td>
            {% if track %}
              <a href="{{ track.url }}">{{ track.title }}</a>
            {% else %}
              {{ kit.title }}
            {% endif %}
          </td>
          <td class="kind">
            {% if track.media.format %}
              {% assign format_title = track.media.format | format_description %}
              <a href="/music/formats/{{ track.media.format | downcase }}/" aria-description="{{ format_title }}" data-tooltip="{{ format_title }}">{{ track.media.format }}</a>
            {% endif %}
          </td>
          <td>
            <a href="{{ kit.url }}">View kit</a>
          </td>
        </tr>
      {% endfor %}
    </tbody>
  </table>
{% else %}
  <p>No remix kits found.</p>
{% endif %}

[cc-by-nc]: https://creativecommons.org/licenses/by-nc/4.0/
[license]: /license
