# adam-review test plan

Unit tests use `testthat` (3rd edition). There is exactly one `shinytest2`
smoke test per module. Tests for each module and function are written in the phase that implements it
(Explorer: Phase 2, Compare: Phase 3, Report: Phase 4).

| Requirement | Test file | Test description |
|---|---|---|
| REQ-01 | `tests/testthat/test-fct_load_data.R` | `load_demo_data("ADSL")` and `("ADAE")` return a data frame plus metadata with one row per column (name, label, type). |
| REQ-01 | `tests/testthat/test-fct_load_data.R` | An unknown demo dataset name errors with an informative message. |
| REQ-02 | `tests/testthat/test-fct_load_data.R` | A CSV file and an XPT file (written to a temp path) are read into data plus metadata; XPT variable labels are preserved. |
| REQ-02 | `tests/testthat/test-fct_load_data.R` | A missing file and an unsupported extension (e.g. `.txt`) each error with an informative message. |
| REQ-03 | `tests/testthat/test-fct_summarize_data.R` | The summary has one row per variable with type, n, n_missing and n_distinct that match hand-computed values on a small fixture. |
| REQ-03 | `tests/testthat/test-fct_summarize_data.R` | Numeric variables get min/median/mean/max, categorical variables get the top value, and an all-missing column and a zero-row data frame are handled without error. |
| REQ-04 | `tests/testthat/test-mod_explorer.R` | shinytest2 smoke test: select a demo dataset, assert the DT table, metadata table and summary output render. |
| REQ-05 | `tests/testthat/test-fct_compare_data.R` | Identical data frames return an explicit "identical" result. |
| REQ-05 | `tests/testthat/test-fct_compare_data.R` | Differing data returns a tidy table with one row per issue and columns for issue type, variable and detail. |
| REQ-06 | `tests/testthat/test-fct_compare_data.R` | Differing values, columns present in only one dataset, differing row counts, and type mismatches are each reported with the expected issue type. |
| REQ-07 | `tests/testthat/test-mod_compare.R` | shinytest2 smoke test: supply two files, click run, assert the diff table renders. |
| REQ-08 | `tests/testthat/test-fct_render_report.R` | `build_report_params()` combines the Explorer summary (with variable labels) and the Compare result, and accepts `NULL` for either. |
| REQ-08 | `tests/testthat/test-fct_render_report.R` | Rendering with representative params (differing compare result) produces a non-empty HTML file containing the summary and diff; skipped if the `quarto` CLI is unavailable. |
| REQ-08 | `tests/testthat/test-fct_render_report.R` | Rendering with an "identical" compare result, and with nothing loaded or compared, also produces a non-empty HTML file; skipped if the `quarto` CLI is unavailable. |
| REQ-08 | `tests/testthat/test-fct_render_report.R` | An invalid output path and a missing Quarto CLI each error with an informative message. |
| REQ-08 | `tests/testthat/test-mod_report.R` | shinytest2 smoke test of the Report module: the download control is present and enabled; when Quarto is installed the download also yields a non-empty HTML report. |
| REQ-09 | `tests/testthat/test-architecture.R` | Every function in `R/fct_*.R` and `R/utils_*.R` has no `input`, `output` or `session` argument, and `app_server` body only calls `mod_*_server()` functions. |
