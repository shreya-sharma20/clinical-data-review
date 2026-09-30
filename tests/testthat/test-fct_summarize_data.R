fixture <- function() {
  data.frame(
    USUBJID = c("01", "02", "03", "04"),
    SEX = c("F", "M", "F", ""),
    AGE = c(30, 40, NA, 50),
    stringsAsFactors = FALSE
  )
}

mixed_fixture <- function() {
  data.frame(
    AGE = c(30, 40, 50, NA),
    SEX = c("F", "M", "F", ""),
    FLAG = c(TRUE, TRUE, FALSE, NA),
    ARM = factor(c("A", "A", "B", "B")),
    START = as.Date(c("2020-03-01", "2020-01-15", NA, "2020-02-01")),
    stringsAsFactors = FALSE
  )
}

# summarize_data(): shape ------------------------------------------------------

test_that("summarize_data() returns one table per variable type that applies", {
  res <- summarize_data(mixed_fixture())

  expect_named(res, c("numeric", "categorical", "date"))
  expect_identical(res$numeric$variable, "AGE")
  expect_identical(res$categorical$variable, c("SEX", "FLAG", "ARM"))
  expect_identical(res$date$variable, "START")
})

test_that("summarize_data() leaves out tables that do not apply", {
  res <- summarize_data(fixture())
  expect_named(res, c("numeric", "categorical"))

  expect_named(summarize_data(data.frame(D = Sys.Date())), "date")
  expect_named(summarize_data(data.frame(X = c(1, 2))), "numeric")
})

test_that("each table has exactly the columns that apply to its type", {
  res <- summarize_data(mixed_fixture())

  expect_named(
    res$numeric,
    c("variable", "n", "missing", "mean", "sd", "median", "min", "max")
  )
  expect_named(
    res$categorical,
    c("variable", "n", "missing", "distinct", "top_value", "top_n", "top_pct")
  )
  expect_named(res$date, c("variable", "n", "missing", "earliest", "latest"))
})

test_that("no table has a column that is entirely NA for fully populated data", {
  data <- data.frame(
    N = c(1, 2, 3), C = c("a", "b", "b"), D = as.Date("2020-01-01") + 0:2,
    stringsAsFactors = FALSE
  )
  for (table in summarize_data(data)) {
    expect_false(any(vapply(table, function(col) all(is.na(col)), logical(1))))
  }
})

# summarize_data(): values -----------------------------------------------------

test_that("numeric summaries match hand-computed values", {
  age <- summarize_data(fixture())$numeric

  expect_identical(nrow(age), 1L)
  expect_identical(age$n, 3L)
  expect_identical(age$missing, 1L)
  expect_equal(age$mean, 40)
  expect_equal(age$sd, 10)
  expect_equal(age$median, 40)
  expect_equal(age$min, 30)
  expect_equal(age$max, 50)
})

test_that("categorical summaries count the empty string as missing", {
  res <- summarize_data(fixture())$categorical

  expect_identical(res$variable, c("USUBJID", "SEX"))
  expect_identical(res$n, c(4L, 3L))
  expect_identical(res$missing, c(0L, 1L))
  expect_identical(res$distinct, c(4L, 2L))
  sex <- res[res$variable == "SEX", ]
  expect_identical(sex$top_value, "F")
  expect_identical(sex$top_n, 2L)
  expect_equal(sex$top_pct, 100 * 2 / 3)
})

test_that("categorical summaries break top-value ties by first appearance", {
  res <- summarize_data(data.frame(X = c("b", "a", "a", "b")))$categorical
  expect_identical(res$top_value, "b")
  expect_equal(res$top_pct, 50)
})

test_that("logical and factor variables are summarised as categorical", {
  res <- summarize_data(mixed_fixture())$categorical

  flag <- res[res$variable == "FLAG", ]
  expect_identical(flag$top_value, "TRUE")
  expect_identical(flag$n, 3L)
  expect_identical(flag$missing, 1L)
  arm <- res[res$variable == "ARM", ]
  expect_identical(arm$top_value, "A")
  expect_identical(arm$distinct, 2L)
})

