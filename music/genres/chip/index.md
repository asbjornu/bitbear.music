---
title: Bitbear's Chiptunes
layout: page
description: |
    Chiptunes are songs which mimic the sound of physical hardware chips such as
    Commodore 64's SID or ZX Spectrum's AY-3-8910. Here you can find Bitbear's
    chiptunes.
---

{:.jumbotron}
[Chiptunes] are songs which mimic the sound of physical hardware chips such as
[Commodore 64][c64]'s [SID] or [ZX Spectrum's][zx] [AY-3-8910].

Originally, "chip tunes" had to be produced on hardware with actual synthesizers
on a chip – hence the name. On the [Amiga] and [IBM PC][pc], no such standard
synthesizer chips were available, so "chip tunes" were rather faithful
emulations produced using samples.

Besides the oldschool sound, the other defining characteristic of chip tunes was
file size. Somewhere around 10 kilobytes was usually the upper file size limit
and had to be adhered to if you wanted to participate in a chip tune
competition.

You can find all of Bitbear's chiptunes below.

{% assign posts=site.tags['chip'] %}
{% include song_year_nav.html posts=posts %}
{% include song_table.html posts=posts %}

[ay-3-8910]: https://en.wikipedia.org/wiki/General_Instrument_AY-3-8910
[c64]: https://en.wikipedia.org/wiki/Commodore_64
[chiptunes]: https://en.wikipedia.org/wiki/Chiptune
[sid]: https://en.wikipedia.org/wiki/MOS_Technology_6581
[zx]: https://en.wikipedia.org/wiki/ZX_Spectrum
[amiga]: https://en.wikipedia.org/wiki/Amiga
[pc]: https://en.wikipedia.org/wiki/IBM_PC_compatible
