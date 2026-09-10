(function (document) {
    'use strict';

    var current = null;

    function restore() {
        if (!current) {
            return;
        }

        current.media.classList.remove('is-playing');

        if (current.iframe) {
            current.iframe.remove();
            current.iframe = null;
        }
    }

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && window.location.hash === '#cover-art') {
            window.location.hash = '';
        }
    });

    window.addEventListener('hashchange', restore);

    function initCoverArt() {
        var media = document.querySelector('#cover-media');
        var play = media && media.querySelector('#cover-play');
        var img = media && media.querySelector('img');

        if (!media || !img || !play) {
            current = null;
            return;
        }

        current = { media: media, play: play, iframe: null };

        play.addEventListener('click', function (event) {
            var match = /[?&]v=([^&#]+)/.exec(play.getAttribute('href'));
            var youtube = match ? match[1] : null;

            if (!youtube || current.iframe) {
                return;
            }

            event.preventDefault();

            var iframe = document.createElement('iframe');

            iframe.setAttribute('type', 'text/html');
            iframe.setAttribute('src', 'https://www.youtube.com/embed/' + youtube + '?autoplay=1');
            iframe.setAttribute('frameborder', '0');
            iframe.setAttribute('allow', 'autoplay; encrypted-media');
            iframe.setAttribute('allowfullscreen', '');

            media.classList.add('is-playing');
            media.appendChild(iframe);
            current.iframe = iframe;
        });
    }

    function ready(fn) {
        if (document.readyState !== 'loading') {
            fn();
        } else {
            document.addEventListener('DOMContentLoaded', fn);
        }
    }

    ready(initCoverArt);
})(document);
