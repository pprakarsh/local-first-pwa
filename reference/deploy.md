# Hosting, installing, and service worker discipline

## Free hosting that works

The app is static files — typically under 200 KB. Every option below is free with HTTPS, which iOS
requires for a real install.

| Host | Why pick it |
|---|---|
| **Cloudflare Pages** | Unmetered bandwidth and requests; drag-and-drop or git |
| **GitHub Pages** | Simplest if the code is already in git; free from a public repo |
| **Netlify Drop** | Drag a folder onto the page, URL in seconds, no git |
| **Vercel** | Fine, but aimed at frameworks; no advantage here |

Nothing of the user's travels to the host. It serves the app; the data stays in IndexedDB.

**If the repo is public, the code is public.** Keep exported backups out of the repo folder — they
contain real data; the app code does not.

## GitHub Pages in two commands

`scripts/scaffold.sh` writes a `deploy.sh` that creates the repo, pushes, enables Pages and prints
the URL. It also guards against the two mistakes that matter on a shared machine:

- aborts if `gh` is authenticated as an unexpected account;
- aborts if the latest commit carries a corporate email address.

```bash
gh auth login        # once, interactive, needs a browser
./deploy.sh          # re-run to ship an update
```

Check the identity on the commits **before** the first push. Rewriting unpushed local history is
trivial; rewriting pushed history is not.

```bash
git config user.name  "Your Name"      # repo-local, leaves the global config alone
git config user.email "you@personal.example"
```

A public repo publishes whatever address the commits carry. GitHub's
`username@users.noreply.github.com` is the private alternative.

## Service worker discipline

**Go network-first with a cache fallback.** Cache-first is a trap during development: the outgoing
worker keeps serving the old JS for one more load, so a change appears not to have happened until
the second reload. The cost of network-first is one round trip when online; offline still works
fully from the cache.

```js
const CACHE = 'app-v1';           // bump with APP_VERSION, enforced by a test
const ASSETS = ['.', 'index.html', 'css/styles.css', 'js/app.js', /* every module */];

self.addEventListener('install', (e) => e.waitUntil(
  caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting())));

self.addEventListener('activate', (e) => e.waitUntil(
  caches.keys()
    .then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim())));

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;
  e.respondWith(
    fetch(req).then((res) => {
      if (res && res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
      return res;
    }).catch(async () => (await caches.match(req))
      || (req.mode === 'navigate' ? caches.match('index.html') : undefined)
      || new Response('Offline and not cached', { status: 504 })),
  );
});
```

Three non-negotiables:

1. **Every shipped file is in `ASSETS`** — a test asserts it, or adding a module silently breaks
   offline.
2. **Bump `CACHE` with the app version** — a test asserts they agree.
3. **Show the version in the UI.** Without a visible build number you cannot tell a stale cache
   from a real bug, and you will waste an afternoon on exactly that.

## Keep relative paths

`"start_url": "."`, `"scope": "."`, relative `<link>`/`<script>` hrefs, relative `ASSETS`, and
`navigator.serviceWorker.register('sw.js')`. That makes a subpath deploy such as
`https://user.github.io/my-app/` work unchanged.

## Clearing a stuck service worker, safely

DevTools → Application → Service Workers → **Unregister**, then reload.

**Never tell a user to "Clear site data"** — that deletes IndexedDB, which is all of their data.
Unregistering the worker only drops cached copies of the app files.

## Verify a deploy, don't assume it

```bash
curl -s -o /dev/null -w '%{http_code} %{content_type}\n' https://user.github.io/my-app/js/app.js
curl -s https://user.github.io/my-app/js/util.js | grep APP_VERSION
```

`.js` must come back as `text/javascript` or `application/javascript`, or ES modules will not load.
Then confirm the live version marker matches what you shipped.
