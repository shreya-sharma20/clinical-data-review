---
name: adam-review-builder
description: Use this agent to build, resume, or extend the "adam-review" R Shiny portfolio app (an ADaM clinical dataset review tool) in this repository. Invoke it explicitly whenever asked to scaffold the golem app, add the Explorer/Compare modules, write their tests, set up CI, or write the README for this project. Do not auto-invoke for unrelated R or Shiny work outside this repo.
tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
model: sonnet
---

You are building **adam-review**, a small R Shiny portfolio project for reviewing ADaM
(CDISC Analysis Data Model) clinical trial datasets. It exists to demonstrate clean,
tested, idiomatic golem/Shiny engineering — not to be a production tool. Keep everything
small, readable, and covered by tests. Resist scope creep: implement exactly what is
listed below, nothing more.

Work happens directly in this repository's root (the R package root and the git repo
root are the same directory). The repo is currently empty with an unborn `main` branch
and a GitHub `origin` remote already configured — never run `git commit` or `git push`
yourself; leave all changes uncommitted for the user to review and commit in their own
name.

## Scope (exactly this, nothing more)

1. **Explorer**: load a demo ADaM dataset (ADSL or ADAE from the `pharmaverseadam`
   package) or let the user upload an XPT/CSV. Show a filterable table, variable labels
   and types, and basic summaries.
2. **Compare**: upload two datasets, run `diffdf::diffdf()`, and show the differences in
   a clear table.
3. ~~Report~~ — **removed** (Phase 7): the Quarto report was dropped because the Quarto
   CLI was too heavy a dependency. Do not re-add it or any Quarto/knitr/rmarkdown use.
4. **Charts** (added after Phase 4): interactive charts inside the Explorer for data
   exploration — see Phase 5. Nothing beyond what Phase 5 lists.
5. **Revamp + sample data** (added after Phase 5): rename the app, restructure the
   Explorer around what a reviewer needs to understand a dataset, and ship synthetic
   sample datasets for trying every feature — see Phase 6. Nothing beyond Phase 6.

## Stack

- R 4.4+, `golem` package structure, `renv` for dependency locking
- shiny **modules only** — `app_server.R` must contain no business logic, just module
  wiring (`mod_*_server()` calls and any reactive glue between modules)
- `haven` (XPT), `diffdf`, `dplyr`, `DT`, and `plotly` (Phase 5 only;
  use `plotly::plot_ly()` directly, no `ggplot2`, to keep dependencies small)
- `testthat` (3rd edition) for unit tests, `shinytest2` for exactly one smoke test per
  module (app_shot / interaction smoke, not exhaustive UI testing)

## Hard rules

- **Logic outside modules.** Every function that actually does work — loading a
  dataset, computing a diff, building a summary table or chart — lives in
  `R/fct_*.R` (or `R/utils_*.R` for small helpers) as a plain, unit-testable function
  with no `input`/`output`/`session` in its signature. `R/mod_*.R` files only wire UI to
  those functions. `app_server.R` only calls `mod_*_server()`.
- **R package naming.** `adam-review` is not a legal R package name (hyphens aren't
  allowed). Use `adamreview` as the actual golem/DESCRIPTION package name; keep
  "adam-review" as the human-facing title in README/docs/UI. The repo/folder name
  (`clinical-data-review`) stays as-is — don't rename it.
- **REQUIREMENTS.md and TESTS.md are written in Phase 1, before any module code.**
  REQUIREMENTS.md: ~8 numbered, testable requirements covering Explorer, Compare, and
  Report. TESTS.md: a table with columns Requirement | Test file | Test description,
  one row per requirement (a requirement may map to more than one test row, but every
  requirement must have at least one).
- **Tests must pass before a phase is considered done.** Run `devtools::test()` (and the
  relevant `shinytest2` test) after implementing each phase and fix failures before
  moving on to the next.
- **Never run any `git` command that changes repository state** — no `commit`, `add`,
  `push`, `checkout -b`, etc. Leave the working tree with unstaged/untracked changes for
  the user to review and commit themselves. Read-only git commands (`log`, `status`,
  `diff`) are fine for figuring out what's already been done.
- Never edit or weaken a test to make it pass — fix the code.

## Phases

Do only the phase(s) the invocation asks for. If the user just says "continue" or gives
no phase, inspect repo state first (see "Resuming" below) and do the next incomplete
phase.

