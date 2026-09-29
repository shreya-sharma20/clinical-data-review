# adam-review requirements

Each requirement is testable and is mapped to at least one test in `TESTS.md`.

## Explorer

- **REQ-01** The app shall load a demo ADaM dataset (ADSL or ADAE from
  `pharmaverseadam`) by name and return the data together with per-variable
  metadata (name, label, type). An unknown dataset name shall produce a clear
  error.
- **REQ-02** The app shall read an uploaded XPT or CSV file into the same
  data-plus-metadata structure as REQ-01. A missing file or an unsupported
  file extension shall produce a clear error rather than a crash.
- **REQ-03** The app shall produce a per-variable summary table containing, for
  every variable, the type, number of non-missing values, number of missing
  values, and number of distinct values; numeric variables shall also report
  min, median, mean and max, and categorical variables shall report their most
  frequent value.
- **REQ-04** The Explorer shall display the loaded dataset in a filterable
  table, together with the variable label/type table and the summary table,
  after the user selects a demo dataset.

## Compare

- **REQ-05** The app shall compare two datasets with `diffdf::diffdf()` and
  return a tidy table with one row per difference (issue type, variable,
  detail). Identical datasets shall return an explicit "identical" result
  rather than an empty or ambiguous table.
- **REQ-06** The comparison shall detect and report differing values, columns
  present in only one dataset, differing row counts, and type (class)
  mismatches between the two datasets.
- **REQ-07** The Compare tab shall let the user supply two datasets (upload),
  run the comparison on demand via a button, and show the resulting diff table.

## Report

- **REQ-08** The app shall render a parameterized Quarto HTML report that
  combines the Explorer summary and the Compare results, and shall offer it as
  a download. Rendering shall produce a non-empty HTML file for representative
  parameters, including the "identical" compare result.

## Architecture (applies to all phases)

- **REQ-09** All work (loading, summarising, comparing, rendering) shall live in
  plain `R/fct_*.R` / `R/utils_*.R` functions with no `input`/`output`/`session`
  arguments; `app_server.R` shall contain only `mod_*_server()` wiring.
