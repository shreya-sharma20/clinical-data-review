test_that("explorer module shows the data preview, variable pop-up, summary tables and charts", {
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
    height = 900, width = 1300,
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
  # Number of elements matching a CSS selector.
  count <- function(selector) {
    app$get_js(sprintf("document.querySelectorAll('%s').length", selector))
  }
  wait_for_count <- function(selector) {
    app$wait_for_js(
      sprintf("document.querySelectorAll('%s').length > 0", selector),
      timeout = 15 * 1000
    )
  }

  app$set_inputs(`explorer-demo` = "ADAE")

  # Data tab (shown first): heading, one-line overview and filterable table.
  expect_match(rendered_text("data_table", "APPLICATION SITE"), "APPLICATION SITE")
  expect_match(app$get_text("#explorer-tabs + .tab-content h4"), "Data Preview")
  app$wait_for_js(
    "document.getElementById('explorer-overview').innerText.includes('rows')",
    timeout = 15 * 1000
  )
  expect_match(app$get_text("#explorer-overview"), "columns \\| [0-9.]+% of cells missing")
  expect_gt(count("#explorer-data_table thead input"), 0) # per-column filter boxes

  # The (i) button opens the variable summary pop-up.
  app$click("explorer-info")
  expect_match(
    rendered_text("meta_table", "Unique Subject Identifier"),
    "Unique Subject Identifier"
  )
  expect_match(app$get_text(".modal-title"), "ADAE")
  app$click(selector = ".modal-footer button")
  app$wait_for_js("document.querySelectorAll('.modal.show').length === 0",
                  timeout = 15 * 1000)

  # Summary tab: one table per variable type, each with its own columns.
  app$set_inputs(`explorer-tabs` = "Summary")
  expect_match(rendered_text("summary_numeric", "AGE"), "AGE")
  expect_match(rendered_text("summary_categorical", "USUBJID"), "USUBJID")
  expect_match(rendered_text("summary_date", "TRTSDT"), "TRTSDT")
  headings <- app$get_text("#explorer-summary_tables")
  expect_match(headings, "Numeric variables")
  expect_match(headings, "Categorical variables")
  expect_match(headings, "Date variables")
  expect_match(app$get_text("#explorer-summary_numeric thead"), "median")
  expect_no_match(app$get_text("#explorer-summary_numeric thead"), "top_value")

  # Charts tab: the pickers follow the loaded dataset and all four plots render.
  app$set_inputs(`explorer-tabs` = "Charts")
  # AESEV only exists in ADAE, so the picker reflects the loaded dataset;
  # AEDECOD has too many distinct values to be offered.
  app$wait_for_js(
    "!!document.getElementById('explorer-pie_var').selectize.options.AESEV",
    timeout = 15 * 1000
  )
  expect_false(app$get_js(
    "!!document.getElementById('explorer-pie_var').selectize.options.AEDECOD"
  ))
  wait_for_count("#explorer-missing_chart.js-plotly-plot .trace.bars")
  wait_for_count("#explorer-pie_chart.js-plotly-plot .pielayer .slice")
  wait_for_count("#explorer-hist_chart.js-plotly-plot .trace.bars")
  wait_for_count("#explorer-box_chart.js-plotly-plot .trace.boxes")

  app$set_inputs(`explorer-hist_var` = "AGE", `explorer-hist_group` = "SEX")
  app$wait_for_js(
    "(document.querySelector('#explorer-hist_chart .xtitle') || {textContent: ''}).textContent.includes('AGE')",
    timeout = 15 * 1000
  )
  expect_gt(count("#explorer-hist_chart .legend .traces"), 1) # one legend entry per group

  # An uploaded CSV replaces the demo dataset everywhere. CSV files carry no
  # variable labels, but their ISO dates are recognised as dates.
  csv_path <- app_sys("extdata", "sample-data", "adsl_sample.csv")
  skip_if(!nzchar(csv_path), "Sample data not available")
  app$set_inputs(`explorer-source` = "upload")
  app$upload_file(`explorer-file` = csv_path)
  app$set_inputs(`explorer-tabs` = "Data")
  app$wait_for_js(
    "document.getElementById('explorer-overview').innerText.startsWith('60 rows')",
    timeout = 15 * 1000
  )
  expect_match(rendered_text("data_table", "ADAMDEMO01"), "ADAMDEMO01")
  app$click("explorer-info")
  expect_match(rendered_text("meta_table", "USUBJID"), "USUBJID")
  expect_match(app$get_text(".modal-body"), "no variable labels")
  app$click(selector = ".modal-footer button")
  app$wait_for_js("document.querySelectorAll('.modal.show').length === 0",
                  timeout = 15 * 1000)
  app$set_inputs(`explorer-tabs` = "Summary")
  expect_match(rendered_text("summary_date", "TRTSDT"), "TRTSDT")
})
