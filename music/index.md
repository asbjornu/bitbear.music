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
to the [legacy section][legacy].

{% assign posts=site.categories['music'] | reject: 'category', 'legacy' %}
{% include song_table.html posts=posts album=true %}

## Follow

Bitbear can also be found on the following online music platforms:

- [Bandcamp]{:rel="me"}
- [Beatport]{:rel="me"}
- [Mixcloud]{:rel="me"}
- [SoundCloud]{:rel="me"}
- [YouTube]{:rel="me"}

[bandcamp]: https://bitbearmusic.bandcamp.com
[beatport]: https://dj.beatport.com/bitbear
[cc-by-nc]: https://creativecommons.org/licenses/by-nc/4.0/
[legacy]: /music/legacy/
[license]: /license/
[mixcloud]: https://www.mixcloud.com/bitbearmusic/
[soundcloud]: https://soundcloud.com/bitbear
[youtube]: https://www.youtube.com/channel/UC9wb6OrUrugGg6-q9805RDQ
