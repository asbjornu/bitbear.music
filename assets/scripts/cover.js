(function (document) {
    'use strict';

    // The play button on the cover art opens #cover-art and starts whichever
    // source the track has: SoundCloud by default (see `data-default`), or the
    // YouTube embed, or the tracker module played over the artwork by
    // cover-audio.js. A small switcher appears when more than one is available.
    //
    // The SoundCloud widget is created and buffered as soon as the cover art is
    // hovered or the dialog opens, so pressing play only has to tell it to
    // start rather than wait for the iframe to load.

    var current = null;
    var soundcloud = { frame: null, widget: null, ready: false, pending: false };
    var api = null;

    function loadApi(callback) {
        if (window.SC && window.SC.Widget) {
            callback();
            return;
        }

        if (!api) {
            api = [];
            api.push(callback);

            var element = document.createElement('script');
            element.src = 'https://w.soundcloud.com/player/api.js';
            element.onload = function () {
                var queue = api;

                api = [];
                queue.forEach(function (fn) {
                    fn();
                });
            };
            element.onerror = function () {
                api = null;
            };
            document.head.appendChild(element);

            return;
        }

        api.push(callback);
    }

    function soundcloudUrl(autoplay) {
        return 'https://w.soundcloud.com/player/?url=' +
            encodeURIComponent(current.media.getAttribute('data-soundcloud')) +
            '&auto_play=' + (autoplay ? 'true' : 'false') +
            '&visual=true&color=%2341228e&inverse=true&hide_related=true&show_comments=false';
    }

    function widgetReady() {
        soundcloud.ready = true;

        if (soundcloud.pending) {
            soundcloud.pending = false;
            soundcloud.widget.play();
        }
    }

    function preloadSoundcloud() {
        if (!current || !current.media.getAttribute('data-soundcloud') || soundcloud.frame) {
            return;
        }

        var frame = document.createElement('iframe');

        frame.className = 'is-preload';
        frame.setAttribute('type', 'text/html');
        frame.setAttribute('src', soundcloudUrl(false));
        frame.setAttribute('frameborder', '0');
        frame.setAttribute('allow', 'autoplay; encrypted-media');
        frame.setAttribute('title', 'SoundCloud player');
        current.media.appendChild(frame);
        soundcloud.frame = frame;

        loadApi(function () {
            if (!window.SC || !window.SC.Widget || soundcloud.widget) {
                return;
            }

            var probe;
            var attempts = 0;

            soundcloud.widget = window.SC.Widget(frame);
            soundcloud.widget.bind(window.SC.Widget.Events.READY, widgetReady);

            // The widget may have finished loading before api.js was ready, in
            // which case READY has already fired; poll it until it answers.
            probe = window.setInterval(function () {
                attempts += 1;

                if (soundcloud.ready || attempts > 25) {
                    window.clearInterval(probe);
                    return;
                }

                soundcloud.widget.isPaused(function () {
                    window.clearInterval(probe);
                    widgetReady();
                });
            }, 200);
        });
    }

    function stopSoundcloud() {
        if (soundcloud.widget) {
            soundcloud.widget.pause();
        }

        soundcloud.pending = false;

        if (soundcloud.frame) {
            soundcloud.frame.classList.add('is-preload');
        }
    }

    function stop() {
        if (!current) {
            return;
        }

        current.media.classList.remove('is-playing');
        current.media.classList.remove('is-visualising');
        stopSoundcloud();

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
        var buttons = document.querySelectorAll('.cover-sources [data-source]');
        var index;

        for (index = 0; index < buttons.length; index += 1) {
            buttons[index].setAttribute('aria-pressed', String(buttons[index].getAttribute('data-source') === source));
        }
    }

    function playVideo() {
        var frame = document.createElement('iframe');

        frame.setAttribute('type', 'text/html');
        frame.setAttribute('src', 'https://www.youtube.com/embed/' + current.media.getAttribute('data-video') + '?autoplay=1');
        frame.setAttribute('frameborder', '0');
        frame.setAttribute('allow', 'autoplay; encrypted-media');
        frame.setAttribute('allowfullscreen', '');
        frame.setAttribute('title', 'YouTube video');

        current.media.classList.add('is-playing');
        current.media.appendChild(frame);
        current.frame = frame;
    }

    function playSoundcloud() {
        preloadSoundcloud();
        current.media.classList.add('is-playing');
        soundcloud.frame.classList.remove('is-preload');

        if (!soundcloud.widget) {
            // api.js did not load; let the widget autoplay by itself instead.
            soundcloud.frame.setAttribute('src', soundcloudUrl(true));
        } else if (soundcloud.ready) {
            soundcloud.widget.play();
        } else {
            soundcloud.pending = true;
        }
    }

    function play(source) {
        stop();

        if (source === 'video') {
            playVideo();
        } else if (source === 'soundcloud') {
            playSoundcloud();
        } else if (source === 'module' && window.CoverAudio) {
            current.media.classList.add('is-visualising');
            window.CoverAudio.play(current.media, current.media.getAttribute('data-module'));
        } else {
            return;
        }

        current.playing = source;
        mark(source);
    }

    function initCover() {
        var media = document.querySelector('#cover-media');
        var playButton = media && media.querySelector('#cover-play');
        var link = document.querySelector('#cover .cover-link');
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

        // Start buffering the SoundCloud player before it is needed.
        preloadOnIntent(link);
    }

    function preloadOnIntent(link) {
        if (link) {
            link.addEventListener('pointerenter', preloadSoundcloud);
            link.addEventListener('focus', preloadSoundcloud);
        }

        if (window.location.hash === '#cover-art') {
            preloadSoundcloud();
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

    window.addEventListener('hashchange', function () {
        if (window.location.hash === '#cover-art') {
            preloadSoundcloud();
        } else {
            stop();
        }
    });

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})(document);
