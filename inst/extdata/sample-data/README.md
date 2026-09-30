# Sample datasets

Fully synthetic and fictional (no real subjects or studies), generated with a
fixed seed by `data-raw/make_sample_data.R`. Each dataset comes as `.csv` (no
variable labels) and `.xpt` (with variable labels and SAS dates).

- `adsl_sample` - 60 subjects, one row each: try it in **Explorer** (all three tabs, and dates in the Summary tab).
- `adae_sample` - adverse events for those subjects, linked by `USUBJID`: try it in **Explorer** for a second, larger dataset with categorical variables to chart.
- `adsl_sample_v2` - `adsl_sample` with changed values, a dropped column (`HEIGHTBL`), an added column (`RANDFL`), 3 rows removed from the end and a column that changed type (`WEIGHTBL`): upload it against `adsl_sample` in **Compare**.
- `adsl_sample_copy` - an unchanged copy of `adsl_sample`: upload the two in **Compare** to see the "No differences found" result.
- `adae_sample_v2` - `adae_sample` with changed values (`AESEV`, `AEDUR`, `AETERM`), a renamed column (`AEREL` becomes `AERELAT`) and 4 extra events at the end: **Compare** against `adae_sample`.
- `adsl_sample_rounded` - `adsl_sample` with `WEIGHTBL` and `BMIBL` rounded to the nearest 0.5, and `HEIGHTBL` nudged by 1e-10: **Compare** reports the rounded columns but not `HEIGHTBL`, because the nudge is below diffdf's tolerance.
- `adsl_sample_sorted` - the same 60 subjects with the columns reversed and the rows sorted by `AGE`: **Compare** reports differences in nearly every column because rows are matched by position, so sort both datasets the same way first.
- `edge_cases` - an all-missing column, empty strings, a constant column, a high-cardinality ID, negatives, very long text and a date column: try it in **Explorer** to see how empty and awkward data is handled.
