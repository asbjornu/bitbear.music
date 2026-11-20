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
    var decoder = new TextDecoder('utf-8');

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

    function readString(lib, pointer) {
        var heap = lib.HEAPU8;
        var end = pointer;

        if (!pointer) {
            return '';
        }

        while (heap[end] !== 0) {
            end += 1;
        }

        return decoder.decode(heap.subarray(pointer, end));
    }

    function clock(seconds) {
        var total = Math.floor(seconds || 0);
        var minutes = Math.floor(total / 60);
        var rest = total % 60;

        return minutes + ':' + (rest < 10 ? '0' : '') + rest;
    }

    function build(media, title, withPattern) {
        var root = document.createElement('div');
        var canvas = document.createElement('canvas');
        var controls = document.createElement('div');
        var toggle = document.createElement('button');
        var seek = document.createElement('input');
        var time = document.createElement('span');
        var pattern = null;
        var meta = null;
        var viewport = null;
        var rows = null;

        root.className = 'cover-audio';
        canvas.className = 'cover-audio__canvas';
        controls.className = 'cover-audio__controls';

        if (withPattern) {
            pattern = document.createElement('div');
            meta = document.createElement('div');
            viewport = document.createElement('div');
            rows = document.createElement('div');
            pattern.className = 'cover-pattern';
            meta.className = 'cover-pattern__meta';
            viewport.className = 'cover-pattern__viewport';
            rows.className = 'cover-pattern__rows';
            // It is a visualisation of the module, not readable content.
            pattern.setAttribute('aria-hidden', 'true');
            viewport.appendChild(rows);
            pattern.appendChild(meta);
            pattern.appendChild(viewport);
            root.appendChild(pattern);
        }

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
            time: time,
            pattern: pattern,
            meta: meta,
            viewport: viewport,
            rows: rows
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
            ui: build(media, title, media.id === 'cover-media'),
            patterns: {},
            patternIndex: -1,
            rowIndex: -1,
            rowEls: [],
            rowHeight: 0,
            metaText: '',
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

        current.channels = lib._openmpt_module_get_num_channels(module);

        current.render = function () {
            var position = lib._openmpt_module_get_position_seconds(module);

            draw(current);
            ui.time.textContent = clock(position) + ' / ' + clock(current.duration);
            ui.seek.value = String(Math.round((position / current.duration) * 1000));

            if (ui.pattern) {
                try {
                    updatePattern(current);
                } catch (error) {
                    ui.pattern.hidden = true;
                }
            }
        };

        ui.toggle.disabled = false;
        resume(current);
    }

    // Formats every cell of a pattern once, so scrolling the tracker view is
    // just DOM work. Strings come back from the wasm heap and must be freed.
    function formatPattern(current, pattern, columns) {
        var lib = current.lib;
        var module = current.module;
        var rows = lib._openmpt_module_get_pattern_num_rows(module, pattern);
        var data = { columns: columns, rows: [] };
        var row;
        var channel;
        var pointer;

        for (row = 0; row < rows; row += 1) {
            var cells = [];

            for (channel = 0; channel < columns; channel += 1) {
                pointer = lib._openmpt_module_format_pattern_row_channel(module, pattern, row, channel, 0, 1);
                cells.push(readString(lib, pointer));

                if (pointer) {
                    lib._openmpt_free_string(pointer);
                }
            }

            data.rows.push(cells);
        }

        return data;
    }

    function charWidth(current) {
        var probe;
        var width;

        if (current.charWidth) {
            return current.charWidth;
        }

        probe = document.createElement('span');
        probe.textContent = 'MMMMMMMMMM';
        probe.style.position = 'absolute';
        probe.style.visibility = 'hidden';
        probe.style.whiteSpace = 'pre';
        current.ui.viewport.appendChild(probe);
        width = probe.getBoundingClientRect().width / 10;
        current.ui.viewport.removeChild(probe);
        current.charWidth = width || 5;

        return current.charWidth;
    }

    function columnCount(current) {
        var viewport = current.ui.viewport;
        var width = viewport ? viewport.clientWidth : 0;
        var columns;

        if (!width) {
            return Math.min(current.channels, 8);
        }

        // One column is libopenmpt's 13-character cell plus a separating space.
        columns = Math.floor((width - 24) / (14 * charWidth(current)));

        return Math.max(2, Math.min(current.channels, columns));
    }

    function renderPattern(current, pattern) {
        var columns = columnCount(current);
        var key = pattern + ':' + columns;
        var data = current.patterns[key] || formatPattern(current, pattern, columns);
        var fragment = document.createDocumentFragment();
        var rows = current.ui.rows;

        current.patterns[key] = data;
        current.patternIndex = pattern;
        current.rowIndex = -1;
        current.rowEls = [];
        rows.textContent = '';
        rows.style.transform = 'translateY(0)';

        data.rows.forEach(function (cells, row) {
            var element = document.createElement('div');

            element.className = 'cover-pattern__row';
            element.textContent = (row < 10 ? '0' : '') + row + ' ' + cells.join(' ');
            fragment.appendChild(element);
            current.rowEls.push(element);
        });

        rows.appendChild(fragment);
        current.rowHeight = current.rowEls.length ? current.rowEls[0].offsetHeight : 0;
    }

    function updatePattern(current) {
        var lib = current.lib;
        var module = current.module;
        var pattern = lib._openmpt_module_get_current_pattern(module);
        var row = lib._openmpt_module_get_current_row(module);
        var order = lib._openmpt_module_get_current_order(module);
        var bpm = Math.round(lib._openmpt_module_get_current_estimated_bpm(module));
        var meta = 'ord ' + (order + 1) + ' \u00b7 pat ' + (pattern + 1) + ' \u00b7 ' + bpm + ' bpm';
        var previous = current.rowEls[current.rowIndex];
        var visible;
        var offset;

        if (pattern !== current.patternIndex) {
            renderPattern(current, pattern);
            previous = null;
        }

        if (row !== current.rowIndex) {
            if (previous) {
                previous.classList.remove('is-current');
            }

            if (current.rowEls[row]) {
                current.rowEls[row].classList.add('is-current');
            }

            current.rowIndex = row;

            if (current.rowHeight && current.ui.viewport) {
                visible = Math.max(1, Math.floor(current.ui.viewport.clientHeight / current.rowHeight));
                offset = Math.min(
                    Math.max(0, row - Math.floor(visible / 2)),
                    Math.max(0, current.rowEls.length - visible)
                );
                current.ui.rows.style.transform = 'translateY(-' + (offset * current.rowHeight) + 'px)';
            }
        }

        if (meta !== current.metaText) {
            current.metaText = meta;
            current.ui.meta.textContent = meta;
        }
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
        var index;
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
        step = current.data.length;

        gradient = context2d.createLinearGradient(0, height, 0, height * 0.25);
        gradient.addColorStop(0, 'rgba(157, 123, 255, .35)');
        gradient.addColorStop(1, 'rgba(255, 255, 255, .9)');
        context2d.fillStyle = gradient;

        for (bar = 0; bar < bars; bar += 1) {
            // Logarithmic spacing, so the (usually empty) top octaves don't
            // squeeze all the visible energy into the first few bars.
            index = Math.min(step - 1, Math.round(Math.pow(step * 0.75, bar / (bars - 1))));
            value = current.data[index] / 255;
            context2d.fillRect(
                bar * (width / bars) + (width / bars) * 0.2,
                height - height * 0.9 * value,
                (width / bars) * 0.6,
                height * 0.9 * value
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
