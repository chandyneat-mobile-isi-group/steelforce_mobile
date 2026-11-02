// App-shell cache: lets the installed web app open without a connection.
//
// Caches the app's OWN static files only (index.html, main.dart.js, CanvasKit,
// sqlite3.wasm, fonts, images) — never business data. ADR-010 forbids business
// data at rest in the browser; every API call is to another origin and passes
// straight through this worker untouched, as do Google Maps and fonts.
//
// Network-first: online, every file comes fresh from the server, so a new
// deploy is picked up on the next load with no versioning scheme to maintain.
// The cache is only the fallback when the network fails.
//
// Flutter's own `flutter_service_worker.js` is a deprecated self-unregistering
// worker; `web/flutter_bootstrap.js` deliberately does not register it, because
// it would replace and then unregister this one.

const CACHE = 'steelforce-shell-v1';

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names.filter((n) => n !== CACHE).map((n) => caches.delete(n)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  const scope = new URL(self.registration.scope);
  if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) {
    return;
  }

  event.respondWith(networkFirst(request));
});

async function networkFirst(request) {
  const cache = await caches.open(CACHE);
  try {
    const response = await fetch(request);
    if (response.ok && response.type === 'basic') {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const cached = await cache.match(request, { ignoreSearch: true });
    if (cached) return cached;
    // Any in-app route opened offline falls back to the cached shell.
    if (request.mode === 'navigate') {
      const shell = await cache.match(self.registration.scope);
      if (shell) return shell;
    }
    throw error;
  }
}
