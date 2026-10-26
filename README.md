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

## Use it with any AI agent

The method is tool-agnostic. `AGENTS.md` is the entry point — the cross-tool standard that Codex,
Cursor, Copilot, Aider, Windsurf, Zed, Gemini CLI and Claude Code all read natively — and small
router files wire it into the tools that want their own filename.

**Globally, for your own agent** (a symlink, so `git pull` updates every tool at once):

```bash
git clone https://github.com/pprakarsh/local-first-pwa.git ~/src/local-first-pwa
cd ~/src/local-first-pwa
./install.sh kiro        # or: claude | cursor
./install.sh list        # show what is installed where
```

**Into a project**, so any agent that opens that repo picks it up:

```bash
./install.sh project ~/my-project
```

| Tool | File it reads | Role |
|---|---|---|
| Codex, Cursor, Copilot, Aider, Windsurf, Zed, Gemini CLI, Claude Code | `AGENTS.md` | The cross-tool standard, read natively |
| Claude Code (older), Anthropic Agent Skills | `CLAUDE.md`, `SKILL.md` | `CLAUDE.md` imports AGENTS.md; `SKILL.md` carries skill frontmatter |
| Kiro | `SKILL.md` | Skill frontmatter, auto-activated by description match |
| Cursor (scoped rules) | `.cursor/rules/local-first-pwa.mdc` | Router with Cursor frontmatter and globs |
| GitHub Copilot | `.github/copilot-instructions.md` | Router |
| Windsurf | `.windsurfrules` | Router |
| Cline / Roo | `.clinerules` | Router |

**One source of truth.** The method lives only in `SKILL.md` and `reference/`. Every per-tool file
is a short pointer, never a copy — `verify.sh` fails if any of them grows past 40 lines, because at
that point it has become a second copy that will drift.

Skill, or always-on rules? This is deliberately a **skill**: it is needed for *some* tasks, not
every session. That is why the content sits behind a description-matched trigger rather than being
injected into every prompt.

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
