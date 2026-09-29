# REQ-09: logic lives in plain functions; app_server only wires modules.

test_that("fct_* and utils_* functions take no input, output or session", {
  # Needs the source files, which an installed package (R CMD check) lacks.
  files <- list.files(
    test_path("..", "..", "R"),
    pattern = "^(fct|utils)_.*\\.R$", full.names = TRUE
  )
  skip_if(length(files) == 0L, "Package source files not available")

  forbidden <- c("input", "output", "session")
  for (file in files) {
    env <- new.env()
    sys.source(file, envir = env)
    for (fn_name in ls(env, all.names = TRUE)) {
      fn <- get(fn_name, envir = env)
      if (is.function(fn)) {
        expect_false(
          any(forbidden %in% names(formals(fn))),
          info = paste(basename(file), fn_name)
        )
      }
    }
  }
})

test_that("app_server only calls mod_*_server() functions", {
  called <- function(expr) {
    if (is.call(expr)) {
      c(as.character(expr[[1]])[1], unlist(lapply(as.list(expr)[-1], called)))
    }
  }
  fns <- unique(called(body(app_server)))
  allowed_glue <- c("{", "<-", "(")
  calls <- setdiff(fns, allowed_glue)

  expect_gt(length(calls), 0)
  expect_true(all(grepl("^mod_.+_server$", calls)), info = toString(calls))
})
