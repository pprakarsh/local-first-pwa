# Architecture

The pattern. Deliberately dumb: no virtual DOM, no reactivity, no framework.

## Module layout

```
index.html          shell: header, #viewRoot, #tabBar, #modalRoot, #toast
css/styles.css
sw.js               service worker (network-first)
manifest.webmanifest
js/app.js           boot, render loop, delegated events, ACTIONS registry
js/store.js         ALL state and persistence, plus domain logic
js/db.js            promise wrapper over IndexedDB
js/ui.js            modal / toast / confirm / clipboard primitives
js/util.js          formatting + parsing helpers, APP_VERSION
js/format.js        model -> display strings (see "why this exists" below)
js/views/*.js       one module per screen: render() + an actions map
test/               dev-only suites
```

### Dependency direction, enforced by a test

```
js/app.js  (composition root -- may import anything)
   |
js/views/*  ->  store, format, ui, util
   |
store, format, exportimport  ->  db, util
```

**Nothing outside `js/views/` may import a view**, except `app.js`.

`js/format.js` exists precisely because of this rule: exporters need the same wording the screen
uses, and putting those helpers in a view would force a core module to import upward. Create it as
soon as a second consumer wants a display string.

## The render loop

```
tap -> delegated handler -> ACTIONS[name](dataset) -> store mutator
     -> persist -> emit() -> render() -> viewRoot.innerHTML = view.render()
```

```js
// js/app.js
let lastScreen = '';
export function render() {
  if (!state.ready) return;
  const view = VIEWS[state.tab];
  const screen = `${state.tab}|${state.nav.id || ''}`;
  const y = window.scrollY;
  document.getElementById('viewRoot').innerHTML = view.render();
  window.scrollTo(0, screen === lastScreen ? y : 0);   // keep place, reset on new screen
  lastScreen = screen;
  document.querySelectorAll('#tabBar .tab').forEach((b) => {
    b.classList.toggle('active', b.dataset.tab === state.tab);
  });
}
subscribe(render);
```

### The consequences you must design around

**A re-render destroys every input in the view.** Three rules follow:

1. Live field edits persist **silently** — write to the store and IndexedDB but do not `emit()`.
2. If you re-render on blur so derived values catch up, defer it and bail when focus is still
   inside a field:

```js
document.addEventListener('blur', (ev) => {
  if (!ev.target?.dataset?.f) return;
  setTimeout(() => {
    const ae = document.activeElement;
    if (ae && ['INPUT', 'TEXTAREA', 'SELECT'].includes(ae.tagName)) return;
    render();
  }, 0);
}, true);
```

3. Anything that must change a value **without** losing focus (a stepper, a quick-pick) writes
   `input.value` directly and dispatches an `input` event so the silent-save path runs with no
   re-render. Build the event from the element's own realm so it also works under jsdom:

```js
const Ev = input.ownerDocument?.defaultView?.Event || Event;
input.dispatchEvent(new Ev('input', { bubbles: true }));
```

## Event routing

One delegated listener. No per-element listeners except inside modals, wired after the modal opens.

| Attribute | Meaning |
|---|---|
| `data-action="name"` | every tap; `ACTIONS[name]({...dataset})` |
| `data-f` inside `[data-row]` | a field on a sub-record; silent save |
| `data-sf` | a field on the parent record; silent save |
| `data-tab` | tab bar |

```js
const ACTIONS = { ...mainActions, ...settingsActions };   // names must be globally unique

document.addEventListener('click', async (ev) => {
  const el = ev.target.closest('[data-action]');
  if (!el) return;
  const fn = ACTIONS[el.dataset.action];
  if (!fn) return;
  ev.preventDefault();
  try { await fn({ ...el.dataset }); }
  catch (err) { console.error(err); toast(err?.message || 'Something went wrong'); }
  render();
});
```

A test asserts: no duplicate action names (one would silently shadow), every `data-action` in the
source has a handler, and every handler is reachable from markup.

## State

```js
export const state = {
  ready: false,
  items: [],        // your records, sorted however you display them
  active: null,     // the in-progress instance, if your app has one
  editId: null,     // a past instance opened for correction
  settings: { ...DEFAULTS },
  tab: 'main',
  nav: {},          // per-tab sub-navigation
};

const listeners = new Set();
export const subscribe = (fn) => { listeners.add(fn); return () => listeners.delete(fn); };
export const emit = () => listeners.forEach((fn) => fn());
```

### The `working()` indirection — add it on day one

If your app can edit both a live instance and a past one, every mutator must resolve its target
through one function:

```js
export function working() {
  if (state.editId) return state.items.find((x) => x.id === state.editId) || null;
  return state.active;
}
```

This is what lets the *same* editing UI serve both. Mutators must never reference `state.active`
directly — that bug is invisible until someone edits history and nothing saves.

### Mutators

Persist first, then emit. Never leave the write for later; a mid-use reload must find the truth.

```js
async function touch({ silent = false } = {}) {
  const s = working();
  if (!s) return;
  await dbPut('items', s);
  if (!silent) emit();
}

export async function updateField(rowId, patch, opts) {
  const s = working();
  if (!s) return;
  Object.assign(s.rows.find((r) => r.id === rowId), patch);
  await touch(opts);           // { silent: true } from an input handler
}
```

## Persistence

IndexedDB, one version, a store per noun plus a `meta` key-value store.

```js
db.createObjectStore('items', { keyPath: 'id' }).createIndex('createdAt', 'createdAt');
db.createObjectStore('meta', { keyPath: 'key' });   // settings, activeId, tokens
```

Keep secrets (API tokens) under their own `meta` key, **never** inside `settings`, so an exported
backup cannot contain them. Assert that with a test.

localStorage is the wrong choice: ~5 MB, synchronous, and more readily evicted.

## Template and instance

The shape that most of these apps want:

```js
template = { id, name, description, rows: [rowTemplate], createdAt, updatedAt }
instance = { id, templateId, templateName, startedAt, finishedAt,
             rows: [{ ...rowTemplate, sourceId, entries: [] }], notes }
```

- `startInstance()` **snapshots** `template.rows` into `instance.rows`, giving each a fresh `id` and
  keeping `sourceId` pointing at the template row.
- Mid-use edits touch only the instance. Offer an explicit "save back to template" action; use
  `sourceId` so template row IDs stay stable.
- Record units, settings and any other context **on the record as it is created**, so changing a
  setting later never rewrites history.

## Normalisation is the import boundary

```js
export function normalizeRow(raw = {}) {
  return {
    id: raw.id || uid('r'),
    name: String(raw.name || raw.title || 'Untitled').trim(),
    count: num(raw.count ?? raw.qty) ?? 1,
    notes: (Array.isArray(raw.notes) ? raw.notes.join('\n') : String(raw.notes ?? '')).trim(),
  };
}
```

Absorb aliases, ignore unknown keys (which makes `"//"` comment keys work in hand-written JSON),
and default every new field so old backups still load.

**If one key accepts two shapes, make the discriminator explicit.** A field that is "a count or a
list" will eventually read logged data back as configuration:

```js
const isPlan = Array.isArray(raw.sets)
  && !raw.sets.some((x) => x && typeof x === 'object' && ('id' in x || 'done' in x));
```

## Modals

One `#modalRoot`, innerHTML-replaced, with a submit handler that reads every `[name]` field.
Closing a modal must `emit()`, because a submit may have changed the tab or the data behind it.

Dynamic content inside a modal (adding grid rows) is wired directly after `openModal()` returns the
element — this is the one place direct listeners are correct, since the modal is outside the render
loop.
