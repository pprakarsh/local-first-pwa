#!/usr/bin/env bash
# Scaffold a local-first PWA: installable, offline, no build step, no dependencies.
#
#   scaffold.sh <target-dir> ["App Name"]
#
# Produces a working app with two tabs, IndexedDB persistence, a service worker,
# generated icons, a test harness with the guards wired, deploy.sh and the docs.
#
# ASCII only: macOS bash 3.2 folds the bytes of a non-ASCII character following a
# variable into the variable name, which fails under `set -u`.
set -euo pipefail

TARGET="${1:-}"
APP_NAME="${2:-My App}"
[ -n "${TARGET}" ] || { echo "usage: scaffold.sh <target-dir> [\"App Name\"]"; exit 1; }
[ -e "${TARGET}" ] && { echo "refusing to overwrite existing path: ${TARGET}"; exit 1; }

SLUG="$(echo "${APP_NAME}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')"
mkdir -p "${TARGET}"/{css,js/views,icons,test}
cd "${TARGET}"

echo "Scaffolding '${APP_NAME}' in ${TARGET}"

# ---------------------------------------------------------------- index.html
cat > index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="${APP_NAME}">
<meta name="theme-color" content="#0f1115">
<title>${APP_NAME}</title>
<link rel="manifest" href="manifest.webmanifest">
<link rel="apple-touch-icon" href="icons/icon-192.png">
<link rel="icon" href="icons/icon-192.png">
<link rel="stylesheet" href="css/styles.css">
</head>
<body>
  <header id="appHeader"><h1 id="appTitle">${APP_NAME}</h1></header>
  <main id="viewRoot" aria-live="polite"></main>
  <nav id="tabBar">
    <button class="tab" data-tab="main" type="button"><span class="tab-ico">&#9634;</span><span>Items</span></button>
    <button class="tab" data-tab="settings" type="button"><span class="tab-ico">&#9881;</span><span>Settings</span></button>
  </nav>
  <div id="modalRoot" hidden></div>
  <div id="toast" hidden></div>
  <script type="module" src="js/app.js"></script>
</body>
</html>
HTML

# ---------------------------------------------------------------- css
cat > css/styles.css <<'CSS'
:root{
  --bg:#0f1115;--bg2:#171a21;--bg3:#1f2430;--line:#2b3240;
  --fg:#e9edf4;--fg2:#9aa6b8;--fg3:#6b7789;--accent:#4f8cff;--ok:#35c07e;--bad:#ff5d5d;
  --safe-t:env(safe-area-inset-top,0px);--safe-b:env(safe-area-inset-bottom,0px);
  --hdr-h:52px;--tab-h:56px;
}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
/* must beat the display rules below, which are more specific than UA [hidden] */
[hidden]{display:none !important}
html,body{margin:0;height:100%}
body{background:var(--bg);color:var(--fg);-webkit-text-size-adjust:100%;
  font:16px/1.4 -apple-system,BlinkMacSystemFont,system-ui,sans-serif;overscroll-behavior-y:none}
#appHeader{position:fixed;top:0;left:0;right:0;z-index:40;
  height:calc(var(--hdr-h) + var(--safe-t));padding:var(--safe-t) 12px 0;
  display:flex;align-items:center;justify-content:center;
  background:rgba(15,17,21,.88);backdrop-filter:blur(12px);border-bottom:1px solid var(--line)}
#appTitle{margin:0;font-size:17px;font-weight:650}
#viewRoot{padding:calc(var(--hdr-h) + var(--safe-t) + 12px) 12px
  calc(var(--tab-h) + var(--safe-b) + 24px);max-width:620px;margin:0 auto}
#tabBar{position:fixed;bottom:0;left:0;right:0;z-index:40;
  height:calc(var(--tab-h) + var(--safe-b));padding-bottom:var(--safe-b);display:flex;
  background:rgba(15,17,21,.94);backdrop-filter:blur(12px);border-top:1px solid var(--line)}
.tab{flex:1;background:none;border:0;color:var(--fg3);font:inherit;font-size:11px;font-weight:600;
  display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;
  cursor:pointer;touch-action:manipulation}
.tab-ico{font-size:17px;line-height:1}
.tab.active{color:var(--accent)}
h2{font-size:15px;margin:22px 0 8px;color:var(--fg2);font-weight:650;text-transform:uppercase}
h2:first-child{margin-top:0}
p.hint{color:var(--fg3);font-size:13px}
.card{background:var(--bg2);border:1px solid var(--line);border-radius:14px;padding:12px;margin-bottom:10px}
.row{display:flex;align-items:center;gap:8px}
.empty{text-align:center;color:var(--fg3);padding:34px 14px;font-size:14px}
.small{font-size:13px}.dim{color:var(--fg3)}.muted{color:var(--fg2)}
.btn{appearance:none;border:1px solid var(--line);background:var(--bg3);color:var(--fg);
  padding:10px 14px;border-radius:11px;font:inherit;font-size:15px;font-weight:600;
  cursor:pointer;display:inline-flex;align-items:center;justify-content:center;gap:6px;
  touch-action:manipulation}
.btn:active{opacity:.65}
.btn.primary{background:var(--accent);border-color:var(--accent);color:#fff}
.btn.danger{background:transparent;border-color:#5a2b33;color:var(--bad)}
.btn.ghost{background:transparent}
.btn.block{width:100%}
.btn.sm{padding:7px 10px;font-size:13px;border-radius:9px}
.btn-row{display:flex;gap:8px}.btn-row>*{flex:1}
input,select,textarea{font:inherit;font-size:16px;background:var(--bg3);color:var(--fg);
  border:1px solid var(--line);border-radius:10px;padding:10px;width:100%;appearance:none}
label.field{display:block;margin-bottom:10px}
label.field>span{display:block;font-size:12px;color:var(--fg2);margin-bottom:4px;font-weight:600}
.kv{display:flex;justify-content:space-between;gap:10px;font-size:14px;padding:5px 0;
  border-bottom:1px solid var(--line)}
.kv:last-child{border-bottom:0}.kv span:first-child{color:var(--fg2)}
.item{display:flex;align-items:center;gap:10px;padding:11px 12px;background:var(--bg2);
  border:1px solid var(--line);border-radius:12px;margin-bottom:8px}
.item .body{flex:1;min-width:0}
.item .nm{font-weight:650;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.item .sub{font-size:12px;color:var(--fg2);margin-top:2px}
.item.done .nm{text-decoration:line-through;color:var(--fg3)}
#modalRoot{position:fixed;inset:0;z-index:60;background:rgba(0,0,0,.6);
  align-items:flex-end;justify-content:center;backdrop-filter:blur(2px)}
#modalRoot:not([hidden]){display:flex}
.modal{width:100%;max-width:620px;max-height:88vh;overflow-y:auto;background:var(--bg);
  border:1px solid var(--line);border-radius:18px 18px 0 0;
  padding:16px 14px calc(16px + var(--safe-b))}
.modal h3{margin:0 0 14px;font-size:18px}
.modal-foot{display:flex;gap:8px;margin-top:16px}.modal-foot>*{flex:1}
#toast{position:fixed;z-index:80;left:50%;transform:translateX(-50%);
  bottom:calc(var(--tab-h) + var(--safe-b) + 24px);background:#2b3240;color:var(--fg);
  border:1px solid var(--line);padding:9px 15px;border-radius:999px;font-size:13px;
  font-weight:600;max-width:86vw;text-align:center}
CSS

# ---------------------------------------------------------------- js/util.js
cat > js/util.js <<'JS'
// Shared helpers. No dependencies, no DOM.

/** Bump this with the sw.js CACHE name on every shipped change. A test enforces it. */
export const APP_VERSION = '1';

export const uid = (p = 'id') =>
  `${p}_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;

export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

export function num(v) {
  if (v === '' || v === null || v === undefined) return null;
  const n = Number(String(v).trim().replace(',', '.'));
  return Number.isFinite(n) ? n : null;
}

export const fmtNum = (n) =>
  n === null || n === undefined || !Number.isFinite(Number(n))
    ? '' : String(Math.round(Number(n) * 1000) / 1000);

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export function fmtDate(ts) {
  const d = new Date(ts);
  return `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}
