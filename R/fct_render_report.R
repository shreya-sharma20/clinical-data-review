#' Locate the report template shipped with the package
#'
#' @return Path to `report.qmd`.
#' @noRd
report_template_path <- function() {
  path <- app_sys("report/report.qmd")
  if (!nzchar(path)) stop("Report template not found.", call. = FALSE)
  path
}

#' Is the Quarto CLI available?
#'
#' @return `TRUE` when the `quarto` R package can find a Quarto CLI.
#' @noRd
quarto_available <- function() {
  requireNamespace("quarto", quietly = TRUE) &&
    !is.null(quarto::quarto_path())
}

#' Assemble the report parameters
#'
#' Combines the Explorer summary and the Compare result into the plain list
#' the Quarto template reads. Either input may be `NULL` (nothing loaded or no
#' comparison run yet); the report then says so.
#'
#' @param dataset The Explorer dataset (a list with `data`, `meta` and `name`,
#'   as returned by `load_demo_data()`), or `NULL`.
#' @param comparison The Compare result (as returned by `compare_datasets()`),
#'   or `NULL`.
#'
#' @return A list with elements `generated`, `explorer` and `compare`.
#'   `explorer` is `NULL` or a list with `name`, `n_rows`, `n_cols` and
#'   `summary` (the per-variable summary with variable labels added).
#'   `compare` is `NULL` or the comparison list.
#' @noRd
build_report_params <- function(dataset = NULL, comparison = NULL) {
  explorer <- NULL
  if (!is.null(dataset)) {
    stopifnot(is.data.frame(dataset$data))
    summary <- summarize_data(dataset$data)
    labels <- variable_metadata(dataset$data)[, c("variable", "label")]
    explorer <- list(
      name = dataset$name,
      n_rows = nrow(dataset$data),
      n_cols = ncol(dataset$data),
      summary = merge_labels(summary, labels)
    )
  }
  if (!is.null(comparison)) {
    stopifnot(is.data.frame(comparison$table))
  }
  list(
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    explorer = explorer,
    compare = comparison
  )
}

#' Add a `label` column to the summary, keeping the summary's row order
#' @noRd
merge_labels <- function(summary, labels) {
  summary$label <- labels$label[match(summary$variable, labels$variable)]
  summary[, c("variable", "label", setdiff(names(summary), c("variable",
                                                             "label")))]
}

#' Render the parameterized Quarto report to a self-contained HTML file
#'
#' The template is copied to a scratch directory and rendered there, so the
#' installed package is never written to. The report parameters (which contain
#' data frames and so cannot be passed as plain Quarto YAML parameters) are
#' saved as an RDS file whose path is passed as the `data_file` parameter.
#'
#' @inheritParams build_report_params
#' @param output_file Where to write the HTML report.
#'
#' @return `output_file`, invisibly.
#' @noRd
render_report <- function(dataset = NULL, comparison = NULL, output_file) {
  if (!is.character(output_file) || length(output_file) != 1L ||
        is.na(output_file) || !nzchar(output_file)) {
    stop("`output_file` must be a single file path.", call. = FALSE)
  }
  if (!quarto_available()) {
    stop(
      "The Quarto CLI is required to render the report but was not found. ",
      "Install it from https://quarto.org/docs/get-started/.",
      call. = FALSE
    )
  }

  params <- build_report_params(dataset, comparison)

  work_dir <- tempfile("adamreview-report-")
  dir.create(work_dir)
  on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

  data_file <- file.path(work_dir, "report-params.rds")
  saveRDS(params, data_file)
  input <- file.path(work_dir, "report.qmd")
  file.copy(report_template_path(), input)

  tryCatch(
    quarto::quarto_render(
      input,
      output_format = "html",
      execute_params = list(data_file = data_file),
      quiet = TRUE
    ),
    error = function(e) {
      stop("Rendering the report failed: ", conditionMessage(e),
           call. = FALSE)
    }
  )

  html <- file.path(work_dir, "report.html")
  if (!file.exists(html) || file.size(html) == 0L) {
    stop("Rendering the report did not produce an HTML file.", call. = FALSE)
  }
  if (!file.copy(html, output_file, overwrite = TRUE)) {
    stop("Could not write the report to '", output_file, "'.", call. = FALSE)
  }
  invisible(output_file)
}
