(function (window, document) {
    'use strict';

    // Plays a tracker module over the cover art in the #cover-art dialog,
    // using libopenmpt (the engine behind Demozoo's Cowbell player). The
    // artwork carries a ProTracker-style view: one colour-coded column per
    // channel, a static window of pattern rows that follows playback, the
    // sample/instrument currently loaded on each channel, and a meter per
    // channel along the bottom. Nothing loads until the visitor presses play.

    var script = document.currentScript;
    var base = script && script.src ? script.src.replace(/[^/]*$/, '') : '/assets/scripts/';

    // One colour per channel, cycling for modules with more channels than this.
    var PALETTE = [
        '#a78bfa', '#38bdf8', '#f472b6', '#fbbf24', '#34d399', '#fb7185',
        '#c084fc', '#4ade80', '#fdba74', '#93c5fd', '#f9a8d4', '#a3e635'
    ];

    var context = null;
    var libPromise = null;
    var session = null;
    var utf8 = new TextDecoder('utf-8');
    var latin1 = new TextDecoder('windows-1252');

    function readString(lib, pointer) {
        var heap = lib.HEAPU8;
        var end = pointer;
        var bytes;
        var text;

        if (!pointer) {
            return '';
        }

        while (heap[end] !== 0) {
            end += 1;
        }

        bytes = heap.subarray(pointer, end);
        text = utf8.decode(bytes);

        // Old modules label samples in Latin-1, not UTF-8.
        return text.indexOf('\uFFFD') === -1 ? text : latin1.decode(bytes);
    }

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

    function build(media, title, withPattern) {
        var root = document.createElement('div');
        var canvas = document.createElement('canvas');
        var controls = document.createElement('div');
        var toggle = document.createElement('button');
        var seek = document.createElement('input');
        var time = document.createElement('span');
        var pattern = null;
        var meta = null;
        var channels = null;
        var viewport = null;
        var rows = null;

        root.className = 'cover-audio';
        canvas.className = 'cover-audio__canvas';
        controls.className = 'cover-audio__controls';

        if (withPattern) {
            pattern = document.createElement('div');
            meta = document.createElement('div');
            channels = document.createElement('div');
            viewport = document.createElement('div');
            rows = document.createElement('div');
            pattern.className = 'cover-pattern';
            meta.className = 'cover-pattern__meta';
            channels.className = 'cover-pattern__channels';
            viewport.className = 'cover-pattern__viewport';
            rows.className = 'cover-pattern__rows';
            // A visualisation of the module, not readable content.
            pattern.setAttribute('aria-hidden', 'true');
            viewport.appendChild(rows);
            pattern.appendChild(meta);
            pattern.appendChild(channels);
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
            channels: channels,
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

        if (current.lib) {
            if (current.module) {
                current.lib._openmpt_module_destroy(current.module);
            }

            current.lib._free(current.left);
            current.lib._free(current.right);
        }

        current.processor = null;
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
            names: {},
            labels: [],
            lastInstrument: [],
            patternIndex: -1,
            rowIndex: -1,
            metaText: '',
            bars: [],
            fontSize: 0,
            windowRows: 0,
            centre: 0
        };

        session = current;

        current.ui.toggle.disabled = true;
        current.ui.toggle.textContent = 'Loading\u2026';
        current.ui.toggle.setAttribute('aria-label', 'Loading \u201c' + title + '\u201d');
        current.ui.toggle.addEventListener('click', function () {
            if (current.failed) {
                play(media, url, onChange);
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

        current.duration = lib._openmpt_module_get_duration_seconds(module);
        current.channels = lib._openmpt_module_get_num_channels(module);
        current.processor = processor;

        if (!ui.pattern) {
            // The inline player has no pattern columns to align to.
            measureMeters(current);
        }
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

            drawMeters(current);
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

    // ---- pattern view ----------------------------------------------------

    // Formats every cell of a pattern once; strings come from the wasm heap
    // and must be freed.
    function patternData(current, pattern) {
        var lib = current.lib;
        var module = current.module;
        var rows = lib._openmpt_module_get_pattern_num_rows(module, pattern);
        var data = { rows: [] };
        var row;
        var channel;
        var pointer;

        if (current.patterns[pattern]) {
            return current.patterns[pattern];
        }

        for (row = 0; row < rows; row += 1) {
            var cells = [];

            for (channel = 0; channel < current.channels; channel += 1) {
                pointer = lib._openmpt_module_format_pattern_row_channel(module, pattern, row, channel, 0, 1);
                cells.push(readString(lib, pointer));

                if (pointer) {
                    lib._openmpt_free_string(pointer);
                }
            }

            data.rows.push(cells);
        }

        current.patterns[pattern] = data;

        return data;
    }

    function instrumentName(current, number) {
        var lib = current.lib;
        var pointer;
        var name = '';

        if (current.names[number] !== undefined) {
            return current.names[number];
        }

        if (lib._openmpt_module_get_instrument_name) {
            pointer = lib._openmpt_module_get_instrument_name(current.module, number - 1);
            name = readString(lib, pointer);

            if (pointer) {
                lib._openmpt_free_string(pointer);
            }
        }

        if (!name && lib._openmpt_module_get_sample_name) {
            pointer = lib._openmpt_module_get_sample_name(current.module, number - 1);
            name = readString(lib, pointer);

            if (pointer) {
                lib._openmpt_free_string(pointer);
            }
        }

        current.names[number] = name.replace(/\s+/g, ' ').trim();

        return current.names[number];
    }

    // Shrink the font until every channel column fits the modal width.
    function fitFont(current, columns) {
        var width = current.ui.viewport.clientWidth || 0;
        var size = width ? ((width - 24) / columns) / 8.5 : 9;

        size = Math.max(5, Math.min(16, size));
        current.fontSize = size;
        current.ui.pattern.style.setProperty('--pattern-font', size + 'px');
    }

    function windowRows(current, patternRows) {
        var height = current.ui.viewport.clientHeight || 0;
        var count = Math.min(patternRows, Math.floor(height / ((current.fontSize || 9) * 1.35)));

        if (count % 2 === 0) {
            count -= 1;
        }

        return Math.max(5, count);
    }

    function renderPattern(current, pattern, row) {
        var ui = current.ui;
        var columns = current.channels;
        var index;
        var channel;
        var line;
        var cells;

        var data = patternData(current, pattern);

        current.patternIndex = pattern;
        fitFont(current, columns);
        current.windowRows = windowRows(current, data.rows.length);
        current.centre = Math.floor(current.windowRows / 2);
        current.rowIndex = -1;

        ui.channels.textContent = '';
        ui.channels.appendChild(gutter());
        for (channel = 0; channel < columns; channel += 1) {
            cells = document.createElement('span');
            cells.className = 'cover-pattern__channel';
            cells.style.color = PALETTE[channel % PALETTE.length];
            cells.textContent = current.labels[channel] || '';
            ui.channels.appendChild(cells);
        }

        ui.rows.textContent = '';
        current.cells = [];
        current.currentEl = null;
        for (index = 0; index < current.windowRows; index += 1) {
            line = document.createElement('div');
            line.className = 'cover-pattern__row';
            line.appendChild(gutter());
            cells = [];
            for (channel = 0; channel < columns; channel += 1) {
                var cell = document.createElement('span');
                cell.className = 'cover-pattern__cell';
                cell.style.color = PALETTE[channel % PALETTE.length];
                line.appendChild(cell);
                cells.push(cell);
            }

            ui.rows.appendChild(line);
            current.cells.push({
                element: line,
                number: line.firstChild,
                cells: cells
            });
        }

        fillWindow(current, row);
        measureMeters(current);
    }

    function gutter() {
        var element = document.createElement('span');

        element.className = 'cover-pattern__num';

        return element;
    }

    function fillWindow(current, row) {
        var data = current.patterns[current.patternIndex];
        var start = Math.max(0, Math.min(row - current.centre, data.rows.length - current.windowRows));
        var index;
        var channel;
        var patternRow;
        var line;

        for (index = 0; index < current.windowRows; index += 1) {
            patternRow = start + index;
            line = current.cells[index];
            line.number.textContent = patternRow >= data.rows.length ? '' : (patternRow < 10 ? '0' : '') + patternRow;

            for (channel = 0; channel < current.channels; channel += 1) {
                line.cells[channel].textContent = data.rows[patternRow] ?
                    data.rows[patternRow][channel] : '';
            }
        }

        if (current.currentEl) {
            current.currentEl.classList.remove('is-current');
        }

        line = current.cells[row - start];
        current.currentEl = line ? line.element : null;

        if (current.currentEl) {
            current.currentEl.classList.add('is-current');
        }

        updateLabels(current, row);
    }

    // Sample/instrument names stick until the channel starts something new.
    function updateLabels(current, row) {
        var line = current.patterns[current.patternIndex].rows[row];
        var channel;
        var cell;
        var note;
        var instrument;
        var name;

        if (!line) {
            return;
        }

        for (channel = 0; channel < current.channels; channel += 1) {
            cell = line[channel] || '';
            note = cell.slice(0, 3);
            instrument = cell.slice(4, 6);

            if (note === '...' || note === '' || !/^\d\d$/.test(instrument)) {
                continue;
            }

            name = instrumentName(current, parseInt(instrument, 10));

            if (!name) {
                continue;
            }

            current.labels[channel] = name;

            if (current.ui.channels.children[channel + 1]) {
                current.ui.channels.children[channel + 1].textContent = name;
            }
        }
    }

    function updatePattern(current) {
        var lib = current.lib;
        var module = current.module;
        var pattern = lib._openmpt_module_get_current_pattern(module);
        var row = lib._openmpt_module_get_current_row(module);
        var order = lib._openmpt_module_get_current_order(module);
        var bpm = Math.round(lib._openmpt_module_get_current_estimated_bpm(module));
        var meta = 'ord ' + (order + 1) + ' \u00b7 pat ' + (pattern + 1) + ' \u00b7 ' + bpm + ' bpm';

        if (pattern !== current.patternIndex) {
            renderPattern(current, pattern, row);
        } else if (row !== current.rowIndex) {
            fillWindow(current, row);
        }

        current.rowIndex = row;

        if (meta !== current.metaText) {
            current.metaText = meta;
            current.ui.meta.textContent = meta;
        }
    }

    // ---- per-channel meters ---------------------------------------------

    function measureMeters(current) {
        var rect = current.ui.canvas.getBoundingClientRect();
        var headers = current.ui.channels ?
            current.ui.channels.querySelectorAll('.cover-pattern__channel') : [];
        var width = current.ui.canvas.clientWidth;
        var index;

        if (!rect.width) {
            current.bars = [];
            return;
        }

        if (headers.length) {
            current.bars = Array.prototype.map.call(headers, function (element) {
                var box = element.getBoundingClientRect();

                return { x: box.left - rect.left, width: box.width };
            });

            return;
        }

        // No pattern view (inline player): spread the meters over the canvas.
        current.bars = [];
        for (index = 0; index < current.channels; index += 1) {
            current.bars.push({
                x: (width / current.channels) * index,
                width: width / current.channels
            });
        }
    }

    function drawMeters(current) {
        var canvas = current.ui.canvas;
        var width = canvas.clientWidth;
        var height = canvas.clientHeight;
        var ratio = window.devicePixelRatio || 1;
        var context2d = canvas.getContext('2d');
        var index;
        var bar;
        var barWidth;
        var level;

        if (!width || !height || !context2d || !current.module) {
            return;
        }

        if (!current.bars.length) {
            measureMeters(current);
        }

        if (canvas.width !== Math.round(width * ratio) || canvas.height !== Math.round(height * ratio)) {
            canvas.width = Math.round(width * ratio);
            canvas.height = Math.round(height * ratio);
        }

        context2d.setTransform(ratio, 0, 0, ratio, 0, 0);
        context2d.clearRect(0, 0, width, height);

        for (index = 0; index < current.bars.length && index < current.channels; index += 1) {
            bar = current.bars[index];
            level = Math.max(
                current.lib._openmpt_module_get_current_channel_vu_left(current.module, index),
                current.lib._openmpt_module_get_current_channel_vu_right(current.module, index)
            );
            level = Math.min(1, Math.max(0, level));

            if (level < 0.005) {
                continue;
            }

            context2d.fillStyle = PALETTE[index % PALETTE.length];
            context2d.globalAlpha = 0.9;
            barWidth = Math.min(bar.width * 0.7, 24);
            context2d.fillRect(
                bar.x + (bar.width - barWidth) / 2,
                height - level * height,
                barWidth,
                level * height
            );
        }

        context2d.globalAlpha = 1;
    }

    // ---- transport -------------------------------------------------------

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
        current.processor.connect(current.ctx.destination);
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
        drawMeters(current);
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
