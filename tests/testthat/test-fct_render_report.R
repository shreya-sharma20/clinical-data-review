demo_dataset <- function() {
  new_dataset(
    data.frame(
      USUBJID = c("S1", "S2", "S3"),
      AGE = c(30, 40, NA),
      SEX = c("F", "M", "F")
    ),
    "DEMO"
  )
}

demo_comparison <- function(identical = FALSE) {
  base <- demo_dataset()$data
  compare <- if (identical) base else transform(base, AGE = AGE + 1)
  compare_datasets(base, compare, base_name = "BASE", compare_name = "NEW")
}

test_that("build_report_params combines the explorer summary and comparison", {
  params <- build_report_params(demo_dataset(), demo_comparison())

  expect_named(params, c("generated", "explorer", "compare"))
  expect_equal(params$explorer$name, "DEMO")
  expect_equal(params$explorer$n_rows, 3L)
  expect_equal(params$explorer$n_cols, 3L)
  expect_equal(params$explorer$summary$variable, c("USUBJID", "AGE", "SEX"))
  expect_true("label" %in% names(params$explorer$summary))
  expect_false(params$compare$identical)
})

test_that("build_report_params accepts missing inputs", {
  params <- build_report_params()
  expect_null(params$explorer)
  expect_null(params$compare)
})

test_that("render_report validates its output path", {
  expect_error(render_report(output_file = NA_character_), "output_file")
  expect_error(render_report(output_file = c("a", "b")), "output_file")
})

test_that("render_report errors clearly when the Quarto CLI is missing", {
  local_mocked_bindings(quarto_available = function() FALSE)
  expect_error(
    render_report(output_file = withr::local_tempfile(fileext = ".html")),
    "Quarto CLI"
  )
})

test_that("the report renders with a differing comparison", {
  skip_on_cran()
  skip_if_not(quarto_available(), "Quarto CLI not available")

  out <- withr::local_tempfile(fileext = ".html")
  expect_no_error(render_report(demo_dataset(), demo_comparison(), out))

  expect_true(file.exists(out))
  expect_gt(file.size(out), 0)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "Explorer summary", fixed = TRUE)
  expect_match(html, "value_difference", fixed = TRUE)
  expect_match(html, "USUBJID", fixed = TRUE)
})

test_that("the report renders with an identical comparison", {
  skip_on_cran()
  skip_if_not(quarto_available(), "Quarto CLI not available")

  out <- withr::local_tempfile(fileext = ".html")
  expect_no_error(
    render_report(demo_dataset(), demo_comparison(identical = TRUE), out)
  )

  expect_gt(file.size(out), 0)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "no differences were found", fixed = TRUE)
})

test_that("the report renders when nothing was loaded or compared", {
  skip_on_cran()
  skip_if_not(quarto_available(), "Quarto CLI not available")

  out <- withr::local_tempfile(fileext = ".html")
  render_report(output_file = out)

  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "No dataset was loaded", fixed = TRUE)
  expect_match(html, "No comparison was run", fixed = TRUE)
})
