---
title: Music
description: |
    Bitbear's music is licensed under the CC BY-NC 4.0 license, meaning you can
    use it for any non-commercial purpose as long as you provide attribution.
---

{:.jumbotron}
Bitbear's music is licensed under the [CC BY-NC 4.0 license][cc-by-nc].

{:.jumbotron .subtitle}
This means you can use it for any non-commercial purpose as long as
you provide attribution. Read more in the [license & credits][license]
section.

## Listen

You can listen to my music online. My latest tracks are conveniently provided
below. If you would like to browse through my oldschool legacy, please head over
to the [legacy section][legacy]. Some tracks also have a [remix kit][remix-kits]
available, bundling up the stems and project files behind them.

{% assign posts=site.categories['music'] | reject: 'category', 'legacy' %}
{% include song_table.html posts=posts album=true %}

[cc-by-nc]: https://creativecommons.org/licenses/by-nc/4.0/
[legacy]: /music/legacy/
[license]: /license
[remix-kits]: /music/remix-kits/
