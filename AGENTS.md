# AGENTS.md

Instructions for any AI coding agent working with this repository.

This repo is **not an application**. It is a reusable method for building one: a local-first,
installable, dependency-free Progressive Web App that runs on iOS, Android and any desktop browser.

## What to read, and when

**The method is in [SKILL.md](SKILL.md). Read it before writing any code.**

Then load one `reference/` file at a time, when you reach the step it covers. Do not read all of
them up front; each is dense and only one is relevant at a time.

| Read | When |
|---|---|
| [SKILL.md](SKILL.md) | Always, first. When the method fits, the hard rules, the workflow, the traps |
| [reference/architecture.md](reference/architecture.md) | Setting up the store, views, events, render loop |
| [reference/testing.md](reference/testing.md) | Writing the test harness and the guards |
| [reference/platform-limits.md](reference/platform-limits.md) | **Before promising any feature**, and when choosing PWA vs native |
| [reference/deploy.md](reference/deploy.md) | Hosting, installing on a phone, service worker discipline |
| [reference/sync.md](reference/sync.md) | Adding backup, device transfer or cross-device sync |
| [reference/maintainability.md](reference/maintainability.md) | Writing the project's own docs and guards |

## When this method applies

Use it when the user asks for a personal tool — a tracker, logger, planner, checklist, calculator —
that must work on their phone and their laptop, offline, without an account; or when they ask to
avoid a build step or dependencies; or when they ask how to make something installable.

Do **not** use it when the app needs multiple users sharing data, server-side compute or secrets, an
Apple Watch app, widgets, Live Activities, background GPS, HealthKit, or Bluetooth. Those are
impossible in this method — say so early rather than building most of an app first.
`reference/platform-limits.md` has the complete list.

## Non-negotiables

These are the rules that make the method work. Breaking one quietly turns the project into an
ordinary web app with all the maintenance that implies.

1. **No runtime dependencies, no build step, no framework.** Plain ES modules served as static
   files. Dev-only test dependencies live in `test/package.json` and never ship.
2. **Local-first.** The app must be fully usable with no network and no account. Sync is optional
   and additive, never a dependency.
3. **One store owns all state and all persistence.** Everything else reads it and calls its
   mutators.
4. **Views are pure functions returning HTML strings.** No DOM references, no local state.
5. **All events are delegated** through one registry of `data-action` handlers.
6. **Every rule that can be a test must be a test.** Prose decays silently; a failing test does not.
7. **Shell scripts stay ASCII.** macOS ships bash 3.2, which folds the bytes of a non-ASCII
   character following a variable into the variable name.
8. **Bump the app version and the service worker cache name together**, enforced by a test.

## Starting a new app

Do not hand-write the boilerplate. Run the scaffold:

```bash
./scripts/scaffold.sh ~/my-app "My App"
cd ~/my-app
(cd test && npm install && npm test)            # must be green before you build anything
python3 -m http.server 8000 --bind 127.0.0.1    # http://localhost:8000
```

It produces a complete working app — shell, store, IndexedDB wrapper, two CRUD tabs, modals,
backup/restore/CSV, a network-first service worker, generated icons, three test suites with eight
guards wired, a deploy script and three documents. Delete what you don't need, then build.

`file://` will not work — ES modules are blocked by CORS. Always serve over `localhost`.

## Verification gates — mandatory

Never report success on an unverified claim.

- `npm test` green, including the guards.
- Served over HTTP with `.js` returning `text/javascript` or `application/javascript`, or ES
  modules will not load.
- Reload the page and confirm data survives.
- After deploying, fetch the live version marker and confirm it matches what you shipped.
- **State plainly what you could not verify.** This harness cannot check visual layout, touch
  ergonomics, real iOS Safari behaviour, or any real third-party API.

## Changing this repo

```bash
./verify.sh
```

Scaffolds into a temp directory, parses every generated module, runs all three generated suites, and
asserts the guards fail when their invariants are deliberately broken. It must pass before any
commit that touches `scripts/scaffold.sh`.

**Single source of truth:** the method lives in `SKILL.md` and `reference/`. The per-tool files
listed below are routers that point here — never copy content into them, or the copies will drift.

## How this is wired into different tools

| Tool | File | Role |
|---|---|---|
| Codex, Cursor, Copilot, Aider, Windsurf, Zed, Gemini CLI, Claude Code | `AGENTS.md` | This file. The cross-tool standard, read natively |
| Claude Code (older versions), Anthropic Agent Skills | `CLAUDE.md`, `SKILL.md` | `CLAUDE.md` imports this file; `SKILL.md` carries skill frontmatter |
| Kiro | `SKILL.md` | Skill frontmatter, auto-activated by description match |
| Cursor (scoped rules) | `.cursor/rules/local-first-pwa.mdc` | Router with Cursor frontmatter |
| GitHub Copilot | `.github/copilot-instructions.md` | Router |
| Windsurf | `.windsurfrules` | Router |
| Cline / Roo | `.clinerules` | Router |

Install it for your own tool with `./install.sh --help`.
