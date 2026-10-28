# Testing without a browser

Node + jsdom + fake-indexeddb tests the real modules, including the real UI, with no browser and no
network. Dev-only: `test/package.json`, never shipped.

```json
{
  "name": "app-tests", "private": true, "type": "module",
  "scripts": { "test": "node style.mjs && node smoke.mjs && node dom.mjs" },
  "devDependencies": { "jsdom": "24.1.3", "fake-indexeddb": "6.0.0" }
}
```

## The four suites

| Suite | Covers | Cannot cover |
|---|---|---|
| `style.mjs` | computed `display` of overlays, CSS sanity, the guards below | layout, spacing, anything visual |
| `smoke.mjs` | store logic, normalisation, import/export round trips | the UI |
| `dom.mjs` | the real UI: clicks, typing, focus, modals, whole flows | touch ergonomics, real Safari |
| `sync.mjs` | sync against a faked API | the real API's behaviour |

## Harness boilerplate

```js
import { JSDOM } from 'jsdom';
import 'fake-indexeddb/auto';
import { readFileSync } from 'node:fs';

const APP = new URL('..', import.meta.url).pathname.replace(/\/$/, '');
const dom = new JSDOM(readFileSync(`${APP}/index.html`, 'utf8'), {
  url: 'https://example.test/', pretendToBeVisual: true,
});
global.window = dom.window;
global.document = dom.window.document;
Object.defineProperty(global, 'navigator', { value: dom.window.navigator, configurable: true });
global.Blob = dom.window.Blob;
global.URL = dom.window.URL;                     // or downloads cross realms and fail
dom.window.scrollTo = () => {};                  // jsdom does not implement scrolling
dom.window.HTMLAnchorElement.prototype.click = function () {};   // capture downloads

let failures = 0;
const ok = (c, l) => { if (c) console.log(`  ok   ${l}`); else { failures++; console.log(`  FAIL ${l}`); } };
```

Gotchas that will cost you an hour each:

- `global.navigator` is read-only in Node 22 — use `Object.defineProperty`.
- Set `global.URL` from the jsdom window, or `URL.createObjectURL` is the wrong realm.
- jsdom does not implement `window.scrollTo` or `document.execCommand` — stub them.
- `new Event(...)` inside app code resolves against the Node realm. Build events from
  `el.ownerDocument.defaultView.Event` in the app, which fixes the test *and* is more correct.

## Driving the real UI

```js
async function click(sel, label = sel) {
  const el = document.querySelector(sel);
  if (!el) { failures++; console.log(`  FAIL no element: ${label}`); return false; }
  el.dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true, cancelable: true }));
  await new Promise((r) => setTimeout(r, 40));     // let the async action settle
  return true;
}
async function type(sel, value) {
  const el = document.querySelector(sel);
  el.value = value;
  el.dispatchEvent(new dom.window.Event('input', { bubbles: true }));
  await new Promise((r) => setTimeout(r, 25));
}
await import(`${APP}/js/app.js`);                   // boots itself
```

Submit a modal by dispatching `submit` on `#modalForm`.

## The guards — the real payoff

These enforce rules documentation cannot. **Verify each one fails when its invariant is broken**,
or you have written a test that proves nothing.

```js
// 1. overlays must obey the hidden attribute (catches a permanent full-screen backdrop)
const dom2 = new JSDOM(html.replace('</head>', `<style>${css}</style></head>`));
for (const id of ['modalRoot', 'toast']) {
  const el = dom2.window.document.getElementById(id);
  ok(getComputedStyle(el).display === 'none', `#${id} hides while [hidden]`);
  el.removeAttribute('hidden');
  ok(getComputedStyle(el).display !== 'none', `#${id} shows when shown`);
}

// 2. version and service worker cache must agree
ok(cacheName === `app-v${appVersion}`, 'sw CACHE matches APP_VERSION');

// 3. every shipped file is in the sw ASSETS list (else offline silently breaks)
ok(missing.length === 0, `sw lists every file: ${missing.join(', ')}`);

// 4. action registry: no duplicates, no orphans, no dead handlers
ok(orphanUsed.length === 0, 'every data-action has a handler');
ok(unreachable.length === 0, 'every handler is reachable');

// 5. dependency direction
ok(upward.length === 0, 'no core module imports a view');

// 6. docs reference only real files, and document every module
// 7. no module over 1000 lines; no stray console.log
// 8. shell scripts are pure ASCII
```

## Test discipline

- **A suite passes when it exits 0, and for no other reason.** Never decide a run was clean by
  reading its output for `PASSED` or grepping it for `FAIL`. A suite that dies before the first
  assertion — a syntax error, a bad import, a throw at module scope — prints neither word, and an
  output-matching check reads that silence as success. Chain the suites with `&&` and let a
  non-zero status stop you. Running one alone, branch on the status:
  `node smoke.mjs >/tmp/smoke.log 2>&1 && echo PASS || echo FAIL`.
- **Every bug fix gets a test that fails without the fix.** This is the habit that keeps the
  codebase honest, and it is how most real bugs in this pattern were found.
- **Test the behaviour a user would notice**, not the implementation.
- **Put the actual value in the failure message** — `` `got ${x}` `` — or a red test tells you
  nothing.
- **Test the claims your documentation makes.** Writing a precise spec and then asserting the code
  matches it finds bugs in both. A docs-driven test caught an ambiguous unit rule that had been
  wrong since the first commit.
- Fixtures drift: a test that depends on state mutated by a later section will break confusingly.
  Give each section its own fixture.
