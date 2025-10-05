const CACHE_PREFIX = 'chronicae-vision-precache';
let activeCacheName = `${CACHE_PREFIX}-bootstrap`;

const scopeUrl = new URL(self.registration.scope);

const toAbsoluteURL = (path) => new URL(path, scopeUrl).toString();

async function loadPrecacheManifest() {
    const response = await fetch('./precache-manifest.json', {
        cache: 'no-cache',
        credentials: 'same-origin'
    });
    if (!response.ok) {
        throw new Error(`Failed to load precache manifest: ${response.status}`);
    }
    const manifest = await response.json();
    const assets = Array.isArray(manifest.assets) ? manifest.assets : [];
    const version = typeof manifest.version === 'string' ? manifest.version : 'v1';
    return {
        version,
        assets
    };
}

self.addEventListener('install', (event) => {
    event.waitUntil((async () => {
        try {
            const manifest = await loadPrecacheManifest();
            activeCacheName = `${CACHE_PREFIX}-${manifest.version}`;
            const cache = await caches.open(activeCacheName);
            const urls = manifest.assets
                .map((asset) => asset.path)
                .filter((path) => typeof path === 'string')
                .map((path) => toAbsoluteURL(path));
            const uniqueUrls = Array.from(new Set([...urls, toAbsoluteURL('index.html')]));
            await cache.addAll(uniqueUrls);
        } catch (error) {
            console.error('[Chronicae SW] precache failed', error);
        }
    })());
    self.skipWaiting();
});

self.addEventListener('activate', (event) => {
    event.waitUntil((async () => {
        try {
            const manifest = await loadPrecacheManifest();
            const expectedCache = `${CACHE_PREFIX}-${manifest.version}`;
            activeCacheName = expectedCache;
            const keys = await caches.keys();
            await Promise.all(
                keys
                    .filter((key) => key.startsWith(CACHE_PREFIX) && key !== expectedCache)
                    .map((key) => caches.delete(key))
            );
        } catch (error) {
            console.warn('[Chronicae SW] activate cleanup skipped', error);
        }
    })());
    self.clients.claim();
});

self.addEventListener('fetch', (event) => {
    if (event.request.method !== 'GET') {
        return;
    }

    const url = new URL(event.request.url);
    if (url.origin !== scopeUrl.origin) {
        return;
    }

    if (!url.pathname.startsWith(scopeUrl.pathname)) {
        return;
    }

    event.respondWith((async () => {
        const cacheName = activeCacheName;
        const cache = await caches.open(cacheName);
        const cached = await cache.match(event.request);
        if (cached) {
            return cached;
        }

        try {
            const networkResponse = await fetch(event.request);
            if (networkResponse && networkResponse.ok) {
                const cloned = networkResponse.clone();
                event.waitUntil(cache.put(event.request, cloned));
            }
            return networkResponse;
        } catch (error) {
            if (event.request.mode === 'navigate') {
                const fallback = await cache.match(toAbsoluteURL('index.html'));
                if (fallback) {
                    return fallback;
                }
            }
            throw error;
        }
    })());
});
