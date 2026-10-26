---
name: local-first-pwa
description: Build a personal app that runs on iOS, Android and any desktop browser as an installable PWA, with no framework, no build step and no runtime dependencies, storing data locally in IndexedDB and deploying as static files to free hosting. Covers the architecture (one store, string-rendering views, delegated events), the jsdom + fake-indexeddb test harness that tests without a browser, mechanical guards that keep the codebase maintainable, optional device-to-device sync through a secret GitHub Gist with conflict guards, GitHub Pages deployment, and the platform limits that make certain features impossible. Use when asked to build a tracker, logger, planner, calculator, checklist or similar single-user tool that must work on a phone and a laptop; when asked to make something work offline or installable; when choosing between a PWA and a native app; when asked to avoid a build step or dependencies; or when adding local persistence, backup/restore, export, or cross-device sync to such an app.
version: 1.0.0
tags:
- skill
- pwa
- offline-first
- local-first
- indexeddb
- ios
- android
- static-hosting
- no-build-step
---

# Local-first PWA

A method for building a single-user app that installs on a phone, works offline, keeps data on the
device, and still runs in five years because it has no toolchain to rot.

Proven on a workout tracker: ~4,000 lines of app code, 637 assertions, zero runtime dependencies,
deployed free on GitHub Pages, installed on iOS from Safari.

## When this is the right method

| Use it when | Do not use it when |
|---|---|
| One user, their own data | Multiple users must share or see each other's data |
| A phone and maybe a laptop | You need an Apple Watch, widget or Live Activity |
| Offline must work | You need background location, HealthKit, BLE or push notifications |
| You want no server and no account | You need server-side compute or secrets |
| Longevity matters more than ecosystem | You want a large component library |

Read `reference/platform-limits.md` **before promising any feature**. The limits are hard, and
discovering them after building is the single most expensive mistake here.

## Hard rules

These are what make the method work. Breaking one quietly converts the project into an ordinary
web app with all the maintenance that implies.

1. **No runtime dependencies, no build step, no framework.** Plain ES modules served as static
   files. Dev-only test dependencies live in `test/package.json` and never ship.
2. **Local-first.** The app must be fully usable with no network and no account. Sync, if added, is
   optional and additive — never a dependency.
3. **One store owns all state and all persistence.** Everything else reads it and calls its
   mutators.
4. **Views are pure functions returning HTML strings.** No DOM references, no local state.
5. **All events are delegated** from `document` via `data-action` attributes, routed through one
   registry.
6. **Every rule that can be a test must be a test.** Prose decays silently; a failing test does
   not. See `reference/testing.md`.
7. **Shell scripts stay ASCII.** macOS ships bash 3.2, which folds the bytes of a non-ASCII
   character following a variable into the variable name.
8. **Bump the app version and the service worker cache name together**, enforced by a test.

## Workflow

### 1. Scaffold

```bash
~/.kiro/skills/local-first-pwa/scripts/scaffold.sh ~/my-app "My App"
cd ~/my-app && (cd test && npm install && npm test)
python3 -m http.server 8000 --bind 127.0.0.1    # http://localhost:8000
```

That produces a working, installable, tested skeleton: app shell, store, IndexedDB wrapper, two
tabs, service worker, manifest, generated icons, both test suites with the guards already wired,
`deploy.sh`, and the three docs. Do not hand-write this boilerplate.

`file://` will not work — ES modules are blocked by CORS. Always serve over `localhost`.

### 2. Model the data before writing UI

Decide the two or three nouns and which one is a **template** versus an **instance**. Getting this
wrong is the expensive mistake, because everything else follows from it.

- A template is reusable intent (a routine, a recipe, a checklist definition).
- An instance is one performance of it, created by **snapshotting** the template.
- Snapshot, never reference: editing an instance must not rewrite history, and editing a template
  must not rewrite past instances.

Write `normalizeX()` functions as the single import boundary. They accept loosely-shaped input
(hand-written JSON, LLM output, older backups) and return the canonical shape with defaults. This
is your only compatibility layer — there is no migration framework and you do not need one if new
fields are always optional.

### 3. Build the first vertical slice

One screen that creates a record, lists it, and persists across reload. Verify persistence by
reloading before adding a second feature.

Follow `reference/architecture.md` for the store/view/event pattern and the re-render rules. The
single most important constraint: **a re-render destroys every input in the view**, so live field
edits must persist without emitting, and anything that re-renders on blur must defer and bail while
focus is still inside a field.

### 4. Add export and backup early

Before accumulating data worth losing. A full JSON backup that round-trips verbatim — same IDs —
is what makes device transfer, debugging and user trust possible. CSV for spreadsheets. Per-record
Markdown if the data is worth reading.

Treat the CSV column order as a published contract: append columns, never insert.

### 5. Deploy and install on the phone

See `reference/deploy.md`. Do this at the end of the first day, not at the end of the project —
the gap between "works on localhost" and "works installed on a phone" is where the surprises are.

### 6. Add sync only if a second device is real

See `reference/sync.md` for the secret-Gist blob pattern with conflict guards. Do not build sync
speculatively; the export/import path already covers one-off transfer.

## Verification gates

Never report success on an unverified claim. For this method specifically:

- `npm test` green, including the guards.
- Served over HTTP with correct MIME types — `.js` must be `text/javascript` or
  `application/javascript`, or ES modules will not load.
- Reload the page and confirm data survives.
- After deploying, fetch the live version marker and confirm it matches what you shipped.
- State plainly what you could **not** verify. The harness cannot check visual layout, touch
  ergonomics, real iOS Safari behaviour, or any real third-party API.

## The traps, in the order they will bite

Each of these cost real debugging time. Full detail in the reference docs.

1. **A CSS `display` rule beats the `hidden` attribute.** `#overlay{display:flex}` outranks the UA
   `[hidden]{display:none}`, so your modal backdrop covers the app forever. Use
   `#overlay:not([hidden]){display:flex}`.
2. **Cache-first service workers serve stale code for one more load.** A change appears not to have
   happened until the second reload. Go network-first with a cache fallback, and show a build number
   in the UI so you can tell a stale cache from a real bug.
3. **Re-rendering on blur steals focus** from the field the user is tabbing into.
4. **Overloaded fields.** If one key accepts two shapes (a count or a list), logged data can be read
   back as configuration. Make the discriminator explicit.
5. **Unitless numbers are ambiguous.** Decide per field whether a bare number means seconds or
   minutes, and make numbers and numeric strings behave identically.
6. **Comparing local timestamps to a remote clock.** For sync, always compare against *this*
   device's last-sync time, and use `>=` so a same-millisecond write counts as unsynced.
7. **Sorts that can tie** resolve by iteration order, which is a silent, surprising default. Give
   every sort an explicit second key.
8. **Non-ASCII characters in shell scripts** break under macOS bash 3.2.
9. **iOS evicts storage after 7 idle days** unless the app was added to the home screen. Installing
   is not optional for real use.

## Reference

| File | Read it when |
|---|---|
| `reference/architecture.md` | Setting up the store, views, event routing, render loop |
| `reference/testing.md` | Writing the harness and the mechanical guards |
| `reference/platform-limits.md` | Before promising any feature, and when choosing PWA vs native |
| `reference/deploy.md` | Hosting, installing on a phone, service worker discipline |
| `reference/sync.md` | Adding cross-device sync or backup/restore |
| `reference/maintainability.md` | Writing the docs and guards that keep it alive |
