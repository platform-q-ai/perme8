// Service Worker for Jarga PWA
const CACHE_VERSION = 'jarga-v1';
const STATIC_CACHE = `${CACHE_VERSION}-static`;
const DYNAMIC_CACHE = `${CACHE_VERSION}-dynamic`;
const OFFLINE_PAGE = '/offline.html';

// Assets to cache on install
const STATIC_ASSETS = [
  '/',
  '/assets/css/app.css',
  '/assets/js/app.js',
  '/favicon.svg',
  '/favicon-96x96.png',
  '/web-app-manifest-192x192.png',
  '/web-app-manifest-512x512.png',
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...');
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      console.log('[Service Worker] Caching static assets');
      return cache.addAll(STATIC_ASSETS.filter(url => url !== OFFLINE_PAGE));
    }).then(() => {
      console.log('[Service Worker] Skip waiting');
      return self.skipWaiting();
    }).catch((error) => {
      console.error('[Service Worker] Cache failed:', error);
    })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName.startsWith('jarga-') && cacheName !== STATIC_CACHE && cacheName !== DYNAMIC_CACHE) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      console.log('[Service Worker] Claiming clients');
      return self.clients.claim();
    })
  );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') {
    return;
  }

  // Skip LiveView WebSocket connections
  if (url.pathname.startsWith('/live/websocket')) {
    return;
  }

  // Skip Phoenix LiveView long polling
  if (url.pathname.includes('/live/') && url.search.includes('_csrf_token')) {
    return;
  }

  // Strategy for static assets: Cache First
  if (
    request.destination === 'style' ||
    request.destination === 'script' ||
    request.destination === 'image' ||
    request.destination === 'font' ||
    url.pathname.startsWith('/assets/')
  ) {
    event.respondWith(cacheFirstStrategy(request));
    return;
  }

  // Strategy for HTML pages: Network First
  if (request.destination === 'document' || request.headers.get('accept')?.includes('text/html')) {
    event.respondWith(networkFirstStrategy(request));
    return;
  }

  // Strategy for API calls: Network First with short cache
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(networkFirstStrategy(request, DYNAMIC_CACHE, 60000)); // 1 minute cache
    return;
  }

  // Default: Network First
  event.respondWith(networkFirstStrategy(request));
});

// Cache First Strategy - Try cache, fallback to network
async function cacheFirstStrategy(request) {
  try {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }

    const networkResponse = await fetch(request);
    if (networkResponse && networkResponse.status === 200) {
      const cache = await caches.open(STATIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.error('[Service Worker] Cache first strategy failed:', error);
    return new Response('Offline', { status: 503, statusText: 'Service Unavailable' });
  }
}

// Network First Strategy - Try network, fallback to cache
async function networkFirstStrategy(request, cacheName = DYNAMIC_CACHE, maxAge = null) {
  try {
    const networkResponse = await fetch(request);

    if (networkResponse && networkResponse.status === 200) {
      const cache = await caches.open(cacheName);
      cache.put(request, networkResponse.clone());
    }

    return networkResponse;
  } catch (error) {
    console.log('[Service Worker] Network failed, trying cache:', error);

    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      // Check if cached response is too old
      if (maxAge) {
        const cachedDate = new Date(cachedResponse.headers.get('date'));
        const now = new Date();
        if (now - cachedDate > maxAge) {
          console.log('[Service Worker] Cached response too old');
          return offlineResponse(request);
        }
      }
      return cachedResponse;
    }

    return offlineResponse(request);
  }
}

// Offline response fallback
function offlineResponse(request) {
  if (request.destination === 'document' || request.headers.get('accept')?.includes('text/html')) {
    return caches.match(OFFLINE_PAGE).then(response => {
      return response || new Response(
        '<html><body><h1>Offline</h1><p>Please check your internet connection.</p></body></html>',
        { headers: { 'Content-Type': 'text/html' } }
      );
    });
  }

  return new Response('Offline', {
    status: 503,
    statusText: 'Service Unavailable'
  });
}

// Handle messages from clients
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data && event.data.type === 'CLEAR_CACHE') {
    event.waitUntil(
      caches.keys().then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => caches.delete(cacheName))
        );
      })
    );
  }
});
