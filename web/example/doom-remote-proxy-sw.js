const DOOM_BUNDLE_TARGET_URL = "https://cdn.dos.zone/custom/dos/doom.jsdos?anonymous=1";
const DOOM_EMULATORS_TARGET_BASE_URL = "https://cdn.jsdelivr.net/npm/emulators@8.3.9/dist/";
const DOOM_REMOTE_BUNDLE_SUFFIX = "/doom/remote/vendor/doom.jsdos";
const DOOM_REMOTE_EMULATORS_MARKER = "/doom/remote/emulators/";

self.addEventListener("install", (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

function mapRemoteTarget(pathname) {
  if (pathname.endsWith(DOOM_REMOTE_BUNDLE_SUFFIX)) {
    return DOOM_BUNDLE_TARGET_URL;
  }

  const markerIdx = pathname.indexOf(DOOM_REMOTE_EMULATORS_MARKER);
  if (markerIdx < 0) {
    return null;
  }
  const tail = pathname.slice(markerIdx + DOOM_REMOTE_EMULATORS_MARKER.length);
  if (!tail) {
    return null;
  }
  return `${DOOM_EMULATORS_TARGET_BASE_URL}${tail}`;
}

async function proxyRemote(request, targetUrl) {
  const upstreamHeaders = new Headers();
  const range = request.headers.get("range");
  if (range) {
    upstreamHeaders.set("range", range);
  }

  const upstream = await fetch(targetUrl, {
    method: request.method,
    headers: upstreamHeaders,
    mode: "cors",
    credentials: "omit",
    redirect: "follow",
    cache: request.cache,
  });

  const passthroughHeaderKeys = [
    "content-type",
    "content-length",
    "content-range",
    "accept-ranges",
    "cache-control",
    "etag",
    "last-modified",
  ];
  const headers = new Headers();
  for (const key of passthroughHeaderKeys) {
    const value = upstream.headers.get(key);
    if (value) {
      headers.set(key, value);
    }
  }
  headers.set("Cross-Origin-Resource-Policy", "same-origin");

  if (request.method === "HEAD") {
    return new Response(null, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers,
    });
  }

  const body = await upstream.arrayBuffer();
  return new Response(body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers,
  });
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET" && request.method !== "HEAD") {
    return;
  }

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) {
    return;
  }

  const target = mapRemoteTarget(url.pathname);
  if (!target) {
    return;
  }

  event.respondWith(
    proxyRemote(request, target).catch((err) => {
      const message = err instanceof Error ? err.message : String(err);
      return new Response(`DOOM remote proxy failed: ${message}`, {
        status: 502,
        headers: {
          "Content-Type": "text/plain; charset=utf-8",
          "Cache-Control": "no-store",
        },
      });
    }),
  );
});
