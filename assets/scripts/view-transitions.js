(function () {
    'use strict';

    // Cross-document view transitions (`@view-transition { navigation: auto }`)
    // are driven natively by the browser. `pageswap`/`pagereveal` fire on *every*
    // MPA navigation, but `event.viewTransition` is only set when a transition is
    // actually active (it is `null` otherwise — e.g. under `prefers-reduced-motion`
    // or in browsers without support), so behavior below is gated on it being
    // present. `event.activation.trigger` is also null in some browsers, so the
    // direction cannot be read from the activation. Instead the direction is
    // carried in the URL: a click on a prev/next/back/home link appends `?vt=<dir>`
    // to the destination, the inline <head> script applies the `nav-*` class during
    // parse (before the incoming snapshot), and `pagereveal` strips the param
    // (history.replaceState) and removes the class afterwards.
    // No fetch, no DOM swap, no history handling: the browser navigates natively.
    // Unsupported browsers and reduced-motion users fall through to a plain
    // navigation — both the click handler and inline script bail out so no `?vt=`
    // param or scroll-lock is added.

    var SUPPORTED = 'startViewTransition' in document;

    function prefersReducedMotion() {
        return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    }

    function directionFrom(trigger) {
        if (!trigger || typeof trigger.getAttribute !== 'function') {
            return null;
        }
        var tokens = (trigger.getAttribute('rel') || '').split(/\s+/);
        if (tokens.indexOf('next') !== -1) return 'forward';
        if (tokens.indexOf('prev') !== -1) return 'back';
        // `index`/`home` take precedence over `back`: index links are also
        // decorated with `back`, but should slide up, not down.
        if (tokens.indexOf('index') !== -1) return 'up';
        if (tokens.indexOf('home') !== -1) return 'up';
        if (tokens.indexOf('back') !== -1) return 'down';
        return null;
    }

    var NAV_CLASSES = ['nav-forward', 'nav-back', 'nav-up', 'nav-down'];

    function applyDirection(direction) {
        var c = document.documentElement.classList;
        c.remove.apply(c, NAV_CLASSES);
        if (direction) {
            c.add('nav-' + direction);
        }
    }

    function lockScroll() {
        document.documentElement.classList.add('vt-active');
    }

    function unlockScroll() {
        document.documentElement.classList.remove('vt-active');
    }

    function stripParam() {
        try {
            var url = new URL(location.href);
            if (url.searchParams.has('vt')) {
                url.searchParams.delete('vt');
                history.replaceState(null, '', url.pathname + url.search + url.hash);
            }
        } catch (_) {}
    }

    document.addEventListener('click', function (event) {
        if (!SUPPORTED || prefersReducedMotion()) return;
        // `event.target` may be a text node when the click lands on a link's
        // label, which has no `closest`; normalize to its element first.
        var trigger = event.target;
        if (trigger && trigger.nodeType === 3 /* TEXT_NODE */) {
            trigger = trigger.parentNode;
        }
        if (!trigger || typeof trigger.closest !== 'function') return;
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0) return;
        var link = trigger.closest('a[rel~="next"], a[rel~="prev"], a[rel~="home"], a[rel~="back"], a[rel~="index"]');
        if (!link) return;
        var direction = directionFrom(link);
        if (!direction) return;
        // Only decorate same-origin navigations. Cross-origin links would
        // otherwise receive a spurious `?vt=` query param and the current page
        // would briefly apply the scroll-lock, so let the browser handle those
        // clicks normally.
        var url;
        try {
            url = new URL(link.href, location.href);
        } catch (_) {
            return;
        }
        if (url.origin !== location.origin) return;
        // Outgoing snapshot: set the class synchronously (timing-safe).
        applyDirection(direction);
        lockScroll();
        // Safety net for an interrupted navigation: if it doesn't proceed,
        // `pagereveal` never fires, so schedule an *unlock* (classes/scroll only)
        // so the scroll-lock can't stick. We deliberately don't strip `?vt=` here:
        // this timer runs on the outgoing document and a slow navigation could
        // otherwise `replaceState` the destination's URL before it's read.
        window.setTimeout(unlock, 700);
        // Carry the direction to the incoming page via the URL. We navigate
        // imperatively instead of mutating `link.href`, so the link keeps its
        // original, copyable href and never ends up with a stale `?vt=`.
        try {
            url.searchParams.set('vt', direction);
            event.preventDefault();
            // Navigate to the full URL (including origin) so the destination is
            // reached exactly; only same-origin links get the `?vt=` param.
            window.location.href = url.href;
        } catch (_) {
            // URL construction failed: let the browser navigate natively
            // (without `?vt=`) rather than breaking the click.
        }
    });

    // Remove the direction classes and the scroll-lock without touching history.
    function unlock() {
        applyDirection(null);
        unlockScroll();
    }

    // Full cleanup for the *incoming* document: unlock, then strip `?vt=` from
    // its own URL via `replaceState`. Only call this where the document's own
    // location is the one carrying `?vt=` (i.e. on the destination page).
    function cleanup() {
        unlock();
        stripParam();
    }

    // `pageswap` fires on the outgoing document and `pagereveal` on the incoming
    // one; both expose `event.viewTransition` only when a transition is active
    // (it is `null` for a plain navigation), so bailing on a null `vt` avoids
    // locking scrolling unnecessarily (e.g. under `prefers-reduced-motion`).
    function onSwap(event) {
        var vt = event.viewTransition;
        if (!vt) return;
        lockScroll();
        if (vt.finished && typeof vt.finished.finally === 'function') {
            vt.finished['finally'](unlock);
        }
        // Safety net: always unlock even if `viewTransition.finished` never
        // resolves. Use `unlock` (not `cleanup`) here — this is the outgoing
        // document, so we must not strip `?vt=` before the destination reads it.
        window.setTimeout(unlock, 700);
    }

    function onReveal(event) {
        var vt = event.viewTransition;
        if (!vt) return;
        lockScroll();
        if (vt.finished && typeof vt.finished.finally === 'function') {
            vt.finished['finally'](cleanup);
        }
        // Safety net: always clean up even if `viewTransition.finished` never
        // resolves, so classes/scroll-lock never linger past the transition.
        window.setTimeout(cleanup, 700);
    }

    window.addEventListener('pageswap', onSwap);

    window.addEventListener('pagereveal', onReveal);

    // Safety net for a skipped transition: the inline <head> script may have set
    // `vt-active` (and a `nav-*` class) but `pagereveal` never fired, so nothing
    // scheduled cleanup. If we load with `vt-active` still present, clean up.
    if (document.documentElement.classList.contains('vt-active')) {
        window.setTimeout(cleanup, 700);
    }
}());
