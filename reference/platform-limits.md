# Platform limits

Read this before promising a feature. These are hard limits, not bugs to work around, and
discovering them after building is the most expensive mistake in this method.

## What works everywhere

iOS Safari, Android Chrome, desktop Chrome/Edge/Firefox/Safari:

- Installable to the home screen, launching standalone with no browser chrome
- Full offline operation via a service worker
- IndexedDB, typically ~1 GB per origin, scaling with free disk
- Web Audio (after a user gesture), file download and upload, the Clipboard API
- Screen Wake Lock on iOS 16.4+ and Android — genuinely useful for an app you glance at repeatedly
- `fetch` to any CORS-enabled API

## Installation, per platform

| Platform | How | Result |
|---|---|---|
| **iOS / iPadOS** | **Safari** → Share → Add to Home Screen | True standalone app, offline capable |
| **Android** | Chrome → ⋮ → Install app | Standalone app, offline capable |
| **Desktop** | Chrome/Edge → install icon in the address bar | App window |

**Chrome on iOS cannot do this.** Its "Add to Home Screen" creates a bookmark that opens inside
Chrome. Only Safari produces a standalone, offline-capable app. Every iOS browser is WebKit
underneath, so nothing is lost by using Safari for the install.

**HTTPS is required.** Service workers only run in a secure context — HTTPS or `localhost`. Serving
from your laptop at `http://192.168.x.x` will run the app but will not install it as an offline
app. Host it (see `deploy.md`).

## Not possible on iOS

Do not start these.

| Want | Reality |
|---|---|
| Apple Watch app, widget, Live Activity, Dynamic Island | No API exists for web apps |
| Sound or notification while fully backgrounded | Blocked. A timer's alert only fires with the app open |
| Vibration | iOS Safari ignores `navigator.vibrate` (Android honours it) |
| Background location / GPS tracking with the screen off | Not reliable; a run cannot be tracked |
| HealthKit read or write | No API |
| Background Sync / Periodic Background Sync | Chrome-only |
| Bluetooth (heart-rate straps) | Web Bluetooth is not in iOS Safari |
| True push notifications | Only for home-screen-installed apps, iOS 16.4+, and fiddly |

If a feature on that list is essential, this method is the wrong choice — say so early rather than
building most of an app first.

## The storage eviction trap

Safari erases all script-writable storage — IndexedDB, service worker registration, Cache API — for
a site with no user interaction for **7 days**. That policy **does not apply to apps added to the
home screen**.

Consequences:

- Installing is not optional for real use. Tell the user, in the app's own docs.
- Offer an export, and consider warning when the last backup is old.
- Safari Private Browsing has no persistent storage at all. Detect the failure and say so rather
  than appearing to work.

## Sizing storage honestly

Measure rather than guess: build one realistic record, `JSON.stringify` it, and extrapolate.

For a workout tracker, one session with 7 exercises, 21 logged sets and a cardio effort came to
**5.5 KB**, so six sessions a week for twenty years is ~33 MB — about 3% of a 1 GB budget. Most
apps of this kind will never approach the limit; say so with a number instead of hand-waving.

## iOS layout details that matter

- Inputs must be **≥16px** or Safari zooms the page on focus.
- Use `viewport-fit=cover` plus `env(safe-area-inset-*)` for the notch and home indicator.
- `touch-action: manipulation` on tappable elements removes the 300ms double-tap delay.
- Set `apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style` and an
  `apple-touch-icon`.
- Keep touch targets around 34px minimum.
- `<details>`/`<summary>` gives you collapsible sections with no JavaScript.
- `<input type="date">` and `type="time"` get the native iOS pickers — use them.