export function isoDate(ts) {
  const d = new Date(ts);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
export function relDay(ts) {
  const startOf = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const diff = Math.round((startOf(new Date()) - startOf(new Date(ts))) / 86400000);
  if (diff === 0) return 'Today';
  if (diff === 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return `${diff} days ago`;
  return fmtDate(ts);
}

export function download(filename, text, mime = 'text/plain') {
  const url = URL.createObjectURL(new Blob([text], { type: `${mime};charset=utf-8` }));
  const a = document.createElement('a');
  a.href = url; a.download = filename; a.rel = 'noopener';
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
}

export const csvCell = (v) => {
  const s = v === null || v === undefined ? '' : String(v);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
JS

# ---------------------------------------------------------------- js/db.js
cat > js/db.js <<'JS'
// Promise wrapper over IndexedDB. Stores: items (records) and meta (key/value).
const DB_NAME = 'APP_SLUG_PLACEHOLDER';
const DB_VERSION = 1;
let _dbp = null;

export function openDb() {
  if (_dbp) return _dbp;
  _dbp = new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains('items')) {
        db.createObjectStore('items', { keyPath: 'id' }).createIndex('createdAt', 'createdAt');
      }
      if (!db.objectStoreNames.contains('meta')) db.createObjectStore('meta', { keyPath: 'key' });
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  return _dbp;
}

const wrap = (r) => new Promise((res, rej) => {
  r.onsuccess = () => res(r.result);
  r.onerror = () => rej(r.error);
});
const store = async (name, mode) =>
  (await openDb()).transaction(name, mode).objectStore(name);

export const dbGetAll = async (n) => wrap((await store(n, 'readonly')).getAll());
export const dbGet = async (n, k) => wrap((await store(n, 'readonly')).get(k));
export const dbPut = async (n, v) => wrap((await store(n, 'readwrite')).put(v));
export const dbDel = async (n, k) => wrap((await store(n, 'readwrite')).delete(k));
export const dbClear = async (n) => wrap((await store(n, 'readwrite')).clear());

export async function metaGet(key, fallback = null) {
  const row = await dbGet('meta', key);
  return row === undefined || row === null ? fallback : row.value;
}
export const metaSet = (key, value) => dbPut('meta', { key, value });
JS
sed -i '' "s/APP_SLUG_PLACEHOLDER/${SLUG}/" js/db.js 2>/dev/null \
  || sed -i "s/APP_SLUG_PLACEHOLDER/${SLUG}/" js/db.js

# ---------------------------------------------------------------- js/store.js
cat > js/store.js <<'JS'
// All state and all persistence. Nothing else may mutate state or touch the db.
import { dbGetAll, dbPut, dbDel, dbClear, metaGet, metaSet } from './db.js';
import { uid, num } from './util.js';

export const DEFAULT_SETTINGS = { sortBy: 'created' };

export const state = {
  ready: false,
  items: [],
  settings: { ...DEFAULT_SETTINGS },
  tab: 'main',
  nav: {},
};

const listeners = new Set();
export const subscribe = (fn) => { listeners.add(fn); return () => listeners.delete(fn); };
export const emit = () => listeners.forEach((fn) => fn());

/**
 * The import boundary: accepts loosely-shaped input (hand-written JSON, an older
 * backup) and returns the canonical shape. New fields must always be optional
 * and defaulted here -- this is the only compatibility layer there is.
 */
export function normalizeItem(raw = {}) {
  return {
    id: raw.id || uid('it'),
    name: String(raw.name || raw.title || 'Untitled').trim(),
    notes: (Array.isArray(raw.notes) ? raw.notes.join('\n') : String(raw.notes ?? '')).trim(),
    count: num(raw.count ?? raw.qty) ?? 0,
    done: !!raw.done,
    createdAt: raw.createdAt || Date.now(),
    updatedAt: raw.updatedAt || Date.now(),
  };
}

function sortItems() {
  const by = state.settings.sortBy;
  state.items.sort((a, b) => (by === 'name'
    ? a.name.localeCompare(b.name)
    : b.createdAt - a.createdAt));
}

export async function init() {
  const [items, settings] = await Promise.all([dbGetAll('items'), metaGet('settings', null)]);
  state.items = (items || []).map(normalizeItem);
  state.settings = { ...DEFAULT_SETTINGS, ...(settings || {}) };
  sortItems();
  state.ready = true;
  emit();
}

export async function updateSettings(patch) {
  state.settings = { ...state.settings, ...patch };
  await metaSet('settings', state.settings);
  sortItems();
  emit();
}

export const getItem = (id) => state.items.find((x) => x.id === id) || null;

/** Persist one item, optionally without a re-render (for live field edits). */
async function touch(item, { silent = false } = {}) {
  item.updatedAt = Date.now();
  await dbPut('items', item);
  if (!silent) { sortItems(); emit(); }
}

export async function addItem(raw) {
  const item = normalizeItem(raw);
  state.items.push(item);
  await touch(item);
  return item;
}

export async function updateItem(id, patch, opts) {
  const item = getItem(id);
  if (!item) return null;
  Object.assign(item, patch);
  await touch(item, opts);
  return item;
}

export async function toggleDone(id) {
  const item = getItem(id);
  if (!item) return;
  await updateItem(id, { done: !item.done });
}

export async function deleteItem(id) {
  state.items = state.items.filter((x) => x.id !== id);
  await dbDel('items', id);
  emit();
}

/** Counts you can compare across devices after a restore. */
export const dataFingerprint = () => ({
  items: state.items.length,
  done: state.items.filter((x) => x.done).length,
  oldest: state.items.length ? Math.min(...state.items.map((x) => x.createdAt)) : null,
  newest: state.items.length ? Math.max(...state.items.map((x) => x.createdAt)) : null,
});

/** Wipe and rewrite verbatim -- same ids -- so a restore is loss-free. */
export async function restoreAll({ items = [], settings = null }) {
  await dbClear('items');
  state.items = items.map(normalizeItem);
  sortItems();
  await Promise.all(state.items.map((i) => dbPut('items', i)));
  if (settings) state.settings = { ...DEFAULT_SETTINGS, ...settings };
  await metaSet('settings', state.settings);
  state.nav = {};
  emit();
  return dataFingerprint();
}
JS

# ---------------------------------------------------------------- js/ui.js
cat > js/ui.js <<'JS'
// Modal / toast / confirm / clipboard primitives.
import { esc } from './util.js';
import { emit } from './store.js';

let toastTimer = null;
export function toast(msg, ms = 2200) {
  const el = document.getElementById('toast');
  el.textContent = msg;
  el.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { el.hidden = true; }, ms);
}

export async function copyText(text) {
  try {
    if (navigator.clipboard?.writeText) { await navigator.clipboard.writeText(text); return true; }
  } catch { /* fall through */ }
  try {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.style.cssText = 'position:fixed;top:0;left:0;opacity:0;pointer-events:none';
    document.body.appendChild(ta);
    ta.select();
    const ok = document.execCommand('copy');
    ta.remove();
    return !!ok;
  } catch { return false; }
}

let onClose = null;

export function closeModal() {
  const root = document.getElementById('modalRoot');
  root.hidden = true;
  root.innerHTML = '';
  const cb = onClose; onClose = null;
  if (cb) cb();
  emit();   // a submit may have changed the tab or the data behind the modal
}

export function openModal({
  title, bodyHtml, okText = 'Save', cancelText = 'Cancel', onSubmit = null, danger = false,
}) {
  const root = document.getElementById('modalRoot');
  root.hidden = false;
  root.innerHTML = `
    <div class="modal" role="dialog" aria-modal="true" aria-label="${esc(title)}">
      <h3>${esc(title)}</h3>
      <form id="modalForm" novalidate>
        <div class="modal-body">${bodyHtml}</div>
        <div class="modal-foot">
          <button type="button" class="btn ghost" data-mclose>${esc(cancelText)}</button>
          ${onSubmit ? `<button type="submit" class="btn ${danger ? 'danger' : 'primary'}">${esc(okText)}</button>` : ''}
        </div>
      </form>
    </div>`;
  root.querySelector('[data-mclose]').onclick = closeModal;
  root.onclick = (e) => { if (e.target === root) closeModal(); };

  const form = root.querySelector('#modalForm');
  form.onsubmit = async (e) => {
    e.preventDefault();
    if (!onSubmit) return closeModal();
    const values = {};
    form.querySelectorAll('[name]').forEach((f) => {
      values[f.name] = f.type === 'checkbox' ? f.checked : f.value;
    });
    if (await onSubmit(values, root.querySelector('.modal')) !== false) closeModal();
  };
  const first = form.querySelector('input,select,textarea');
  if (first && !first.dataset.nofocus) setTimeout(() => first.focus(), 60);
  return root.querySelector('.modal');
}

export function confirmDialog(message, { okText = 'Delete', title = 'Are you sure?' } = {}) {
  return new Promise((resolve) => {
    let settled = false;
    onClose = () => { if (!settled) { settled = true; resolve(false); } };
    openModal({
      title,
      bodyHtml: `<p class="muted" style="margin:0">${esc(message)}</p>`,
      okText,
      danger: true,
      onSubmit: () => { settled = true; resolve(true); return true; },
    });
  });
}
JS

# ---------------------------------------------------------------- js/exportimport.js
cat > js/exportimport.js <<'JS'
// Backup / restore / CSV. Nothing leaves the device without an explicit tap.
import { state, restoreAll, addItem, dataFingerprint, normalizeItem } from './store.js';
import { download, csvCell, isoDate, fmtNum } from './util.js';

export const SCHEMA = 'app/v1';

export function backupObject() {
  return {
    schema: SCHEMA,
    exportedAt: new Date().toISOString(),
    counts: dataFingerprint(),
    settings: state.settings,     // secrets live under their own meta key, never here
    items: state.items,
  };
}

export function exportBackup() {
  download(`backup-${isoDate(Date.now())}.json`,
    JSON.stringify(backupObject(), null, 2), 'application/json');
}

/** Column order is a published contract: append columns, never insert. */
const CSV_COLS = ['id', 'name', 'count', 'done', 'created', 'updated', 'notes'];

export function csvRows(items = state.items) {
  const rows = [CSV_COLS.join(',')];
  [...items].sort((a, b) => a.createdAt - b.createdAt).forEach((i) => {
    rows.push([i.id, i.name, fmtNum(i.count), i.done ? 'yes' : 'no',
      isoDate(i.createdAt), isoDate(i.updatedAt), i.notes].map(csvCell).join(','));
  });
  return rows.join('\n');
}

export function exportCsv() {
  download(`items-${isoDate(Date.now())}.csv`, csvRows(), 'text/csv');
}

export const isBackup = (d) => !!d && !Array.isArray(d) && Array.isArray(d.items);

/**
 * mode 'replace' wipes this device and restores verbatim (same ids).
 * mode 'merge' adds only ids that are not already present.
 */
export async function importFromText(text, { mode = 'merge' } = {}) {
  let data;
  try { data = JSON.parse(text); } catch (err) {
    throw new Error(`That is not valid JSON: ${err.message}`);
  }
  const list = isBackup(data) ? data.items : Array.isArray(data) ? data : null;
  if (!list) throw new Error('Expected a backup file or a list of items.');

  if (mode === 'replace') {
    const actual = await restoreAll({ items: list, settings: data.settings || null });
    return { mode, added: actual.items, skipped: 0, expected: data.counts || null, actual };
  }
  let added = 0; let skipped = 0;
  for (const raw of list) {
    const item = normalizeItem(raw);
    if (state.items.some((x) => x.id === item.id)) { skipped++; continue; }
    await addItem(item);
    added++;
  }
  return { mode, added, skipped, actual: dataFingerprint() };
}
JS

# ---------------------------------------------------------------- views
cat > js/views/main.js <<'JS'
// "Items" tab: the primary screen. render() returns an HTML string; no DOM refs.
import { state, addItem, updateItem, deleteItem, toggleDone, getItem } from '../store.js';
import { esc, fmtNum, relDay } from '../util.js';
import { openModal, confirmDialog, toast } from '../ui.js';

export function render() {
  const { items } = state;
  const done = items.filter((i) => i.done).length;
  return `
    <button type="button" class="btn block primary" data-action="item-new">+ New item</button>

    <h2>${items.length} item${items.length === 1 ? '' : 's'}${done ? ` &middot; ${done} done` : ''}</h2>
    ${items.length ? items.map((i) => `
      <div class="item ${i.done ? 'done' : ''}">
        <button type="button" class="btn sm ${i.done ? '' : 'ghost'}"
                data-action="item-toggle" data-id="${i.id}" aria-label="Toggle done">
          ${i.done ? '&#10003;' : '&nbsp;&nbsp;'}</button>
        <div class="body">
          <div class="nm">${esc(i.name)}</div>
          <div class="sub">${i.count ? `${esc(fmtNum(i.count))} &middot; ` : ''}${esc(relDay(i.createdAt))}</div>
          ${i.notes ? `<div class="sub" style="white-space:pre-wrap">${esc(i.notes)}</div>` : ''}
        </div>
        <button type="button" class="btn sm ghost" data-action="item-edit" data-id="${i.id}">Edit</button>
      </div>`).join('')
    : '<div class="empty">Nothing here yet. Add your first item.</div>'}`;
}

function itemForm(i = {}) {
  return `
    <label class="field"><span>Name</span>
      <input name="name" value="${esc(i.name || '')}" autocapitalize="sentences" required></label>
    <label class="field"><span>Count</span>
      <input name="count" inputmode="decimal" value="${esc(fmtNum(i.count))}"></label>
    <label class="field"><span>Notes</span>
      <textarea name="notes" rows="3">${esc(i.notes || '')}</textarea></label>`;
}

export const mainActions = {
  'item-new': () => {
    openModal({
      title: 'New item',
      bodyHtml: itemForm(),
      okText: 'Add',
      onSubmit: async (v) => {
        if (!v.name.trim()) { toast('Give it a name'); return false; }
        await addItem(v);
        return true;
      },
    });
  },

  'item-edit': ({ id }) => {
    const item = getItem(id);
    if (!item) return;
    openModal({
      title: 'Edit item',
      bodyHtml: `${itemForm(item)}
        <button type="button" class="btn block danger" data-action="item-del" data-id="${id}">Delete</button>`,
      onSubmit: async (v) => {
        if (!v.name.trim()) { toast('Give it a name'); return false; }
        await updateItem(id, { name: v.name.trim(), count: Number(v.count) || 0, notes: v.notes });
        return true;
      },
    });
  },

  'item-toggle': async ({ id }) => { await toggleDone(id); },

  'item-del': async ({ id }) => {
    const item = getItem(id);
    if (!item) return;
    if (await confirmDialog(`Delete "${item.name}"? This cannot be undone.`)) {
      await deleteItem(id);
      toast('Deleted');
    }
  },
};
JS

cat > js/views/settings.js <<'JS'
// "Settings" tab: preferences, backup, restore, and the build number.
import { state, updateSettings, dataFingerprint } from '../store.js';
import { esc, fmtDate, APP_VERSION } from '../util.js';
import { openModal, toast, confirmDialog } from '../ui.js';
import { exportBackup, exportCsv, importFromText } from '../exportimport.js';

export function render() {
  const fp = dataFingerprint();
  return `
    <h2>Your data</h2>
    <div class="card">
      <div class="kv"><span>Items</span><span>${fp.items}</span></div>
      <div class="kv"><span>Done</span><span>${fp.done}</span></div>
      ${fp.oldest ? `<div class="kv"><span>Range</span><span>${esc(fmtDate(fp.oldest))} &rarr; ${esc(fmtDate(fp.newest))}</span></div>` : ''}
      <p class="hint" style="margin-bottom:0">Compare these on another device after a restore; if they
        match, the transfer was complete.</p>
    </div>
    <div class="btn-row">
      <button type="button" class="btn" data-action="export-backup">Export backup</button>
      <button type="button" class="btn" data-action="export-csv">Export CSV</button>
    </div>
    <button type="button" class="btn block ghost" style="margin-top:8px"
            data-action="import-open">Import / restore</button>

    <h2>Preferences</h2>
    <div class="card">
      <label class="field" style="margin-bottom:0"><span>Sort items by</span>
        <select data-sf="sortBy">
          <option value="created" ${state.settings.sortBy === 'created' ? 'selected' : ''}>Newest first</option>
          <option value="name" ${state.settings.sortBy === 'name' ? 'selected' : ''}>Name</option>
        </select></label>
    </div>

    <p class="hint" style="text-align:center;margin-top:18px">
      All data is stored on this device only.<br><span class="dim">build ${esc(APP_VERSION)}</span></p>`;
}

export const settingsActions = {
  'export-backup': () => { exportBackup(); toast('Backup exported'); },
  'export-csv': () => { exportCsv(); toast('CSV exported'); },

  'import-open': () => {
    const modal = openModal({
      title: 'Import / restore',
      bodyHtml: `
        <label class="field"><span>Pick a .json file</span>
          <input type="file" id="impFile" accept=".json,application/json" data-nofocus></label>
        <label class="field"><span>...or paste JSON</span>
          <textarea name="text" id="impText" rows="6"></textarea></label>
        <label class="field"><span>Mode</span>
          <select name="mode">
            <option value="merge">Merge - add what is missing</option>
            <option value="replace">Replace - wipe this device and restore exactly</option>
          </select></label>`,
      okText: 'Import',
      onSubmit: async (v) => {
        const text = (v.text || '').trim();
        if (!text) { toast('Choose a file or paste JSON'); return false; }
        if (v.mode === 'replace'
          && !await confirmDialog('Replace ALL data on this device?', { okText: 'Replace' })) {
          return true;
        }
        try {
          const res = await importFromText(text, { mode: v.mode });
          toast(`Imported ${res.added} item${res.added === 1 ? '' : 's'}`
            + (res.skipped ? `, ${res.skipped} already present` : ''), 3200);
          return true;
        } catch (err) { toast(err.message, 4800); return false; }
      },
    });
    const file = modal.querySelector('#impFile');
    const text = modal.querySelector('#impText');
    file.addEventListener('change', () => {
      const f = file.files && file.files[0];
      if (!f) return;
      const fr = new FileReader();
      fr.onload = () => { text.value = String(fr.result || ''); toast(`Loaded ${f.name}`); };
      fr.readAsText(f);
    });
  },
};

/** Settings fields (data-sf). Called from app.js. */
export async function handleSettingsField(target) {
  if (!target.dataset.sf) return;
  await updateSettings({ [target.dataset.sf]: target.value });
}
JS

# ---------------------------------------------------------------- js/app.js
cat > js/app.js <<'JS'
// Boot, render loop, delegated event routing.
import { state, init, subscribe } from './store.js';
import { toast } from './ui.js';
import * as mainView from './views/main.js';
import * as settingsView from './views/settings.js';

const VIEWS = { main: mainView, settings: settingsView };
const ACTIONS = { ...mainView.mainActions, ...settingsView.settingsActions };

let lastScreen = '';

export function render() {
  if (!state.ready) return;
  const view = VIEWS[state.tab] || VIEWS.main;
  const screen = `${state.tab}|${state.nav.id || ''}`;
  const y = window.scrollY;
  document.getElementById('viewRoot').innerHTML = view.render();
  window.scrollTo(0, screen === lastScreen ? y : 0);
  lastScreen = screen;
  document.querySelectorAll('#tabBar .tab').forEach((b) => {
    b.classList.toggle('active', b.dataset.tab === state.tab);
  });
}

document.addEventListener('click', async (ev) => {
  const tab = ev.target.closest('#tabBar .tab');
  if (tab) { state.tab = tab.dataset.tab; state.nav = {}; render(); return; }

  const el = ev.target.closest('[data-action]');
  if (!el) return;
  const fn = ACTIONS[el.dataset.action];
  if (!fn) return;
  ev.preventDefault();
  try { await fn({ ...el.dataset }); } catch (err) {
    console.error(`action ${el.dataset.action} failed`, err);
    toast(err?.message || 'Something went wrong');
  }
  render();
});

// Live field edits persist without a re-render, so the keyboard and caret stay put.
document.addEventListener('input', (ev) => {
  if (ev.target.dataset?.sf) settingsView.handleSettingsField(ev.target);
});

subscribe(render);

(async function start() {
  try {
    await init();
    render();
  } catch (err) {
    document.getElementById('viewRoot').innerHTML =
      `<div class="empty">Could not open local storage.<br><br><span class="small">${err.message}</span>`
      + '<br><br><span class="small">In Safari Private Browsing storage is unavailable.</span></div>';
  }
}());

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch(() => { /* offline unavailable */ });
  });
}
JS

