(function (document) {
    'use strict';

    // Tracker modules are played by Cowbell (https://demozoo.github.io/cowbell/),
    // Demozoo's player, backed by libopenmpt compiled to WebAssembly. The engine
    // is ~1.5 MB, so it is only fetched when a visitor presses play; until then
    // the page just carries a couple of KB of markup and this script.

    var script = document.currentScript;
    var base = script && script.src ? script.src.replace(/[^/]*$/, '') : '/assets/scripts/';
    var loaded = {};
    var engine = null;

    function loadScript(src) {
        if (!loaded[src]) {
            loaded[src] = new Promise(function (resolve, reject) {
                var element = document.createElement('script');
                element.src = src;
                element.onload = resolve;
                element.onerror = function () {
                    reject(new Error('Could not load ' + src));
                };
                document.head.appendChild(element);
            });
        }

        return loaded[src];
    }

    // cowbell.min.js defines the player and UI plumbing; openmpt.min.js registers
    // the Cowbell.Player.OpenMPT backend, which in turn loads libopenmpt.js.
    function loadEngine() {
        if (!engine) {
            engine = loadScript(base + 'cowbell/cowbell.min.js')
                .then(function () {
                    return loadScript(base + 'cowbell/openmpt.min.js');
                })
                .then(function () {
                    return base + 'cowbell/libopenmpt.js';
                });
        }

        return engine;
    }

    function clock(seconds) {
        var total = Math.floor(seconds || 0);
        var minutes = Math.floor(total / 60);
        var rest = total % 60;

        return minutes + ':' + (rest < 10 ? '0' : '') + rest;
    }

    // Cowbell's UI contract: a constructor that receives the host element, plus an
    // `open(track)` method. A Cowbell track is a factory whose `open()` returns an
    // HTMLMediaElement lookalike (duration, currentTime, play, pause, and on*
    // handlers), so this stays independent of the backend.
    function Controls(host) {
        var url = host.getAttribute('data-module');
        var title = host.getAttribute('data-title') || 'track';
        var playLabel = 'Play \u201c' + title + '\u201d';
        var pauseLabel = 'Pause \u201c' + title + '\u201d';
        var toggle = document.createElement('button');
        var seek = document.createElement('input');
        var time = document.createElement('span');
        var position = document.createElement('span');
        var duration = document.createElement('span');
        var status = document.createElement('span');
        var track = null;
        var media = null;
        var loading = false;

        toggle.type = 'button';
        toggle.className = 'module-player__toggle';
        toggle.textContent = 'Play';
        toggle.setAttribute('aria-label', playLabel);

        seek.type = 'range';
        seek.className = 'module-player__seek';
        seek.min = 0;
        seek.max = 1000;
        seek.value = 0;
        seek.step = 1;
        seek.disabled = true;
        seek.setAttribute('aria-label', 'Seek within \u201c' + title + '\u201d');

        position.textContent = clock(0);
        duration.textContent = clock(0);
        time.className = 'module-player__time';
        time.appendChild(position);
        time.appendChild(document.createTextNode(' / '));
        time.appendChild(duration);

        status.className = 'module-player__status';
        status.setAttribute('role', 'status');

        [toggle, seek, time, status].forEach(function (element) {
            host.appendChild(element);
        });

        function label(text, description) {
            toggle.textContent = text;
            toggle.setAttribute('aria-label', description);
        }

        function listen(element) {
            element.onloadedmetadata = function () {
                duration.textContent = clock(element.duration);
                seek.disabled = false;
            };

            element.onplay = function () {
                label('Pause', pauseLabel);
                status.textContent = '';
            };

            element.onpause = function () {
                label('Play', playLabel);
            };

            element.ontimeupdate = function () {
                if (!element.duration) {
                    return;
                }

                position.textContent = clock(element.currentTime);
                seek.value = String(Math.round((element.currentTime / element.duration) * 1000));
            };

            element.onended = function () {
                position.textContent = clock(0);
                seek.value = 0;
                label('Play', playLabel);
            };
        }

        function fail() {
            loading = false;
            toggle.disabled = false;
            label('Retry', 'Retry playing \u201c' + title + '\u201d');
            status.textContent = 'Playback failed.';
        }

        function load() {
            loading = true;
            label('Loading\u2026', 'Loading \u201c' + title + '\u201d');
            toggle.disabled = true;
            status.textContent = '';

            loadEngine()
                .then(function (libopenmpt) {
                    var backend = Cowbell.Player.OpenMPT({
                        pathToLibOpenMPT: libopenmpt
                    });

                    loading = false;
                    ui.open(new backend.Track(url));
                })
                .catch(fail);
        }

        toggle.addEventListener('click', function () {
            if (!media) {
                if (!loading) {
                    load();
                }

                return;
            }

            if (media.paused) {
                media.play();
            } else {
                media.pause();
            }
        });

        seek.addEventListener('input', function () {
            if (media && media.duration) {
                position.textContent = clock((seek.value / 1000) * media.duration);
            }
        });

        seek.addEventListener('change', function () {
            if (media && media.duration) {
                position.textContent = clock((seek.value / 1000) * media.duration);
                media.currentTime = (seek.value / 1000) * media.duration;
            }
        });

        var ui = {
            open: function (next) {
                if (media && !media.paused) {
                    media.pause();
                }

                if (track && track !== next && typeof track.close === 'function') {
                    track.close();
                }

                track = next;
                media = null;
                seek.value = 0;
                position.textContent = clock(0);

                if (!next) {
                    seek.disabled = true;
                    return;
                }

                toggle.disabled = false;
                media = next.open();
                listen(media);
                // The visitor already pressed play to get here; WebAudioPlayer
                // defers the actual start until the module has loaded.
                media.play();
            }
        };

        return ui;
    }

    // The engine itself is only fetched on play, but the UI needs Cowbell's
    // createPlayer() to exist first. That is a ~6 KB script, so it is loaded
    // eagerly on pages that carry a module; the 1.5 MB backend is not.
    function decorate(host) {
        if (host.getAttribute('data-ready')) {
            return;
        }

        host.setAttribute('data-ready', 'true');
        // No URL is passed here on purpose: Cowbell then only builds the UI and
        // leaves the backend until the visitor actually presses play.
        Cowbell.createPlayer(host, {
            ui: Controls
        });
    }

    function init() {
        var hosts = document.querySelectorAll('[data-module]');

        if (!hosts.length) {
            return;
        }

        loadScript(base + 'cowbell/cowbell.min.js')
            .then(function () {
                Array.prototype.forEach.call(hosts, decorate);
            })
            .catch(function () {
                Array.prototype.forEach.call(hosts, function (host) {
                    host.hidden = true;
                });
            });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})(document);
