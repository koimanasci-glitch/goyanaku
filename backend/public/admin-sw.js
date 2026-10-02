// No fetch handler: authenticated pages, customer data and secrets are never cached.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
