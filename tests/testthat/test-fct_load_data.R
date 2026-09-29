test_that("load_demo_data() returns data plus one metadata row per column", {
  skip_if_not_installed("pharmaverseadam")

  for (nm in c("ADSL", "ADAE")) {
    res <- load_demo_data(nm)

    expect_named(res, c("data", "meta", "name"))
    expect_s3_class(res$data, "data.frame")
    expect_gt(nrow(res$data), 0)
    expect_identical(res$name, nm)

    expect_named(res$meta, c("variable", "label", "type"))
    expect_identical(res$meta$variable, names(res$data))
    expect_type(res$meta$label, "character")
    expect_false(anyNA(res$meta$type))
  }

  adsl <- load_demo_data("adsl")
  expect_identical(adsl$name, "ADSL")
  expect_identical(adsl$meta$label[adsl$meta$variable == "AGE"], "Age")
  expect_identical(adsl$meta$type[adsl$meta$variable == "AGE"], "numeric")
})

test_that("load_demo_data() errors clearly for an unknown dataset", {
  expect_error(load_demo_data("ADXX"), "Unknown demo dataset 'ADXX'")
  expect_error(load_demo_data("ADXX"), "ADSL, ADAE")
  expect_error(load_demo_data(NA_character_), "Unknown demo dataset")
  expect_error(load_demo_data(c("ADSL", "ADAE")), "Unknown demo dataset")
})

test_that("read_uploaded_data() reads a CSV file", {
  path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(USUBJID = c("S-01", "S-02"), AGE = c(34, 51)),
    path, row.names = FALSE
  )

  res <- read_uploaded_data(path)

  expect_named(res, c("data", "meta", "name"))
  expect_identical(nrow(res$data), 2L)
  expect_identical(names(res$data), c("USUBJID", "AGE"))
  expect_identical(res$meta$type, c("character", "numeric"))
  expect_identical(res$meta$label, c("", ""))
})

test_that("read_uploaded_data() reads an XPT file and keeps variable labels", {
  path <- withr::local_tempfile(fileext = ".xpt")
  df <- data.frame(USUBJID = c("01", "02"), AGE = c(34, 51))
  attr(df$USUBJID, "label") <- "Unique Subject Identifier"
  attr(df$AGE, "label") <- "Age"
  haven::write_xpt(df, path)

  res <- read_uploaded_data(path)

  expect_identical(nrow(res$data), 2L)
  expect_identical(
    res$meta$label,
    c("Unique Subject Identifier", "Age")
  )
  expect_identical(res$meta$type, c("character", "numeric"))
})

test_that("read_uploaded_data() uses the original filename for format and name", {
  path <- withr::local_tempfile(fileext = ".tmp")
  utils::write.csv(data.frame(A = 1:3), path, row.names = FALSE)

  res <- read_uploaded_data(path, filename = "adsl_copy.CSV")

  expect_identical(res$name, "adsl_copy")
  expect_identical(nrow(res$data), 3L)
})

test_that("read_uploaded_data() errors for a missing file", {
  expect_error(
    read_uploaded_data(file.path(tempdir(), "does-not-exist.csv")),
    "File not found"
  )
  expect_error(read_uploaded_data(NA_character_), "File not found")
})

test_that("read_uploaded_data() errors for an unsupported extension", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines("a,b", path)

  expect_error(read_uploaded_data(path), "Unsupported file type '.txt'")
  expect_error(read_uploaded_data(path), "\\.xpt or \\.csv")
})

test_that("read_uploaded_data() errors clearly for a corrupt XPT file", {
  path <- withr::local_tempfile(fileext = ".xpt")
  writeLines("this is not a transport file", path)

  expect_error(read_uploaded_data(path), "Could not read '.*\\.xpt' as XPT")
})

test_that("variable_type() classifies common column types", {
  expect_identical(variable_type(1.5), "numeric")
  expect_identical(variable_type(1L), "numeric")
  expect_identical(variable_type("a"), "character")
  expect_identical(variable_type(factor("a")), "factor")
  expect_identical(variable_type(TRUE), "logical")
  expect_identical(variable_type(Sys.Date()), "date")
  expect_identical(variable_type(Sys.time()), "datetime")
  expect_identical(variable_type(list(1)), "other")
})
