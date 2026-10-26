# Keeping it alive

A no-dependency app has no framework upgrades to force maintenance, which is the point — and also
the risk: nothing external will tell you the codebase has rotted. These are the cheap habits that
substitute.

## Three documents, each with one job

| File | Job | Audience |
|---|---|---|
| `README.md` | What it is, how to install and use it, the data formats | the user (often you, in a year) |
| `ARCHITECTURE.md` | How it works: module map, data model, render loop, flows, **known gotchas** | whoever changes it next |
| `AGENTS.md` | Rules, recipes, checklists, debt, product decisions | humans and AI agents editing it |
| `ROADMAP.md` | Candidate features with effort and dependencies, platform limits, rejected ideas | whoever asks "what next" |

`AGENTS.md` is the entry point. An AI agent opening the repo reads it first, and a human picking the
project back up gets the same orientation.

## The one habit that matters most

**Anything in the docs that can be a test must become a test.** Prose decays silently; a failing
test does not. The guard list in `testing.md` exists because each of those rules was first written
as prose and then broken.

Equally: **every bug fix gets a test that fails without the fix.** Verify the new test actually
fails when you revert the fix, or you have written something that proves nothing.

## A "known gotchas" section, written as symptoms

In `ARCHITECTURE.md`, list every bug that has already happened, with the symptom first. The next
reader is searching for a symptom, not a cause. And every comment in the code that explains a
workaround should name the bug it prevents — otherwise the next person's instinct is to simplify it
away.

## A complexity budget with real numbers

| | Soft target | Hard cap (tested) |
|---|---|---|
| Lines per module | 500 | 1000 |
| Runtime dependencies | 0 | 0 |
| Build steps | 0 | 0 |

Record **today's actuals** next to the budget, and name **where the seams are** when the biggest
module needs splitting — so the split happens along an existing boundary rather than an invented
one. A module over the soft target is a signal, not a sin: split when it has two audiences, not when
it has many lines.

## Anti-patterns worth naming explicitly

Write these down, because each is a reasonable-sounding suggestion that quietly ruins the method:

- **A second source of truth.** Derive on read instead of caching into the store. A derived
  exercise library cannot drift; a stored one can.
- **Schema knowledge in two places.** Field names and formats live in `normalizeX()`. Docs and
  samples *describe* it; they must not re-implement it.
- **Storing derived values** (totals, estimates, progress). Compute them.
- **Silent failure.** Every error path either shows the real message or carries a comment saying why
  swallowing it is correct.
- **A framework, bundler or dependency.** The whole value proposition is that it still runs in five
  years with no toolchain.

## A changed-X → update-Y map

The cheapest defence against doc drift. For example:

| Changed | Also update |
|---|---|
| A field on a record | `normalizeX`, the form, the exporter, the samples, the README field table |
| The CSV columns | the README export table — the order is a contract someone's spreadsheet depends on |
| A new module | the service worker `ASSETS` list, the `ARCHITECTURE.md` module map |
| The render loop or state shape | `ARCHITECTURE.md` — this is the doc that stops the next person guessing |
| A fixed bug with a subtle cause | the gotchas list |

## An honest debt table, with triggers not wishes

Give every known shortcut a **trigger** rather than "someday", so the decision to pay it off is
mechanical:

| Debt | Trigger |
|---|---|
| Sync is a blob and cannot merge | when you start using two devices in the same week |
| No migration framework | when a field must *change meaning* rather than be added |
| Totals ignore a category of record | **before** building anything that aggregates, or it is wrong from day one |
| The largest module | when it passes ~900 lines |

## A pre-commit checklist

```
[ ] npm test green, including the guards
[ ] every behaviour change has an assertion that fails without it
[ ] app version and service worker cache bumped together
[ ] new files added to the service worker ASSETS list
[ ] new modules added to the ARCHITECTURE.md module map
[ ] no console.log, no commented-out code, no dead handlers
[ ] docs updated per the map above
[ ] Conventional Commit message explaining what and why
```

## Baselines not to regress

- **Performance.** Rebuilding the whole view on every change is fine at this data size. If a view
  gets slow, paginate it before reaching for a framework.
- **Accessibility.** Inputs ≥16px so iOS does not zoom; touch targets ~34px; `aria-label` on
  unlabelled inputs; real `<button>` elements.
- **Privacy.** Nothing leaves the device without an explicit tap. No analytics, no telemetry, no
  crash reporter.

## Product decisions, recorded

Keep a short list of decisions that are **not** bugs, so they are not re-litigated by accident, each
with its reason. Cross-reference it from the roadmap's "deliberately rejected" section. Changing one
should feel like a product decision, because it is.