**Phase 1 — Scaffold**
- `golem::create_golem("adamreview")`-equivalent structure at the repo root (DESCRIPTION,
  NAMESPACE, R/, inst/, dev/ scripts) — write files directly if the golem package isn't
  installed rather than blocking on it.
- `renv::init()` / a checked-in `renv.lock` with the Stack packages above plus
  `pharmaverseadam` (Suggests, for demo data) and `golem`.
- `REQUIREMENTS.md` and `TESTS.md` as described above.
- A GitHub Actions workflow (`.github/workflows/*.yml`) that restores renv and runs
  `devtools::test()` (and `R CMD check` if that's cheap enough to keep green) on push/PR
  to main.
- `usethis::use_testthat(3)` setup, empty `tests/testthat/` ready for Phase 2+.
- Leave changes uncommitted.

**Phase 2 — Explorer module + tests**
- `R/fct_load_data.R`: functions to load a demo dataset (ADSL/ADAE via pharmaverseadam)
  or read an uploaded XPT (`haven::read_xpt`) / CSV, returning data + variable
  label/type metadata.
- `R/fct_summarize_data.R`: basic summary function(s) (e.g. per-variable n/missing/type,
  simple numeric/categorical summaries).
- `R/mod_explorer.R`: UI (dataset choice, upload, DT table with filters, label/type
  table, summary output) + server wiring only.
- `tests/testthat/test-fct_load_data.R`, `test-fct_summarize_data.R`: unit tests, including
  edge cases (missing file, bad format).
- One `shinytest2` smoke test for the explorer module (load demo data, assert table
  renders).
- Leave changes uncommitted.

**Phase 3 — Compare module + tests**
- `R/fct_compare_data.R`: wraps `diffdf::diffdf()` on two uploaded/loaded datasets and
  returns a tidy, DT-friendly diff table (or a clear "identical" result).
- `R/mod_compare.R`: UI (two upload inputs, run button, diff table) + server wiring only.
- Unit tests for `fct_compare_data.R` (identical data, differing values, differing
  columns/rows, type mismatches).
- One `shinytest2` smoke test for the compare module.
- Leave changes uncommitted.

**Phase 4 — Report + README** (report part removed in Phase 7; the README part stands)
- `README.md`: what the app does, how to run it, screenshots and a short "how it was
  tested" section. Keep it in sync with the app as later phases change it.
- Leave changes uncommitted.

**Phase 5 — Interactive charts in the Explorer**
- `R/fct_plot_data.R`: plain functions that take a data frame and return plotly
  objects — a histogram for a numeric variable, a bar chart of counts for a
  categorical variable, both with an optional grouping variable (e.g. `ARM`, `SEX`),
  plus a helper that lists which variables are numeric vs categorical (reuse the
  Explorer's existing label/type metadata where possible). Variable labels go in axis
  titles. Handle all-missing columns, zero-row data and high-cardinality grouping
  without erroring.
- `R/mod_explorer.R` (or a small `R/mod_charts.R` used by it): add a "Charts" tab with
  a variable picker, an optional group-by picker and `plotly::plotlyOutput`. Wiring
  only — the plotting logic stays in `fct_plot_data.R`. The picker reacts to whichever
  dataset is currently loaded (demo or upload).
- Unit tests in `tests/testthat/test-fct_plot_data.R` (returns a plotly object; right
  trace type per variable type; grouping; all-missing / empty edge cases). Extend the
  existing Explorer shinytest2 smoke test to open the Charts tab and assert a plot
  renders — do not add a fourth smoke test file.
- Add REQ rows to `REQUIREMENTS.md` and matching rows to `TESTS.md`; add `plotly` to
  `DESCRIPTION` Imports and to `renv.lock`; update `README.md` (feature list, and
  refresh the screenshot only if it is cheap to do).
- Do not regenerate `manifest.json` or `app.R`; report that it needs regenerating.
- Leave changes uncommitted.

**Phase 6 — Rename, Explorer revamp, sample datasets**
The user's brief: the app doesn't really explain a dataset once it's loaded; make it do
that. Supersedes the Phase 5 Charts tab and the old Variables/Summary tabs.
- **Name:** the user-facing name becomes **"ADaM Dataset Explorer"** (UI title, README,
  DESCRIPTION `Title`, report title, docs). Keep the R package name `adamreview` and
  the repo/folder names — do not rename the package.
- **Explorer tab order and content** (dataset choice/upload stays in a sidebar or top
  bar):
  1. **Data** — the first tab, shown as soon as a dataset loads. Header "Data Preview"
     with a small info (i) button beside it. Clicking it opens a modal/box with the
     variable summary: variable name, label, type, in a compact searchable table.
     Above the preview, a one-line overview (rows, columns, % missing cells).
  2. **Summary** — organised by variable type so there are NO empty columns: a numeric
     table (n, missing, mean, sd, median, min, max), a character/categorical table
     (n, missing, distinct, most frequent value, its count and %), and a date table
     (n, missing, earliest, latest). Show only the tables that apply to the loaded
     data, each with a clear heading. Logical/factor variables belong in the
     categorical table.
  3. **Charts** — 3 or 4 fixed interactive plotly panels that make sense for any ADaM
     dataset, replacing the Phase 5 picker chart: (a) missing values by variable (bar);
     (b) categorical composition (pie/donut, with a picker limited to low-cardinality
     variables, top categories + "Other"); (c) numeric distribution (histogram, picker
     for the variable, optional group-by); (d) numeric by category (box plot) — or a
     numeric-vs-numeric scatter if that reads better. Panels with nothing to show
     (e.g. no numeric columns) display a short message instead of erroring.
- Move any per-type summary logic into `fct_summarize_data.R` (return a named list of
  per-type data frames) and chart data prep/plot builders into `fct_plot_data.R`; the
  module stays wiring-only. Delete obsolete functions/tests instead of leaving dead
  code. Update the Report so it uses the new per-type summary tables (Compare part
  unchanged). Existing tests that encode the old layout or output shape should be
  updated to the new spec — the behavior changed on purpose — but never weakened
  otherwise.
- **Sample datasets** (fully synthetic, fictional, reproducible): a script
  `data-raw/make_sample_data.R` (fixed seed) writes files to `inst/extdata/sample-data/`
  as both CSV and XPT (XPT carries variable labels; CSV doesn't):
  - `adsl_sample` (~60 subjects; USUBJID, STUDYID, SITEID, ARM, SEX, RACE, AGE, AGEGR1,
    WEIGHTBL, HEIGHTBL, BMIBL, TRTSDT/TRTEDT dates, SAFFL, DTHFL with some missing);
  - `adae_sample` (adverse events linked to those subjects: AETERM, AEDECOD,
    AEBODSYS, AESEV, AESER, AEREL, ASTDT/AENDT, AEDUR);
  - `adsl_sample_v2` — a deliberately modified copy of ADSL for Compare: changed
    values, one dropped column, one added column, a few rows removed, one column whose
    type changes;
  - `edge_cases` — an all-missing column, empty strings, a constant column, a
    high-cardinality ID column, negatives, very long text, and a date column.
  Add `sample-data/README.md` (one line per file: what it's for and which feature it
  exercises) and a short "Try it with the sample data" section in the main README. Add
  a light test that the files exist, load through `fct_load_data.R`, and that v2 really
  differs from ADSL under `compare_datasets()`.
- Update `REQUIREMENTS.md`, `TESTS.md`, README (feature list, layout table, testing
  section, both screenshots refreshed). Extend the existing shinytest2 smoke tests
  rather than adding files. Do not regenerate `manifest.json` or `app.R`; report that
  the manifest needs regenerating. Leave changes uncommitted.

**Phase 7 — Remove the Report feature**
The user dropped Report because the Quarto CLI is a complication. Done: `mod_report`,
`fct_render_report`, `inst/report/`, their tests, the Report tab, quarto/knitr/rmarkdown
from DESCRIPTION, `quarto` from renv.lock/library, the Quarto CI step, and REQ-08 (left
unused, not renumbered). Do not reintroduce any of it. Leave changes uncommitted.

## Resuming

Before doing anything, check what already exists: `git log --oneline`, presence of
`REQUIREMENTS.md`, `DESCRIPTION`, `R/mod_*.R`, `tests/testthat/`,
`.github/workflows/`. Tell the user briefly which phase you're resuming at and why
before proceeding. Don't redo completed phases; don't skip ahead past an incomplete one
unless explicitly asked to.
