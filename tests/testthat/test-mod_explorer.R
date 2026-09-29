test_that("explorer module renders data, variable and summary tables", {
  skip_on_cran()
  skip_if_not_installed("shinytest2")
  skip_if_not_installed("pharmaverseadam")
  skip_if(
    is.null(tryCatch(chromote::find_chrome(), error = function(e) NULL)),
    "No Chrome/Chromium available for shinytest2"
  )

  app <- shinytest2::AppDriver$new(
    test_path("apps", "explorer"),
    name = "explorer",
    height = 800, width = 1200,
    load_timeout = 30 * 1000
  )
  withr::defer(app$stop())

  # DT renders server-side, so wait for text to appear in the browser DOM.
  # `needle` guards against reading rows left over from a previous render.
  rendered_text <- function(output_id, needle) {
    selector <- sprintf("#explorer-%s tbody", output_id)
    app$wait_for_js(
      sprintf(
        "(document.querySelector('%s') || {innerText: ''}).innerText.includes('%s')",
        selector, needle
      ),
      timeout = 15 * 1000
    )
    app$get_text(selector)
  }

  app$set_inputs(`explorer-demo` = "ADAE")

  # Data tab: the filterable DT table shows ADAE rows.
  expect_match(rendered_text("data_table", "APPLICATION SITE"), "APPLICATION SITE")
  expect_gt(
    app$get_js("document.querySelectorAll('#explorer-data_table thead input').length"),
    0 # per-column filter boxes are present
  )

  # Variables tab: label/type table.
  app$set_inputs(`explorer-tabs` = "Variables")
  expect_match(
    rendered_text("meta_table", "Unique Subject Identifier"),
    "Unique Subject Identifier"
  )

  # Summary tab: per-variable summary.
  app$set_inputs(`explorer-tabs` = "Summary")
  expect_match(rendered_text("summary_table", "USUBJID"), "USUBJID")
})
