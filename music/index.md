---
title: Music
description: |
    Bitbear's music is licensed under the CC BY 4.0 license, meaning you can use
    it any way you like as long as you provide attribution.
---

{:.jumbotron}
Bitbear's music is licensed under the [CC BY 4.0 license][cc], meaning you can
use it any way you like as long as you provide attribution.

## Listen

You can listen to my music online. My latest tracks are conveniently provided
below. If you would like to browse through my oldschool legacy, please head over
to the [legacy section][legacy].

{% assign posts=site.categories['music'] | reject: 'category', 'legacy' | reject: 'album.slug' %}
{% include song_table.html posts=posts album=true %}

## Follow

Bitbear can also be found on the following online music platforms:

- [Bandcamp]{:rel="me"}
- [Beatport]{:rel="me"}
- [Mixcloud]{:rel="me"}
- [SoundCloud]{:rel="me"}
- [YouTube]{:rel="me"}

[legacy]: /music/legacy/
[bandcamp]: https://bitbearmusic.bandcamp.com
[beatport]: https://dj.beatport.com/bitbear
[cc]: https://creativecommons.org/licenses/by/4.0/
[mixcloud]: https://www.mixcloud.com/bitbearmusic/
[soundcloud]: https://soundcloud.com/bitbear
[youtube]: https://www.youtube.com/channel/UC9wb6OrUrugGg6-q9805RDQ
