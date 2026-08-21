---
layout: null
---
// Loads Google Analytics 4 (gtag.js) using the measurement ID configured as
// `google_analytics` in _config.yml. No-op if that value is unset, so
// analytics can be disabled entirely (e.g. locally) by removing the config
// key rather than editing this file.
(function () {
  var measurementId = '{{ site.google_analytics }}';

  if (!measurementId) {
    return;
  }

  var script = document.createElement('script');
  script.async = true;
  script.src = 'https://www.googletagmanager.com/gtag/js?id=' + measurementId;
  document.head.appendChild(script);

  window.dataLayer = window.dataLayer || [];

  window.gtag = function () {
    window.dataLayer.push(arguments);
  };

  window.gtag('js', new Date());
  window.gtag('config', measurementId);
})();
