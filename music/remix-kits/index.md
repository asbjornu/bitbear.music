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

{% assign kits = site.remix_kits | sort: 'title' %}
{% if kits.size > 0 %}
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