# ---------------------------------------------------------------- sw.js
cat > sw.js <<'JS'
// Network-first with a cache fallback. Cache-first is a trap: the outgoing
// worker keeps serving old code for one more load, so a change appears not to
// have happened until the second reload.
const CACHE = 'app-v1';   // bump with APP_VERSION; a test enforces that they agree

const ASSETS = [
  '.', 'index.html', 'manifest.webmanifest', 'css/styles.css',
  'js/app.js', 'js/db.js', 'js/store.js', 'js/ui.js', 'js/util.js', 'js/exportimport.js',
  'js/views/main.js', 'js/views/settings.js',
  'icons/icon-192.png', 'icons/icon-512.png',
];

self.addEventListener('install', (e) => e.waitUntil(
  caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()),
));

self.addEventListener('activate', (e) => e.waitUntil(
  caches.keys()
    .then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()),
));

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;
  e.respondWith(
    fetch(req)
      .then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
        }
        return res;
      })
      .catch(async () => {
        const hit = await caches.match(req);
        if (hit) return hit;
        if (req.mode === 'navigate') {
          const shell = await caches.match('index.html');
          if (shell) return shell;
        }
        return new Response('Offline and not cached', { status: 504 });
      }),
  );
});
JS

# ---------------------------------------------------------------- manifest
cat > manifest.webmanifest <<MANIFEST
{
  "name": "${APP_NAME}",
  "short_name": "${APP_NAME}",
  "start_url": ".",
  "scope": ".",
  "display": "standalone",
  "background_color": "#0f1115",
  "theme_color": "#0f1115",
  "icons": [
    { "src": "icons/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" },
    { "src": "icons/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" },
    { "src": "icons/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
MANIFEST

# ---------------------------------------------------------------- icons
python3 - "$APP_NAME" <<'PY'
import struct, sys, zlib
BG, FG = (15, 17, 21), (79, 140, 255)
def png(path, size):
    px = [[BG for _ in range(size)] for _ in range(size)]
    u = size / 100.0
    def rect(x0, y0, x1, y1, col, r=0):
        for y in range(max(0, int(y0)), min(size, int(y1))):
            for x in range(max(0, int(x0)), min(size, int(x1))):
                if r:
                    cx = min(max(x, x0 + r), x1 - r); cy = min(max(y, y0 + r), y1 - r)
                    if (x - cx) ** 2 + (y - cy) ** 2 > r * r: continue
                px[y][x] = col
    rect(22 * u, 22 * u, 78 * u, 78 * u, FG, r=12 * u)
    rect(34 * u, 34 * u, 66 * u, 66 * u, BG, r=6 * u)
    raw = b''.join(b'\x00' + bytes(v for x in range(size) for v in px[y][x]) for y in range(size))
    def chunk(t, d):
        c = t + d
        return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n'
                + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
png('icons/icon-192.png', 192)
png('icons/icon-512.png', 512)
PY

# ---------------------------------------------------------------- tests
cat > test/package.json <<'JSON'
{
  "name": "app-tests",
  "private": true,
  "type": "module",
  "scripts": { "test": "node style.mjs && node smoke.mjs && node dom.mjs" },
  "devDependencies": { "jsdom": "24.1.3", "fake-indexeddb": "6.0.0" }
}
JSON

cat > test/style.mjs <<'JS'
// Guards: things prose cannot enforce. Each must fail when its invariant breaks.
import { JSDOM } from 'jsdom';
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';

const APP = new URL('..', import.meta.url).pathname.replace(/\/$/, '');
const html = readFileSync(`${APP}/index.html`, 'utf8');
const css = readFileSync(`${APP}/css/styles.css`, 'utf8');
const sw = readFileSync(`${APP}/sw.js`, 'utf8');
const util = readFileSync(`${APP}/js/util.js`, 'utf8');

const dom = new JSDOM(html.replace('</head>', `<style>${css}</style></head>`));
const { document, getComputedStyle } = dom.window;

let failures = 0;
const ok = (c, l) => { if (c) console.log(`  ok   ${l}`); else { failures++; console.log(`  FAIL ${l}`); } };
const display = (id) => getComputedStyle(document.getElementById(id)).display;

console.log('\n== overlays must obey the hidden attribute');
for (const id of ['modalRoot', 'toast']) {
  const el = document.getElementById(id);
  ok(el.hasAttribute('hidden'), `#${id} starts hidden`);
  ok(display(id) === 'none', `#${id} computes to display:none while hidden (got "${display(id)}")`);
  el.removeAttribute('hidden');
  ok(display(id) !== 'none', `#${id} becomes visible when shown (got "${display(id)}")`);
}
ok(display('viewRoot') !== 'none', 'the view container is visible');
ok(display('tabBar') === 'flex', 'the tab bar lays out');

console.log('\n== release invariants');
const version = (util.match(/APP_VERSION = '([^']+)'/) || [])[1];
const cache = (sw.match(/const CACHE = '([^']+)'/) || [])[1];
ok(!!version, `APP_VERSION is set (${version})`);
ok(cache === `app-v${version}`,
  `sw CACHE matches APP_VERSION (CACHE="${cache}", expected "app-v${version}")`);

console.log('\n== offline manifest covers every shipped file');
const walk = (dir, prefix = '') => readdirSync(dir).flatMap((n) => {
  const full = `${dir}/${n}`;
  const rel = prefix ? `${prefix}/${n}` : n;
  if (statSync(full).isDirectory()) {
    return ['test', 'node_modules', '.git'].includes(n) || n.startsWith('.') ? [] : walk(full, rel);
  }
  return /\.(js|css|html|webmanifest|png)$/.test(n) ? [rel] : [];
});
const listed = new Set([...sw.matchAll(/'([^']+)'/g)].map((m) => m[1]));
const missing = walk(APP).filter((f) => f !== 'sw.js' && !listed.has(f));
ok(missing.length === 0, `every file is in sw ASSETS${missing.length ? ` -- missing: ${missing.join(', ')}` : ''}`);
ok(/fetch\(req\)/.test(sw), 'service worker goes to the network before the cache');

console.log('\n== action registry integrity');
const viewFiles = ['js/views/main.js', 'js/views/settings.js'];
const sources = viewFiles.map((f) => readFileSync(`${APP}/${f}`, 'utf8'));
const all = sources.join('\n');
const declared = new Map();
sources.forEach((src, i) => {
  for (const m of src.matchAll(/^ {2}'([a-z][a-z0-9-]*)':/gm)) {
    if (declared.has(m[1])) { failures++; console.log(`  FAIL action "${m[1]}" declared twice`); }
    declared.set(m[1], viewFiles[i]);
  }
});
ok(declared.size > 0, `${declared.size} actions declared`);
const used = new Set([...all.matchAll(/data-action="([a-z][a-z0-9-]*)"/g)].map((m) => m[1]));
const orphans = [...used].filter((a) => !declared.has(a));
ok(orphans.length === 0, `every data-action has a handler${orphans.length ? ` -- missing: ${orphans.join(', ')}` : ''}`);
const dead = [...declared.keys()].filter((a) => !used.has(a));
ok(dead.length === 0, `every handler is reachable${dead.length ? ` -- dead: ${dead.join(', ')}` : ''}`);

console.log('\n== maintainability invariants');
const modules = walk(`${APP}/js`).map((f) => `js/${f}`);
const core = modules.filter((m) => !m.startsWith('js/views/') && m !== 'js/app.js');
const upward = core.filter((m) => /from '\.(\/|\.\/)?views\//.test(readFileSync(`${APP}/${m}`, 'utf8')));
ok(upward.length === 0, `no core module imports a view${upward.length ? ` -- ${upward.join(', ')}` : ''}`);
const big = modules.map((m) => [m, readFileSync(`${APP}/${m}`, 'utf8').split('\n').length])
  .filter(([, n]) => n > 1000);
ok(big.length === 0, `every module under 1000 lines${big.length ? ` -- ${big.map(([m, n]) => `${m} (${n})`).join(', ')}` : ''}`);
const logs = modules.filter((m) => /console\.(log|debug|info)\(/.test(readFileSync(`${APP}/${m}`, 'utf8')));
ok(logs.length === 0, `no stray console.log${logs.length ? ` -- ${logs.join(', ')}` : ''}`);
for (const doc of ['README.md', 'ARCHITECTURE.md', 'AGENTS.md']) {
  ok(existsSync(`${APP}/${doc}`), `${doc} exists`);
}
if (existsSync(`${APP}/deploy.sh`)) {
  const sh = readFileSync(`${APP}/deploy.sh`, 'utf8');
  ok([...sh].every((c) => c.charCodeAt(0) <= 126), 'deploy.sh is pure ASCII (macOS bash 3.2)');
}

console.log(`\n${failures === 0 ? 'ALL STYLE CHECKS PASSED' : `${failures} STYLE CHECK(S) FAILED`}`);
process.exit(failures === 0 ? 0 : 1);
JS

cat > test/smoke.mjs <<'JS'
// Store, normalisation and import/export, with no browser.
import { JSDOM } from 'jsdom';
import 'fake-indexeddb/auto';
import { readFileSync } from 'node:fs';

const APP = new URL('..', import.meta.url).pathname.replace(/\/$/, '');
const dom = new JSDOM(readFileSync(`${APP}/index.html`, 'utf8'), { url: 'https://example.test/' });
global.window = dom.window;
global.document = dom.window.document;
Object.defineProperty(global, 'navigator', { value: dom.window.navigator, configurable: true });
global.Blob = dom.window.Blob;
global.URL = dom.window.URL;
dom.window.HTMLAnchorElement.prototype.click = function () {};

let failures = 0;
const ok = (c, l) => { if (c) console.log(`  ok   ${l}`); else { failures++; console.log(`  FAIL ${l}`); } };
const section = (s) => console.log(`\n== ${s}`);

const store = await import(`${APP}/js/store.js`);
const xi = await import(`${APP}/js/exportimport.js`);
const mainView = await import(`${APP}/js/views/main.js`);
const settingsView = await import(`${APP}/js/views/settings.js`);
const { state } = store;

section('init on an empty database');
await store.init();
ok(state.ready, 'store ready');
ok(state.items.length === 0, 'starts empty');
ok(typeof mainView.render() === 'string' && mainView.render().length > 0, 'main view renders');
ok(typeof settingsView.render() === 'string', 'settings view renders');

section('create, update, persist');
const a = await store.addItem({ name: 'First', count: 2, notes: 'hello' });
ok(state.items.length === 1, 'item added');
ok(a.id && a.createdAt > 0, 'got an id and a timestamp');
await store.updateItem(a.id, { count: 5 });
ok(store.getItem(a.id).count === 5, 'update applied');
await store.toggleDone(a.id);
ok(store.getItem(a.id).done === true, 'toggled done');

section('normalisation absorbs loose input');
const b = store.normalizeItem({ title: 'Aliased', qty: '3', notes: ['one', 'two'] });
ok(b.name === 'Aliased', 'title -> name');
ok(b.count === 3, 'qty -> count, string parsed');
ok(b.notes === 'one\ntwo', 'notes array joined to lines');
ok(store.normalizeItem({}).name === 'Untitled', 'missing name defaulted');

section('backup round-trips verbatim');
await store.addItem({ name: 'Second' });
const before = store.dataFingerprint();
const backup = JSON.stringify(xi.backupObject());
await store.restoreAll({ items: [], settings: null });
ok(store.dataFingerprint().items === 0, 'wiped');
const res = await xi.importFromText(backup, { mode: 'replace' });
ok(res.actual.items === before.items, `item count matches (${res.actual.items})`);
ok(state.items.some((x) => x.id === a.id), 'ids preserved, so references survive');
ok(res.expected && res.expected.items === res.actual.items, 'backup self-verifies its counts');

section('merge does not duplicate');
const merged = await xi.importFromText(backup, { mode: 'merge' });
ok(merged.added === 0 && merged.skipped === before.items, 'nothing re-added');

section('bad input is rejected clearly');
for (const [bad, label] of [['nope', 'non-JSON'], ['{"foo":1}', 'wrong shape']]) {
  try { await xi.importFromText(bad); failures++; console.log(`  FAIL ${label} should throw`); }
  catch (err) { ok(err.message.length > 10, `${label} -> "${err.message.slice(0, 40)}"`); }
}

section('csv');
const csv = xi.csvRows();
ok(csv.split('\n')[0] === 'id,name,count,done,created,updated,notes', 'header is the contract');
ok(csv.trim().split('\n').length === before.items + 1, 'one row per item');

console.log(`\n${failures === 0 ? 'ALL CHECKS PASSED' : `${failures} CHECK(S) FAILED`}`);
process.exit(failures === 0 ? 0 : 1);
JS

cat > test/dom.mjs <<'JS'
// Drives the real UI through clicks and typing under jsdom.
import { JSDOM } from 'jsdom';
import 'fake-indexeddb/auto';
import { readFileSync } from 'node:fs';

const APP = new URL('..', import.meta.url).pathname.replace(/\/$/, '');
const dom = new JSDOM(readFileSync(`${APP}/index.html`, 'utf8'),
  { url: 'https://example.test/', pretendToBeVisual: true });
global.window = dom.window;
global.document = dom.window.document;
Object.defineProperty(global, 'navigator', { value: dom.window.navigator, configurable: true });
global.Blob = dom.window.Blob;
global.URL = dom.window.URL;
dom.window.scrollTo = () => {};
dom.window.HTMLAnchorElement.prototype.click = function () {};

let failures = 0;
const ok = (c, l) => { if (c) console.log(`  ok   ${l}`); else { failures++; console.log(`  FAIL ${l}`); } };
const section = (s) => console.log(`\n== ${s}`);
const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
const view = () => $('#viewRoot').innerHTML;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function click(sel, label = sel) {
  const el = $(sel);
  if (!el) { failures++; console.log(`  FAIL no element to click: ${label}`); return false; }
  el.dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true, cancelable: true }));
  await sleep(40);
  return true;
}
const submit = async () => {
  $('#modalForm').dispatchEvent(new dom.window.Event('submit', { bubbles: true, cancelable: true }));
  await sleep(80);
};

const store = await import(`${APP}/js/store.js`);
await import(`${APP}/js/app.js`);
await sleep(150);

section('boot');
ok(store.state.ready, 'store initialised');
ok($$('#tabBar .tab').length === 2, 'two tabs');
ok(/Nothing here yet/.test(view()), 'empty state shown');

section('create an item through the UI');
await click('[data-action="item-new"]', '+ New item');
ok($('#modalRoot').hidden === false, 'modal opened');
$('[name="name"]').value = 'Walk the dog';
$('[name="count"]').value = '2';
await submit();
ok(store.state.items.length === 1, 'item created');
ok($('#modalRoot').hidden === true, 'modal closed');
ok(/Walk the dog/.test(view()), 'and it is on screen');

section('toggle and edit');
await click('[data-action="item-toggle"]', 'toggle done');
ok(store.state.items[0].done === true, 'marked done');
ok($('.item').classList.contains('done'), 'row shows as done');
await click('[data-action="item-edit"]', 'edit');
$('[name="name"]').value = 'Walk the dog twice';
await submit();
ok(store.state.items[0].name === 'Walk the dog twice', 'rename persisted');

section('validation refuses an empty name');
await click('[data-action="item-new"]');
$('[name="name"]').value = '   ';
await submit();
ok($('#modalRoot').hidden === false, 'modal stayed open');
await click('[data-mclose]', 'cancel');
ok(store.state.items.length === 1, 'nothing was created');

section('tabs render and settings persist');
await click('#tabBar .tab[data-tab="settings"]', 'Settings tab');
ok(/Your data/.test(view()), 'settings rendered');
ok($('#tabBar .tab[data-tab="settings"]').classList.contains('active'), 'tab marked active');
ok(/build /.test(view()), 'the build number is visible, so a stale cache is diagnosable');
const sel = $('[data-sf="sortBy"]');
sel.value = 'name';
sel.dispatchEvent(new dom.window.Event('input', { bubbles: true }));
await sleep(50);
ok(store.state.settings.sortBy === 'name', 'preference saved');

section('delete');
await click('#tabBar .tab[data-tab="main"]');
await click('[data-action="item-edit"]', 'edit');
await click('[data-action="item-del"]', 'Delete');
await submit();
ok(store.state.items.length === 0, 'item deleted');
ok(/Nothing here yet/.test(view()), 'back to the empty state');

console.log(`\n${failures === 0 ? 'ALL DOM CHECKS PASSED' : `${failures} DOM CHECK(S) FAILED`}`);
process.exit(failures === 0 ? 0 : 1);
JS

# ---------------------------------------------------------------- deploy.sh
cat > deploy.sh <<'SH'
#!/usr/bin/env bash
# Publish to GitHub Pages.
#   1. gh auth login     (once, interactive)
#   2. ./deploy.sh       (creates the repo, pushes, enables Pages)
# ASCII only: macOS bash 3.2 mangles non-ASCII bytes following a variable.
set -euo pipefail

REPO_NAME="${REPO_NAME:-$(basename "$(cd "$(dirname "$0")" && pwd)")}"
EXPECTED_OWNER="${EXPECTED_OWNER:-}"
BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"
cd "$(dirname "$0")"

command -v gh >/dev/null || { echo "gh is not installed: brew install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Not logged in. Run: gh auth login"; exit 1; }

USER_LOGIN="$(gh api user --jq .login)"
if [ -n "${EXPECTED_OWNER}" ] && [ "${USER_LOGIN}" != "${EXPECTED_OWNER}" ]; then
  echo "gh is authenticated as '${USER_LOGIN}', not '${EXPECTED_OWNER}'."
  echo "Switch with:  gh auth switch --user ${EXPECTED_OWNER}"
  exit 1
fi

echo "GitHub user : ${USER_LOGIN}"
echo "Repo        : ${USER_LOGIN}/${REPO_NAME}"
echo "Commits as  : $(git log -1 --format='%an <%ae>' 2>/dev/null || echo '(no commits yet)')"
echo

if gh repo view "${USER_LOGIN}/${REPO_NAME}" >/dev/null 2>&1; then
  echo "Repo exists - pushing."
  git remote get-url origin >/dev/null 2>&1 \
    || git remote add origin "https://github.com/${USER_LOGIN}/${REPO_NAME}.git"
  git push -u origin "${BRANCH}"
else
  echo "Creating a PUBLIC repo and pushing ${BRANCH} ..."
  gh repo create "${REPO_NAME}" --public --source=. --remote=origin --push
fi

echo
if gh api "repos/${USER_LOGIN}/${REPO_NAME}/pages" >/dev/null 2>&1; then
  echo "Pages already configured."
else
  gh api --method POST "repos/${USER_LOGIN}/${REPO_NAME}/pages" \
    -f "source[branch]=${BRANCH}" -f "source[path]=/" >/dev/null
  echo "Pages enabled."
fi

echo
echo "Done. The first build takes a minute or two."
echo "  https://${USER_LOGIN}.github.io/${REPO_NAME}/"
echo
echo "On iPhone: open that URL in Safari -> Share -> Add to Home Screen."
SH
chmod +x deploy.sh

printf 'node_modules/\npackage-lock.json\n.DS_Store\n' > .gitignore

# ---------------------------------------------------------------- docs
cat > README.md <<DOC
# ${APP_NAME}

A local-first installable web app. Plain HTML, CSS and ES modules: no build step, no dependencies,
no server, no account. Data is stored in IndexedDB on the device.

Runs on iOS, Android and any desktop browser.

## Run it

\`\`\`bash
python3 -m http.server 8000 --bind 127.0.0.1    # http://localhost:8000
\`\`\`

\`file://\` will not work; ES modules are blocked by CORS.

## Install it

| Platform | How |
|---|---|
| **iOS / iPadOS** | **Safari** -> Share -> Add to Home Screen |
| **Android** | Chrome -> menu -> Install app |
| **Desktop** | Chrome/Edge -> install icon in the address bar |

Chrome on iOS cannot do this properly: only Safari produces a standalone, offline-capable app.
Installing also exempts the app from Safari's 7-day storage eviction, so it is not optional.

## Your data

Stored only on this device. Settings -> **Export backup** writes a JSON file that restores
verbatim (same ids); **Replace** mode makes another device an exact copy. Compare the counts shown
in Settings on both devices to confirm a transfer was complete.

## Deploy

\`\`\`bash
gh auth login
./deploy.sh
\`\`\`

## Develop

See [AGENTS.md](AGENTS.md) for the rules and recipes, and [ARCHITECTURE.md](ARCHITECTURE.md) for how
it works.

\`\`\`bash
cd test && npm install && npm test
\`\`\`
DOC

cat > ARCHITECTURE.md <<'DOC'
# Architecture

Plain ES modules, no framework, no build step. The render loop is deliberately dumb.

```
tap -> delegated handler -> ACTIONS[name](dataset) -> store mutator
     -> persist -> emit() -> render() -> viewRoot.innerHTML = view.render()
```

## Modules

```
index.html          shell: header, #viewRoot, #tabBar, #modalRoot, #toast
css/styles.css
sw.js               service worker, network-first with a cache fallback
js/app.js           boot, render loop, delegated events, ACTIONS registry
js/store.js         ALL state and persistence
js/db.js            IndexedDB wrapper
js/ui.js            modal / toast / confirm / clipboard
js/util.js          helpers, APP_VERSION
js/exportimport.js  backup, restore, CSV
js/views/main.js    the Items tab
js/views/settings.js the Settings tab
```

Dependency direction, enforced by a test: `app.js` may import anything; nothing else outside
`js/views/` may import a view; views import store/ui/util; store imports db/util.

## Rules that follow from the render loop

**A re-render destroys every input in the view.** So:

- Live field edits persist with `{ silent: true }` -- no `emit()`, no re-render.
- If you re-render on blur, defer it and bail while focus is still in a field.
- To change a value without losing focus, write `input.value` and dispatch an `input` event built
  from `input.ownerDocument.defaultView.Event`.

## Data model

```js
item = { id, name, notes, count, done, createdAt, updatedAt }
```

`normalizeItem()` is the import boundary: it absorbs aliases, ignores unknown keys and defaults
every field, which is why old backups still load without a migration framework.

If you add a template/instance split (a routine and a session, a recipe and a cooking), **snapshot**
the template into the instance rather than referencing it, so editing one never rewrites the other.

## Gotchas

Written as symptoms, because that is what the next reader is searching for.

1. **A full-screen haze over the app** -- an overlay ignoring `hidden`. A `display:flex` rule at ID
   specificity beats the UA `[hidden]{display:none}`. Use `#id:not([hidden]){display:flex}`.
2. **A change doesn't appear until the second reload** -- a cache-first service worker. This one is
   network-first; check the build number in Settings to tell a stale cache from a real bug.
3. **The keyboard closes while typing** -- something re-rendered on input.
4. **Sorts that can tie** resolve by iteration order. Give every sort an explicit second key.
5. **Non-ASCII in a shell script** breaks under macOS bash 3.2.
DOC

cat > AGENTS.md <<'DOC'
# Working on this codebase

Entry point for humans and AI agents. See [ARCHITECTURE.md](ARCHITECTURE.md) for how it works.

```bash
python3 -m http.server 8000 --bind 127.0.0.1
cd test && npm install && npm test
```

## Hard rules

1. **No runtime dependencies, no build step, no framework.** Dev-only test deps live in
   `test/package.json`.
2. **Run `npm test` before claiming anything works.** Every behaviour change needs an assertion
   that fails without it.
3. **Bump `APP_VERSION` in `js/util.js` and `CACHE` in `sw.js` together.** A test enforces it.
4. **Only `store.js` mutates state or touches IndexedDB.**
5. **Views return HTML strings.** No DOM refs, no local state, `esc()` every value.
6. **Field edits persist with `{ silent: true }`** so typing never triggers a re-render.
7. **New files go in the `sw.js` ASSETS list**, or offline silently breaks. A test enforces it.
8. **Shell scripts stay ASCII.**
9. **Secrets live under their own `meta` key**, never in `settings`, so backups cannot leak them.

## Recipes

**Add a field:** `normalizeItem` (with a default) -> the form -> the display -> the exporter ->
a round-trip test.

**Add a button:** render `data-action="my-thing"`, add `'my-thing': async ({ id }) => {}` to the
view's actions map. Names must be globally unique; a test checks for duplicates, orphans and dead
handlers.

**Add a tab:** a module exporting `render()` and an actions map, registered in `VIEWS` and
`ACTIONS` in `app.js`, a `.tab` button in `index.html`, and the file added to `sw.js` ASSETS.

**Add a mutator:**

```js
export async function doThing(id, patch, opts) {
  const item = getItem(id);
  if (!item) return;
  Object.assign(item, patch);
  await touch(item, opts);     // persists, emits unless { silent: true }
}
```

## Before you commit

```
[ ] npm test green
[ ] a test that fails without this change
[ ] APP_VERSION and sw CACHE bumped together
[ ] new files in sw ASSETS and the ARCHITECTURE module map
[ ] no console.log, no dead handlers
[ ] Conventional Commit message
```

## Product decisions

- **Local-first.** No account, no server. Must stay fully usable offline.
- **Nothing leaves the device without an explicit tap.** No analytics, no telemetry.
- **Unrecorded data is named, not defaulted.** Show "not recorded", never a fabricated value.
DOC

echo
echo "Done. Next:"
echo "  cd ${TARGET}"
echo "  (cd test && npm install && npm test)"
echo "  python3 -m http.server 8000 --bind 127.0.0.1"
echo "  git init -q && git add -A && git commit -qm 'feat: scaffold' && ./deploy.sh"
