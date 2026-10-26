# local-first-pwa

A method, a reference set, and a working scaffold for building a personal app that:

- **installs on iOS, Android and any desktop browser** as a standalone app
- **works offline**, with data stored on the device in IndexedDB
- has **no framework, no build step and no runtime dependencies**
- deploys as static files to **free hosting**
- is **tested without a browser** — real UI, real clicks, no Selenium
- optionally **syncs between devices** through a secret GitHub Gist, with no server

Extracted from a workout tracker built this way: ~4,000 lines of app code, 637 assertions, zero
runtime dependencies, deployed on GitHub Pages, installed on iOS from Safari.

## Use it in 30 seconds

```bash
./scripts/scaffold.sh ~/my-app "My App"
cd ~/my-app
(cd test && npm install && npm test)          # three suites, 40+ assertions, all green
python3 -m http.server 8000 --bind 127.0.0.1  # http://localhost:8000
```

That generates a complete, working, installable app: app shell, store, IndexedDB wrapper, two tabs
with full CRUD, modals, toasts, backup/restore/CSV export, a network-first service worker, generated
PNG icons, the test harness with eight guards already wired, a GitHub Pages deploy script, and three
documents. Then delete what you don't need and build your own screens.

`file://` will not work — ES modules are blocked by CORS. Always serve over `localhost`.

## Use it as a Kiro skill

```bash
git clone https://github.com/pprakarsh/local-first-pwa.git ~/.kiro/skills/local-first-pwa
```

`SKILL.md` carries the YAML frontmatter Kiro expects, so an agent will load it on its own when you
ask for something like *"build me a habit tracker that works on my phone"* — and then follow the
method rather than inventing one.

## Read it as a guide

| File | What it covers |
|---|---|
| [SKILL.md](SKILL.md) | When this method fits and when it doesn't, the hard rules, the workflow, and the nine traps in the order they bite |
| [reference/architecture.md](reference/architecture.md) | One store, string-rendering views, delegated events; the render loop and the three rules that follow from it |
| [reference/testing.md](reference/testing.md) | The jsdom + fake-indexeddb harness, and eight guards that enforce what prose cannot |
| [reference/platform-limits.md](reference/platform-limits.md) | What an iOS/Android PWA can and cannot do. **Read before promising a feature** |
| [reference/deploy.md](reference/deploy.md) | Free hosting, per-platform install, service worker discipline |
| [reference/sync.md](reference/sync.md) | Backup → transfer → gist sync, and the conflict guards that stop a stale device overwriting a fresh one |
| [reference/maintainability.md](reference/maintainability.md) | The docs, budgets, anti-patterns and debt-with-triggers that keep a dependency-free codebase alive |

## When this is the right method

| Use it when | Don't when |
|---|---|
| One user, their own data | Users must share or see each other's data |
| A phone and maybe a laptop | You need an Apple Watch, widget or Live Activity |
| Offline must work | You need background GPS, HealthKit, BLE or real push |
| You want no server and no account | You need server-side compute or secrets |
| Longevity matters more than ecosystem | You want a large component library |

The limits are hard. `reference/platform-limits.md` lists them precisely, because discovering them
after building is the most expensive mistake available here.

## Why no dependencies

Not minimalism for its own sake. A personal tool you want working in five years cannot depend on a
toolchain that needs maintenance now. No framework upgrades, no build to break, no transitive
advisories, no lockfile rot — and the whole app is a folder you can copy.

The cost is that nothing external will tell you the code has rotted, which is why the method leans
so heavily on mechanical guards.

## Verify the scaffold still works

```bash
./verify.sh
```

Scaffolds into a temp directory, installs the dev dependencies, runs all three generated suites, and
asserts the guards fail when their invariants are deliberately broken — so a change to the scaffold
can't silently ship a broken template.

## Licence

MIT. See [LICENSE](LICENSE).
