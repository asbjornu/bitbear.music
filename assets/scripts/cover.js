(function (document) {
    function ready(fn) {
        if (document.readyState !== 'loading') {
            fn();
        } else {
            document.addEventListener('DOMContentLoaded', fn);
        }
    }

    ready(function () {
        var modal = document.querySelector('#cover-art');

        if (modal) {
            document.addEventListener('keydown', function (event) {
                if (event.key === 'Escape' && window.location.hash === '#cover-art') {
                    window.location.hash = '';
                }
            });
        }

        var media = document.querySelector('#cover-media');
        var play = document.querySelector('#cover-media #cover-play');
        var img = media && media.querySelector('img');
        if (!media || !img || !play) {
            return;
        }

        var iframe = null;

        function restore() {
            media.classList.remove('is-playing');
            if (iframe) {
                iframe.remove();
                iframe = null;
            }
        }

        play.addEventListener('click', function (event) {
            var match = /[?&]v=([^&#]+)/.exec(play.getAttribute('href'));
            var youtube = match ? match[1] : null;
            if (!youtube || iframe) {
                return;
            }
            event.preventDefault();
            iframe = document.createElement('iframe');
            iframe.setAttribute('type', 'text/html');
            iframe.setAttribute('src', 'https://www.youtube.com/embed/' + youtube + '?autoplay=1');
            iframe.setAttribute('frameborder', '0');
            iframe.setAttribute('allow', 'autoplay; encrypted-media');
            iframe.setAttribute('allowfullscreen', '');
            media.classList.add('is-playing');
            media.appendChild(iframe);
        });

        window.addEventListener('hashchange', restore);

        restore();
    });
})(document);
