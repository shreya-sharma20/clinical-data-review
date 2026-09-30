test_that("the app is titled ADaM Dataset Explorer", {
  html <- as.character(app_ui(NULL))

  expect_match(html, "<h2>ADaM Dataset Explorer</h2>", fixed = TRUE)
  expect_no_match(html, "adam-review", fixed = TRUE)
})

test_that("the package keeps its legal R name", {
  expect_identical(utils::packageName(environment(app_ui)), "adamreview")
})
