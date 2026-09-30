test_that("compare module runs a comparison and renders the diff table", {
  skip_on_cran()
  skip_if_not_installed("shinytest2")
  skip_if(
    is.null(tryCatch(chromote::find_chrome(), error = function(e) NULL)),
    "No Chrome/Chromium available for shinytest2"
  )

  base_path <- withr::local_tempfile(fileext = ".csv")
  compare_path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(USUBJID = c("S1", "S2"), AGE = c(30, 40)),
    base_path, row.names = FALSE
  )
  utils::write.csv(
    data.frame(USUBJID = c("S1", "S2"), AGE = c(30, 41)),
    compare_path, row.names = FALSE
  )

  app <- shinytest2::AppDriver$new(
    test_path("apps", "compare"),
    name = "compare",
    height = 800, width = 1200,
    load_timeout = 30 * 1000
  )
  withr::defer(app$stop())

  app$upload_file(`compare-base_file` = base_path)
  app$upload_file(`compare-compare_file` = compare_path)
  app$click("compare-run")

  # DT renders in the browser, so wait for the diff row to reach the DOM.
  app$wait_for_js(
    "(document.querySelector('#compare-diff_table tbody') ||
       {innerText: ''}).innerText.includes('value_difference')",
    timeout = 15 * 1000
  )
  table_text <- app$get_text("#compare-diff_table tbody")
  expect_match(table_text, "value_difference")
  expect_match(table_text, "AGE")
  expect_match(app$get_text("#compare-status"), "1 issue(s) found.",
               fixed = TRUE)
})

test_that("compare module works with the shipped sample datasets", {
  skip_on_cran()
  skip_if_not_installed("shinytest2")
  skip_if(
    is.null(tryCatch(chromote::find_chrome(), error = function(e) NULL)),
    "No Chrome/Chromium available for shinytest2"
  )

  base_path <- app_sys("extdata", "sample-data", "adsl_sample.xpt")
  compare_path <- app_sys("extdata", "sample-data", "adsl_sample_v2.xpt")
  skip_if(!nzchar(base_path) || !nzchar(compare_path), "Sample data not available")

  app <- shinytest2::AppDriver$new(
    test_path("apps", "compare"),
    name = "compare-sample",
    height = 800, width = 1200,
    load_timeout = 30 * 1000
  )
  withr::defer(app$stop())

  app$upload_file(`compare-base_file` = base_path)
  app$upload_file(`compare-compare_file` = compare_path)
  app$click("compare-run")

  app$wait_for_js(
    "(document.querySelector('#compare-diff_table tbody') ||
       {innerText: ''}).innerText.includes('type_mismatch')",
    timeout = 15 * 1000
  )
  table_text <- app$get_text("#compare-diff_table tbody")
  for (issue in c("value_difference", "column_only_in_base",
                  "column_only_in_compare", "type_mismatch", "row_count")) {
    expect_match(table_text, issue)
  }
  expect_match(table_text, "HEIGHTBL")
  expect_match(table_text, "RANDFL")
})
