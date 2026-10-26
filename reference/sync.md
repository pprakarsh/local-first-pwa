# Backup, transfer and optional sync

Build these in order. Each is useful on its own, and each is a prerequisite for the next.

## 1. A backup that round-trips verbatim

The foundation. Everything else is built on it.

```js
export function backupObject() {
  return {
    schema: 'my-app/v1',
    exportedAt: new Date().toISOString(),
    counts: dataFingerprint(),          // self-verification, see below
    settings: state.settings,
    activeId: state.active?.id ?? null, // so an in-progress instance travels too
    items: state.items,
  };
}
```

Two modes on import:

- **Replace** — wipe and restore verbatim, **same IDs**, so cross-references survive and a restored
  record exports byte-identically. This is what makes device cloning possible.
- **Merge** — add only what is missing, matching on ID, so re-importing the same file twice is a
  no-op rather than a duplicate.

Keep secrets out. Store API tokens under their own `meta` key, never in `settings`, and assert with
a test that an export cannot contain the token.

### Self-verification

Embed counts in the backup and compare after restoring. Surface the same numbers in the UI so a
user can eyeball both devices.

```js
export const dataFingerprint = () => ({
  items: state.items.length,
  rows: state.items.reduce((n, i) => n + i.rows.length, 0),
  oldest: Math.min(...dates), newest: Math.max(...dates),
});
```

## 2. Also export CSV and Markdown

CSV for spreadsheets — one row per leaf record, with the numeric columns left **empty** rather than
filled with prose like "not recorded", so averages still work. Treat the column order as a published
contract: append columns, never insert.

Markdown per record, for reading and sharing.

## 3. Sync through a secret GitHub Gist

Free, no server, and every push becomes a gist revision — a restorable history for nothing.

- `POST /gists` with `{ public: false, files: { 'backup.json': { content } } }` creates it
- `PATCH /gists/{id}` updates it
- `GET /gists/{id}` reads it
- `api.github.com` is CORS-enabled, so the browser can call it directly
- Use a **classic** token with the single `gist` scope. GitHub's docs only unambiguously document
  that scope; fine-grained token support for gists has been inconsistent. A 403 is the tell.

The token is entered by the user and stored in `meta`, so it never appears in source or in a backup.

### Blob sync, and its one real danger

The whole dataset is one JSON file, so a push or pull replaces everything. That is fine for one
person with one active device, and the danger is obvious: the stale device overwrites the fresh one.
So **both directions must refuse to act blindly**:

```js
// Pull refuses when this device has work the backup predates.
const localNewer = unsyncedLocalChanges();
if (!force && localNewer.length) return { conflict: true, localNewer };

// Push refuses when the remote moved on since this device last synced.
if (remote.pushedAtMs > (sync.lastSeenRemoteMs || 0)) return { conflict: true, remote };
```

Show the user what is at stake — counts on both sides, and which records would be lost — and let
them force it. Gist revisions mean even a forced overwrite is recoverable.

### Two subtle bugs, both of which happened

**Never compare local timestamps against the remote clock.**

```js
// WRONG: a device with a fast clock makes your unpushed work look stale
localChangesSince(remote.pushedAtMs)
// RIGHT: compare against THIS device's own last sync
localChangesSince(Math.max(sync.lastPushedAt || 0, sync.lastPulledAt || 0))
```

**Use `>=`, not `>`.** A record saved in the same millisecond as the sync marker would otherwise
count as already synced. Erring toward "unsynced" costs one extra question; erring the other way
silently destroys data.

Also: with no sync history at all (`0`), treat **everything** as unsynced, so a device with data is
never wiped without asking.

## 4. Pairing a second device

Typing a token on a phone keyboard is miserable. Emit one string carrying both credentials:

```js
export const pairingCode = () => btoa(JSON.stringify({ v: 1, t: sync.token, g: sync.gistId }));
```

Accept it in the token field, detect which it is, and — if the new device is empty — pull
immediately. One paste, no second tap. Tell the user it is as sensitive as a password.

## 5. Automatic triggers

Make each one switchable, and route them all through the same guards.

| Trigger | Default | Why |
|---|---|---|
| Push after completing an instance | off | One clear moment, with feedback |
| Push when the template library changes | **on** | Templates change rarely; debounce ~4s so a burst of edits is one push |
| Pull at launch | on | Cold start only |
| Pull on returning to the foreground | **on** | 5 min cooldown; skip while an instance is in progress |

The foreground pull matters more than it sounds: **an installed PWA resumes rather than
cold-starting**, so a launch-only pull can go days without running.

Watch for template changes by subscribing to the store and comparing a cheap signature
(`length:maxUpdatedAt`) rather than calling a push from each of the ten mutation sites, where one
will eventually be forgotten. Do **not** trigger on every leaf edit — that is revision spam.

```js
export function watchTemplates() {
  let last = signature();
  subscribe(() => { const s = signature(); if (s !== last) { last = s; schedulePush(); } });
}
```

A silent-save path that deliberately does not `emit()` is invisible to that watcher, so it must call
`schedulePush()` itself.

Report background results through a callback the app supplies, so the sync module needs no DOM and
stays unit-testable. Retry a queued push on the `online` event.

## What blob sync is not

It is not merge sync. Use two devices in parallel without syncing between and one side's data must
lose. If that becomes real, move to per-record push/pull keyed on `updatedAt` — and note you will
need **deletion tombstones**, or a merge resurrects everything the other device deleted.

## Testing sync with no network

Stub `global.fetch` with an in-memory fake of the API: a `Map` of gists, a valid-token check, and a
flag to emulate the 1 MB inlining limit. That covers push/pull round trips, both conflict
directions, clock skew, bad tokens, invalid JSON and offline — none of which you can trigger
reliably against the real API.
