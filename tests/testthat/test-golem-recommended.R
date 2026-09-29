# Standard golem scaffold sanity checks (see golem::use_recommended_tests()).

test_that("app ui builds a shiny tag structure", {
  ui <- app_ui()
  expect_s3_class(ui, "shiny.tag.list")
  expect_true(is.function(app_ui))
})

test_that("app server is a function of input, output and session", {
  expect_true(is.function(app_server))
  expect_named(formals(app_server), c("input", "output", "session"))
})

test_that("app_sys() finds the installed package files", {
  expect_true(nzchar(app_sys("golem-config.yml")))
})

test_that("golem config carries the R package name", {
  expect_identical(get_golem_config("golem_name"), "adamreview")
  expect_false(get_golem_config("app_prod"))
})

test_that("run_app() returns a shiny app object", {
  expect_s3_class(run_app(), "shiny.appobj")
})
