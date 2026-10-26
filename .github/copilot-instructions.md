# Copilot instructions

This repository is a reusable method for building a local-first, installable, dependency-free PWA
that runs on iOS, Android and any desktop browser.

Read `AGENTS.md` at the repository root first, then `SKILL.md` for the method, then the single
`reference/*.md` file matching the step you are on.

Non-negotiables: no runtime dependencies, no build step, no framework; local-first (fully usable
offline, no account); one store owns all state and persistence; views are pure functions returning
HTML strings; all events delegated through one `data-action` registry; every rule that can be a test
is a test; shell scripts stay ASCII; bump the app version and service worker cache name together.

Check `reference/platform-limits.md` before promising any feature.

Do not duplicate the method into this file; it will drift.
