test_that("report module offers an enabled download that yields an HTML report", {
  skip_on_cran()
  skip_if_not_installed("shinytest2")
  skip_if(
    is.null(tryCatch(chromote::find_chrome(), error = function(e) NULL)),
    "No Chrome/Chromium available for shinytest2"
  )

  app <- shinytest2::AppDriver$new(
    test_path("apps", "report"),
    name = "report",
    height = 800, width = 1200,
    load_timeout = 30 * 1000
  )
  withr::defer(app$stop())

  expect_equal(app$get_js("document.querySelectorAll('#report-download').length"), 1)
  expect_false(app$get_js("document.querySelector('#report-download').disabled === true"))
  expect_false(app$get_js(
    "document.querySelector('#report-download').classList.contains('disabled')"
  ))

  # Exercise the handler end to end when Quarto is installed.
  if (quarto_available()) {
    path <- app$get_download("report-download")
    expect_gt(file.size(path), 0)
    expect_match(
      paste(readLines(path, warn = FALSE), collapse = "\n"),
      "adam-review report",
      fixed = TRUE
    )
  }
})
