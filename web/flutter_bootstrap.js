{{flutter_js}}
{{flutter_build_config}}

// No `serviceWorkerSettings`: Flutter's service worker is deprecated and
// unregisters itself, which would also remove `offline_sw.js` (registered in
// boot.js). See the header of offline_sw.js.
_flutter.loader.load();
