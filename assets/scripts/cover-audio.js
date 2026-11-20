(function (window, document) {
    'use strict';

    // Plays a tracker module over the cover art in the #cover-art dialog,
    // using libopenmpt (the engine behind Demozoo's Cowbell player) driven by
    // a Web Audio graph with an AnalyserNode, so the artwork can carry a
    // spectrum visualiser. Neither libopenmpt nor the module loads until the
    // visitor presses play.

    var script = document.currentScript;
    var base = script && script.src ? script.src.replace(/[^/]*$/, '') : '/assets/scripts/';

    var context = null;
    var libPromise = null;
    var session = null;

    function audioContext() {
        var AudioContext = window.AudioContext || window.webkitAudioContext;

        if (!context) {
            context = new AudioContext();
        }

        if (context.state === 'suspended') {
            context.resume();
        }

        return context;
    }

    function loadLib() {
        if (!libPromise) {
            libPromise = new Promise(function (resolve, reject) {
                if (window.libopenmpt && window.libopenmpt._openmpt_module_create_from_memory) {
                    resolve(window.libopenmpt);
                    return;
                }

                var lib = window.libopenmpt || {};
                lib.onRuntimeInitialized = function () {
                    resolve(window.libopenmpt);
                };
                window.libopenmpt = lib;

                var element = document.createElement('script');
                element.src = base + 'libopenmpt/libopenmpt.js';
                element.onerror = function () {
                    reject(new Error('Could not load libopenmpt'));
                };
                document.head.appendChild(element);
            });
        }

        return libPromise;
    }

    function clock(seconds) {
        var total = Math.floor(seconds || 0);
        var minutes = Math.floor(total / 60);
        var rest = total % 60;

        return minutes + ':' + (rest < 10 ? '0' : '') + rest;
    }

    function build(media, title) {
        var root = document.createElement('div');
        var canvas = document.createElement('canvas');
        var controls = document.createElement('div');
        var toggle = document.createElement('button');
        var seek = document.createElement('input');
        var time = document.createElement('span');

        root.className = 'cover-audio';
        canvas.className = 'cover-audio__canvas';
        controls.className = 'cover-audio__controls';

        toggle.type = 'button';
        toggle.className = 'cover-audio__toggle';
        toggle.setAttribute('aria-label', 'Pause \u201c' + title + '\u201d');
        toggle.textContent = 'Pause';

        seek.type = 'range';
        seek.className = 'cover-audio__seek';
        seek.min = 0;
        seek.max = 1000;
        seek.value = 0;
        seek.step = 1;
        seek.disabled = true;
        seek.setAttribute('aria-label', 'Seek within \u201c' + title + '\u201d');

        time.className = 'cover-audio__time';
        time.textContent = '0:00 / 0:00';

        controls.appendChild(toggle);
        controls.appendChild(seek);
        controls.appendChild(time);
        root.appendChild(canvas);
        root.appendChild(controls);
        media.appendChild(root);

        return {
            root: root,
            canvas: canvas,
            toggle: toggle,
            seek: seek,
            time: time
        };
    }

    function notify(current) {
        if (current.onChange) {
            current.onChange(current.playing);
        }
    }

    function cleanup(current) {
        if (current.processor) {
            current.processor.disconnect();
            current.processor.onaudioprocess = null;
        }

        if (current.analyser) {
            current.analyser.disconnect();
        }

        if (current.lib) {
            if (current.module) {
                current.lib._openmpt_module_destroy(current.module);
            }

            current.lib._free(current.left);
            current.lib._free(current.right);
        }

        current.processor = null;
        current.analyser = null;
        current.module = null;
    }

    function stop() {
        if (!session) {
            return;
        }

        var finished = session;

        session = null;
        window.cancelAnimationFrame(finished.frame);
        cleanup(finished);

        if (finished.ui.root.parentNode) {
            finished.ui.root.parentNode.removeChild(finished.ui.root);
        }
    }

    function play(media, url, onChange) {
        stop();

        var title = media.getAttribute('data-title') || document.title;
        var current = {
            title: title,
            onChange: typeof onChange === 'function' ? onChange : null,
            ctx: audioContext(),
            ui: build(media, title),
            lib: null,
            module: null,
            processor: null,
            analyser: null,
            left: 0,
            right: 0,
            duration: 0,
            playing: false,
            failed: false,
            frame: 0,
            data: null,
            render: null
        };

        session = current;

        current.ui.toggle.disabled = true;
        current.ui.toggle.textContent = 'Loading\u2026';
        current.ui.toggle.setAttribute('aria-label', 'Loading \u201c' + title + '\u201d');
        current.ui.toggle.addEventListener('click', function () {
            if (current.failed) {
                play(media, url);
            } else if (current.playing) {
                pause(current);
            } else {
                resume(current);
            }
        });

        Promise.all([loadLib(), window.fetch(url).then(function (response) {
            if (!response.ok) {
                throw new Error('Could not load the module (' + response.status + ')');
            }

            return response.arrayBuffer();
        })])
            .then(function (results) {
                if (session !== current) {
                    return;
                }

                var lib = results[0];
                var bytes = new Uint8Array(results[1]);
                var pointer = lib._malloc(bytes.length);

                lib.HEAPU8.set(bytes, pointer);
                current.lib = lib;
                current.module = lib._openmpt_module_create_from_memory(pointer, bytes.length, 0, 0, 0);
                lib._free(pointer);

                if (!current.module) {
                    throw new Error('libopenmpt could not read the module');
                }

                start(current);
            })
            .catch(function () {
                if (session !== current) {
                    return;
                }

                cleanup(current);
                current.failed = true;
                current.ui.root.classList.add('is-failed');
                current.ui.toggle.disabled = false;
                current.ui.toggle.textContent = 'Retry';
                current.ui.toggle.setAttribute('aria-label', 'Retry playing \u201c' + title + '\u201d');
                current.ui.time.textContent = 'Playback failed';
                notify(current);
            });
    }

    function start(current) {
        var lib = current.lib;
        var ctx = current.ctx;
        var ui = current.ui;
        var module = current.module;
        var processor = ctx.createScriptProcessor(4096, 0, 2);
        var analyser = ctx.createAnalyser();

        analyser.fftSize = 2048;
        analyser.smoothingTimeConstant = 0.75;

        current.duration = lib._openmpt_module_get_duration_seconds(module);
        current.analyser = analyser;
        current.processor = processor;
        current.data = new Uint8Array(analyser.frequencyBinCount);
        current.left = lib._malloc(16384);
        current.right = lib._malloc(16384);

        processor.onaudioprocess = function (event) {
            var left = event.outputBuffer.getChannelData(0);
            var right = event.outputBuffer.getChannelData(1);
            var frames = lib._openmpt_module_read_float_stereo(
                module,
                ctx.sampleRate,
                left.length,
                current.left,
                current.right
            );
            var i;

            left.set(lib.HEAPF32.subarray(current.left / 4, current.left / 4 + frames));
            right.set(lib.HEAPF32.subarray(current.right / 4, current.right / 4 + frames));

            for (i = frames; i < left.length; i += 1) {
                left[i] = 0;
                right[i] = 0;
            }

            if (frames < left.length) {
                finish(current);
            }
        };

        analyser.connect(ctx.destination);

        ui.seek.disabled = false;
        ui.seek.addEventListener('input', function () {
            ui.time.textContent = clock((ui.seek.value / 1000) * current.duration) +
                ' / ' + clock(current.duration);
        });
        ui.seek.addEventListener('change', function () {
            lib._openmpt_module_set_position_seconds(module, (ui.seek.value / 1000) * current.duration);
        });

        current.render = function () {
            var position = lib._openmpt_module_get_position_seconds(module);

            draw(current);
            ui.time.textContent = clock(position) + ' / ' + clock(current.duration);
            ui.seek.value = String(Math.round((position / current.duration) * 1000));
        };

        ui.toggle.disabled = false;
        resume(current);
    }

    function pause(current) {
        if (!current.playing) {
            return;
        }

        current.playing = false;
        window.cancelAnimationFrame(current.frame);
        current.processor.disconnect();
        current.ui.toggle.textContent = 'Play';
        current.ui.toggle.setAttribute('aria-label', 'Play \u201c' + current.title + '\u201d');
        current.render();
        notify(current);
    }

    function resume(current) {
        if (current.playing) {
            return;
        }

        current.playing = true;
        current.processor.connect(current.analyser);
        current.ui.toggle.textContent = 'Pause';
        current.ui.toggle.setAttribute('aria-label', 'Pause \u201c' + current.title + '\u201d');
        loop(current);
        notify(current);
    }

    function finish(current) {
        if (session !== current) {
            return;
        }

        current.playing = false;
        window.cancelAnimationFrame(current.frame);
        current.processor.disconnect();
        current.lib._openmpt_module_set_position_seconds(current.module, 0);
        current.ui.toggle.textContent = 'Play';
        current.ui.toggle.setAttribute('aria-label', 'Play \u201c' + current.title + '\u201d');
        current.ui.seek.value = 0;
        current.ui.time.textContent = clock(0) + ' / ' + clock(current.duration);
        draw(current);
        notify(current);
    }

    function loop(current) {
        if (session !== current || !current.playing) {
            return;
        }

        current.frame = window.requestAnimationFrame(function () {
            current.render();
            loop(current);
        });
    }

    function draw(current) {
        var canvas = current.ui.canvas;
        var width = canvas.clientWidth;
        var height = canvas.clientHeight;
        var ratio = window.devicePixelRatio || 1;
        var context2d = canvas.getContext('2d');
        var bars = 48;
        var step;
        var bar;
        var value;
        var gradient;

        if (!width || !height || !context2d) {
            return;
        }

        if (canvas.width !== Math.round(width * ratio)) {
            canvas.width = Math.round(width * ratio);
            canvas.height = Math.round(height * ratio);
        }

        context2d.setTransform(ratio, 0, 0, ratio, 0, 0);
        context2d.clearRect(0, 0, width, height);

        if (!current.analyser) {
            return;
        }

        current.analyser.getByteFrequencyData(current.data);
        step = Math.floor(current.data.length / bars);

        gradient = context2d.createLinearGradient(0, height, 0, height * 0.25);
        gradient.addColorStop(0, 'rgba(157, 123, 255, .35)');
        gradient.addColorStop(1, 'rgba(255, 255, 255, .9)');
        context2d.fillStyle = gradient;

        for (bar = 0; bar < bars; bar += 1) {
            value = current.data[bar * step] / 255;
            context2d.fillRect(
                bar * (width / bars) + (width / bars) * 0.2,
                height - height * 0.55 * value,
                (width / bars) * 0.6,
                height * 0.55 * value
            );
        }
    }

    function active() {
        return Boolean(session && session.processor);
    }

    function toggle() {
        if (!active()) {
            return false;
        }

        if (session.playing) {
            pause(session);
        } else {
            resume(session);
        }

        return session.playing;
    }

    window.CoverAudio = {
        play: play,
        stop: stop,
        active: active,
        toggle: toggle
    };
})(window, document);
