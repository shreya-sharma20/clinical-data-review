# ADaM Dataset Explorer test plan

Unit tests use `testthat` (3rd edition). There is exactly one `shinytest2`
smoke test per module (the Explorer and Compare tests each contain extra
assertions rather than extra files). Tests for each module and function are
written in the phase that implements it (Explorer: Phase 2, Compare: Phase 3,
Explorer charts: Phase 5, revamp and sample data: Phase 6). REQ-08 (Report) was
withdrawn, so it has no tests.

| Requirement | Test file | Test description |
|---|---|---|
| REQ-01 | `tests/testthat/test-fct_load_data.R` | `load_demo_data("ADSL")` and `("ADAE")` return a data frame plus metadata with one row per column (name, label, type). |
| REQ-01 | `tests/testthat/test-fct_load_data.R` | An unknown demo dataset name errors with an informative message. |
| REQ-02 | `tests/testthat/test-fct_load_data.R` | A CSV file and an XPT file (written to a temp path) are read into data plus metadata; XPT variable labels are preserved. |
| REQ-02 | `tests/testthat/test-fct_load_data.R` | A missing file and an unsupported extension (e.g. `.txt`) each error with an informative message. |
| REQ-02 | `tests/testthat/test-fct_load_data.R` | ISO date columns in a CSV are read as dates (empty strings become `NA`); columns with other text or invalid dates stay text. |
| REQ-03 | `tests/testthat/test-fct_summarize_data.R` | `summarize_data()` returns one table per variable type present (numeric, categorical, date) and leaves out the types that are absent; each table has exactly its own columns. |
| REQ-03 | `tests/testthat/test-fct_summarize_data.R` | Numeric statistics, categorical counts/top value/top percentage (ties broken by first appearance, `""` counted as missing) and date earliest/latest match hand-computed values; logical and factor variables are categorical, date-times go in the date table. |
| REQ-03 | `tests/testthat/test-fct_summarize_data.R` | All-missing columns, a single value, zero-row and zero-column data frames are handled without error or warning. |
| REQ-03 | `tests/testthat/test-fct_summarize_data.R` | `is_missing()`, `dataset_overview()` and `overview_text()` give the missing-cell percentage and the one-line overview. |
| REQ-04 | `tests/testthat/test-mod_explorer.R` | shinytest2 smoke test: after selecting ADAE the Data tab shows the "Data Preview" header, the overview line and a filterable table; the (i) button opens a pop-up listing variable labels; the Summary tab shows a numeric, a categorical and a date table under their headings with type-specific columns. Uploading the sample CSV then replaces the data, the pop-up notes that CSV files have no variable labels, and the CSV's ISO dates appear in the date table. |
| REQ-05 | `tests/testthat/test-fct_compare_data.R` | Identical data frames return an explicit "identical" result. |
| REQ-05 | `tests/testthat/test-fct_compare_data.R` | Differing data returns a tidy table with one row per issue and columns for issue type, variable and detail. |
| REQ-06 | `tests/testthat/test-fct_compare_data.R` | Differing values, columns present in only one dataset, differing row counts, and type mismatches are each reported with the expected issue type. |
| REQ-07 | `tests/testthat/test-mod_compare.R` | shinytest2 smoke test: supply two files, click run, assert the diff table renders. |
| REQ-07 | `tests/testthat/test-mod_compare.R` | The same flow with the shipped `adsl_sample.xpt` and `adsl_sample_v2.xpt` shows every issue type in the diff table. |
| REQ-10 | `tests/testthat/test-fct_plot_data.R` | `chart_choices()` splits variables into numeric and low-cardinality categorical (dates, identifiers, all-missing variables excluded; constant variables last), labels the display names, applies the cardinality limit inclusively, and handles zero-variable and zero-row data. |
| REQ-10 | `tests/testthat/test-fct_plot_data.R` | `plot_missing()` draws one horizontal bar per incomplete variable, ranked by percentage missing and capped for wide data. |
| REQ-10 | `tests/testthat/test-fct_plot_data.R` | `plot_composition()` returns a donut (pie trace with a hole) of category counts for character, factor and logical variables. |
| REQ-10 | `tests/testthat/test-fct_plot_data.R` | `plot_histogram()` returns a histogram trace, drops missing and non-finite values, and shares bins across groups; `plot_boxplot()` returns one box trace per category. |
| REQ-10 | `tests/testthat/test-fct_plot_data.R` | Axis titles use the variable label plus name (`Age (AGE)`), falling back to the name when there is no label. |
| REQ-11 | `tests/testthat/test-fct_plot_data.R` | Grouping gives one histogram trace per group with missing groups labelled "(Missing)" and a legend title; `NULL`, `""` and self-grouping mean no grouping. |
| REQ-11 | `tests/testthat/test-fct_plot_data.R` | High-cardinality grouping, composition slices and box categories are pooled into "Other" without losing rows. |
| REQ-11 | `tests/testthat/test-fct_plot_data.R` | All-missing columns, zero-row data, data without missing values and unavailable variables (`NULL`/`""`) give an empty annotated plot without error; unknown columns and wrong-type variables error clearly. |
| REQ-11 | `tests/testthat/test-fct_plot_data.R` | All four charts work on the real ADSL and ADAE demo datasets. |
| REQ-12 | `tests/testthat/test-mod_explorer.R` | The existing Explorer shinytest2 smoke test also opens the Charts tab, checks the pickers follow ADAE (`AESEV` offered, high-cardinality `AEDECOD` not), asserts that the bar, donut, histogram and box plot all render, and that grouping the histogram by `SEX` gives a legend and an `AGE` axis title. |
| REQ-13 | `tests/testthat/test-sample_data.R` | All four sample datasets exist as CSV and XPT plus a README; every file loads through `read_uploaded_data()`; XPT files carry labels and CSV files do not; CSV and XPT have matching shapes. |
| REQ-13 | `tests/testthat/test-sample_data.R` | `adsl_sample` has 60 unique subjects, dates and missing values; `adae_sample` links to it by `USUBJID`. |
| REQ-13 | `tests/testthat/test-sample_data.R` | `adsl_sample_v2` differs from `adsl_sample` under `compare_datasets()` (value differences, dropped and added column, removed rows, type change) in both formats, while `adsl_sample` equals itself. |
| REQ-13 | `tests/testthat/test-sample_data.R` | The extra Compare pairs behave as documented, in CSV and XPT: `adsl_sample_copy` is identical; `adae_sample_v2` shows value differences, the `AEREL`/`AERELAT` rename and extra rows; `adsl_sample_rounded` reports `WEIGHTBL` and `BMIBL` but not the sub-tolerance `HEIGHTBL`; `adsl_sample_sorted` differs only by value (row position) and holds the same subjects. |
| REQ-13 | `tests/testthat/test-sample_data.R` | `edge_cases` contains each awkward column (all-missing, empty strings, constant, high-cardinality ID, negatives, long text, dates) and goes through the summaries and charts without error. |
| REQ-14 | `tests/testthat/test-app_ui.R` | The application UI is titled "ADaM Dataset Explorer", no longer mentions "adam-review", and the package is still named `adamreview`. |
| REQ-09 | `tests/testthat/test-architecture.R` | Every function in `R/fct_*.R` and `R/utils_*.R` has no `input`, `output` or `session` argument, and `app_server` body only calls `mod_*_server()` functions. |
