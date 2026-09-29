fixture <- function() {
  data.frame(
    USUBJID = c("01", "02", "03", "04"),
    SEX = c("F", "M", "F", ""),
    AGE = c(30, 40, NA, 50),
    stringsAsFactors = FALSE
  )
}

test_that("summarize_data() returns one row per variable with counts", {
  res <- summarize_data(fixture())

  expect_named(
    res,
    c("variable", "type", "n", "n_missing", "n_distinct",
      "min", "median", "mean", "max", "top_value")
  )
  expect_identical(res$variable, c("USUBJID", "SEX", "AGE"))
  expect_identical(res$type, c("character", "character", "numeric"))
  expect_identical(res$n, c(4L, 3L, 3L))
  expect_identical(res$n_missing, c(0L, 1L, 1L)) # "" counts as missing
  expect_identical(res$n_distinct, c(4L, 2L, 3L))
})

test_that("summarize_data() gives numeric stats and categorical top values", {
  res <- summarize_data(fixture())
  by_var <- function(v) res[res$variable == v, ]

  age <- by_var("AGE")
  expect_equal(age$min, 30)
  expect_equal(age$median, 40)
  expect_equal(age$mean, 40)
  expect_equal(age$max, 50)
  expect_true(is.na(age$top_value))

  sex <- by_var("SEX")
  expect_identical(sex$top_value, "F")
  expect_true(all(is.na(sex[c("min", "median", "mean", "max")])))
})

test_that("summarize_data() breaks top-value ties by first appearance", {
  res <- summarize_data(data.frame(X = c("b", "a", "a", "b")))
  expect_identical(res$top_value, "b")
})

test_that("summarize_data() treats dates, factors and logicals as categorical", {
  df <- data.frame(
    D = as.Date(c("2020-01-01", "2020-01-01", "2020-02-01")),
    F = factor(c("x", "y", "y")),
    L = c(TRUE, TRUE, FALSE)
  )
  res <- summarize_data(df)

  expect_identical(res$type, c("date", "factor", "logical"))
  expect_identical(res$top_value, c("2020-01-01", "y", "TRUE"))
  expect_true(all(is.na(res$mean)))
})

test_that("summarize_data() handles an all-missing column without error", {
  df <- data.frame(
    N = c(NA_real_, NA_real_),
    C = c(NA_character_, ""),
    stringsAsFactors = FALSE
  )

  expect_no_warning(res <- summarize_data(df))
  expect_identical(res$n, c(0L, 0L))
  expect_identical(res$n_missing, c(2L, 2L))
  expect_identical(res$n_distinct, c(0L, 0L))
  expect_true(all(is.na(res$min)))
  expect_true(all(is.na(res$top_value)))
})

test_that("summarize_data() handles zero-row and zero-column data frames", {
  zero_rows <- fixture()[0, ]
  expect_no_warning(res <- summarize_data(zero_rows))
  expect_identical(nrow(res), 3L)
  expect_identical(res$n, c(0L, 0L, 0L))
  expect_identical(res$n_missing, c(0L, 0L, 0L))

  zero_cols <- summarize_data(data.frame())
  expect_identical(nrow(zero_cols), 0L)
  expect_identical(names(zero_cols), names(res))
})

test_that("summarize_data() rejects non-data-frame input", {
  expect_error(summarize_data(1:3))
})

test_that("summarize_data() works on a real demo dataset", {
  skip_if_not_installed("pharmaverseadam")

  adsl <- load_demo_data("ADSL")$data
  res <- summarize_data(adsl)

  expect_identical(res$variable, names(adsl))
  expect_identical(res$n + res$n_missing, rep(nrow(adsl), ncol(adsl)))
})
