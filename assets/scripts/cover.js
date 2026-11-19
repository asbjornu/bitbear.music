(function (document) {
    'use strict';

    // The play button on the cover art opens #cover-art and starts whichever
    // source the track has: SoundCloud by default (see `data-default`), or the
    // YouTube embed, or the tracker module played over the artwork by
    // cover-audio.js. A small switcher appears when more than one is available.

    var current = null;

    function stop() {
        if (!current) {
            return;
        }

        current.media.classList.remove('is-playing');
        current.media.classList.remove('is-visualising');

        if (current.frame) {
            current.frame.remove();
            current.frame = null;
        }

        if (window.CoverAudio) {
            window.CoverAudio.stop();
        }

        current.playing = null;
    }

    function mark(source) {
        var buttons = current.media.parentNode.querySelectorAll('.cover-sources [data-source]');
        var index;

        for (index = 0; index < buttons.length; index += 1) {
            buttons[index].setAttribute('aria-pressed', String(buttons[index].getAttribute('data-source') === source));
        }
    }

    function iframe(src, allow) {
        var element = document.createElement('iframe');

        element.setAttribute('type', 'text/html');
        element.setAttribute('src', src);
        element.setAttribute('frameborder', '0');
        element.setAttribute('allow', allow);
        element.setAttribute('allowfullscreen', '');

        current.media.classList.add('is-playing');
        current.media.appendChild(element);
        current.frame = element;
    }

    function play(source) {
        var media = current.media;

        stop();

        if (source === 'video') {
            iframe('https://www.youtube.com/embed/' + media.getAttribute('data-video') + '?autoplay=1',
                'autoplay; encrypted-media');
        } else if (source === 'soundcloud') {
            iframe('https://w.soundcloud.com/player/?url=' +
                encodeURIComponent(media.getAttribute('data-soundcloud')) +
                '&auto_play=true&visual=true&color=%2341228e&inverse=true&hide_related=true&show_comments=false',
                'autoplay; encrypted-media');
        } else if (source === 'module' && window.CoverAudio) {
            media.classList.add('is-visualising');
            window.CoverAudio.play(media, media.getAttribute('data-module'));
        } else {
            return;
        }

        current.playing = source;
        mark(source);
    }

    function initCover() {
        var media = document.querySelector('#cover-media');
        var playButton = media && media.querySelector('#cover-play');
        var buttons;
        var index;

        if (!media || !playButton) {
            current = null;
            return;
        }

        current = { media: media, frame: null, playing: null };

        playButton.addEventListener('click', function () {
            play(media.getAttribute('data-default') || 'module');
        });

        buttons = document.querySelectorAll('.cover-sources [data-source]');

        for (index = 0; index < buttons.length; index += 1) {
            buttons[index].addEventListener('click', function () {
                play(this.getAttribute('data-source'));
            });
        }
    }

    // Posts without cover art get a compact player in the Listen row instead.
    function initInline() {
        var hosts = document.querySelectorAll('.inline-audio');
        var index;

        for (index = 0; index < hosts.length; index += 1) {
            (function (host) {
                var button = host.querySelector('.inline-audio__play');

                if (!button || !window.CoverAudio) {
                    return;
                }

                button.addEventListener('click', function () {
                    host.removeChild(button);
                    window.CoverAudio.play(host, host.getAttribute('data-module'));
                });
            }(hosts[index]));
        }
    }

    function init() {
        initCover();
        initInline();
    }

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && window.location.hash === '#cover-art') {
            window.location.hash = '';
        }
    });

    window.addEventListener('hashchange', stop);

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})(document);
