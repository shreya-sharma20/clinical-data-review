base_df <- function() {
  data.frame(
    id = 1:3,
    x = c("a", "b", "c"),
    y = c(1.5, 2.5, 3.5),
    stringsAsFactors = FALSE
  )
}

issues_of <- function(res, type) {
  res$table[res$table$issue == type, , drop = FALSE]
}

test_that("identical data frames return an explicit identical result", {
  res <- compare_datasets(base_df(), base_df())

  expect_true(res$identical)
  expect_equal(nrow(res$table), 1L)
  expect_equal(res$table$issue, "identical")
  expect_named(res$table, c("issue", "variable", "detail"))
})

test_that("differing data returns a tidy table with one row per issue", {
  other <- base_df()
  other$x[2] <- "B"
  other$y[3] <- 9
  other$z <- 1:3

  res <- compare_datasets(base_df(), other)

  expect_false(res$identical)
  expect_named(res$table, c("issue", "variable", "detail"))
  expect_s3_class(res$table, "data.frame")
  expect_setequal(
    paste(res$table$issue, res$table$variable),
    c("value_difference x", "value_difference y", "column_only_in_compare z")
  )
  expect_false(anyNA(res$table))
  expect_equal(rownames(res$table), as.character(seq_len(nrow(res$table))))
})

test_that("differing values report the count and the offending rows", {
  other <- base_df()
  other$x[c(1, 3)] <- c("A", "C")

  res <- compare_datasets(base_df(), other)
  hit <- issues_of(res, "value_difference")

  expect_equal(hit$variable, "x")
  expect_match(hit$detail, "2 value(s) differ", fixed = TRUE)
  expect_match(hit$detail, "row 1: base 'a' vs compare 'A'", fixed = TRUE)
})

test_that("value differences are identified by key when keys are given", {
  other <- base_df()
  other$x[2] <- "B"

  res <- compare_datasets(base_df(), other, keys = "id")

  expect_match(issues_of(res, "value_difference")$detail, "id=2", fixed = TRUE)
})

test_that("columns present in only one dataset are reported", {
  other <- base_df()
  other$y <- NULL
  other$w <- 1

  res <- compare_datasets(base_df(), other)

  expect_equal(issues_of(res, "column_only_in_base")$variable, "y")
  expect_equal(issues_of(res, "column_only_in_compare")$variable, "w")
  expect_match(issues_of(res, "column_only_in_base")$detail,
               "in BASE but not in COMPARE", fixed = TRUE)
})

test_that("differing row counts are reported with the extra rows", {
  bigger <- rbind(base_df(), data.frame(id = 4L, x = "d", y = 4.5))

  res <- compare_datasets(base_df(), bigger)

  expect_match(issues_of(res, "row_count")$detail,
               "BASE has 3 rows but COMPARE has 4", fixed = TRUE)
  expect_match(issues_of(res, "rows_only_in_compare")$detail, "row 4",
               fixed = TRUE)
  expect_equal(nrow(issues_of(res, "rows_only_in_base")), 0L)

  # Reversed: the extra row now lives in BASE.
  res_rev <- compare_datasets(bigger, base_df())
  expect_equal(nrow(issues_of(res_rev, "rows_only_in_base")), 1L)
})

test_that("type mismatches are reported for columns in both datasets", {
  other <- base_df()
  other$y <- as.character(other$y)

  res <- compare_datasets(base_df(), other)
  hit <- issues_of(res, "type_mismatch")

  expect_equal(hit$variable, "y")
  expect_match(hit$detail, "numeric in base but character in compare",
               fixed = TRUE)
  # A type mismatch alone must not be reported as a value difference.
  expect_equal(nrow(issues_of(res, "value_difference")), 0L)
})

test_that("custom dataset names appear in the details", {
  bigger <- rbind(base_df(), data.frame(id = 4L, x = "d", y = 4.5))

  res <- compare_datasets(base_df(), bigger,
                          base_name = "v1", compare_name = "v2")

  expect_equal(res$base_name, "v1")
  expect_match(issues_of(res, "row_count")$detail, "v1 has 3 rows but v2 has 4",
               fixed = TRUE)
})

test_that("long lists of differing values are truncated in the detail", {
  many <- data.frame(x = 1:10)
  changed <- data.frame(x = 11:20)

  hit <- issues_of(compare_datasets(many, changed), "value_difference")

  expect_match(hit$detail, "10 value(s) differ", fixed = TRUE)
  expect_match(hit$detail, "; ...)", fixed = TRUE)
})

test_that("invalid input errors clearly", {
  expect_error(compare_datasets(base_df(), "not a data frame"))
  expect_error(
    compare_datasets(base_df(), base_df(), keys = "nope"),
    "Could not compare the datasets"
  )
})