test_that("date summaries give the earliest and latest date", {
  res <- summarize_data(mixed_fixture())$date

  expect_identical(res$n, 3L)
  expect_identical(res$missing, 1L)
  expect_identical(res$earliest, "2020-01-15")
  expect_identical(res$latest, "2020-03-01")
})

test_that("date-times are summarised in the date table", {
  data <- data.frame(
    T = as.POSIXct(c("2020-01-01 10:00:00", "2020-01-02 12:30:00"), tz = "UTC")
  )
  res <- summarize_data(data)$date
  expect_match(res$earliest, "2020-01-01 10:00:00")
  expect_match(res$latest, "2020-01-02 12:30:00")
})

# summarize_data(): edge cases -------------------------------------------------

test_that("summarize_data() handles all-missing columns without error", {
  df <- data.frame(
    N = c(NA_real_, NA_real_),
    C = c(NA_character_, ""),
    D = as.Date(c(NA, NA)),
    stringsAsFactors = FALSE
  )

  expect_no_warning(res <- summarize_data(df))
  expect_identical(res$numeric$n, 0L)
  expect_identical(res$numeric$missing, 2L)
  expect_true(all(is.na(res$numeric[c("mean", "sd", "median", "min", "max")])))
  expect_identical(res$categorical$n, 0L)
  expect_identical(res$categorical$distinct, 0L)
  expect_true(is.na(res$categorical$top_value))
  expect_identical(res$categorical$top_n, 0L)
  expect_true(is.na(res$categorical$top_pct))
  expect_identical(res$date$missing, 2L)
  expect_true(is.na(res$date$earliest))
})

test_that("a single value has no standard deviation but does not error", {
  res <- summarize_data(data.frame(X = 5))$numeric
  expect_true(is.na(res$sd))
  expect_equal(res$mean, 5)
})

test_that("summarize_data() handles zero-row and zero-column data frames", {
  expect_no_warning(res <- summarize_data(mixed_fixture()[0, ]))
  expect_named(res, c("numeric", "categorical", "date"))
  expect_identical(res$numeric$n, 0L)
  expect_identical(res$categorical$missing, c(0L, 0L, 0L))

  zero_cols <- summarize_data(data.frame())
  expect_length(zero_cols, 0L)
})

test_that("summarize_data() rejects non-data-frame input", {
  expect_error(summarize_data(1:3))
})

test_that("summarize_data() works on a real demo dataset", {
  skip_if_not_installed("pharmaverseadam")

  adsl <- load_demo_data("ADSL")$data
  res <- summarize_data(adsl)

  all_variables <- unlist(lapply(res, `[[`, "variable"))
  expect_setequal(all_variables, names(adsl))
  for (table in res) {
    expect_true(all(table$n + table$missing == nrow(adsl)))
  }
})

# is_missing(), dataset_overview(), overview_text() ----------------------------

test_that("is_missing() treats NA as missing, and '' only for character data", {
  expect_identical(is_missing(c("a", "", NA)), c(FALSE, TRUE, TRUE))
  expect_identical(is_missing(c(1, NA, NaN)), c(FALSE, TRUE, TRUE))
  expect_identical(is_missing(factor(c("a", NA))), c(FALSE, TRUE))
})

test_that("dataset_overview() reports size and percentage of missing cells", {
  ov <- dataset_overview(fixture()) # 12 cells: one "" and one NA

  expect_identical(ov$n_rows, 4L)
  expect_identical(ov$n_cols, 3L)
  expect_equal(ov$pct_missing, 100 * 2 / 12)
  expect_equal(dataset_overview(data.frame())$pct_missing, 0)
  expect_equal(dataset_overview(fixture()[0, ])$pct_missing, 0)
})

test_that("overview_text() gives a one-line description", {
  expect_identical(
    overview_text(dataset_overview(fixture())),
    "4 rows | 3 columns | 16.7% of cells missing"
  )
  expect_match(
    overview_text(list(n_rows = 1L, n_cols = 1L, pct_missing = 0)),
    "^1 row \\| 1 column \\|"
  )
  expect_match(
    overview_text(list(n_rows = 12345L, n_cols = 2L, pct_missing = 0)),
    "^12,345 rows"
  )
})
