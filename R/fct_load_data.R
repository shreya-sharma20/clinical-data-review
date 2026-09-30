#' Demo dataset names available in the Explorer
#'
#' @return A character vector of supported demo dataset names.
#' @noRd
demo_dataset_names <- function() {
  c("ADSL", "ADAE")
}

#' Load a demo ADaM dataset from pharmaverseadam
#'
#' @param name One of `demo_dataset_names()` (case-insensitive).
#'
#' @return A list with elements `data` (a data frame), `meta` (a data frame
#'   with one row per variable: `variable`, `label`, `type`) and `name`.
#' @noRd
load_demo_data <- function(name) {
  if (!is.character(name) || length(name) != 1L || is.na(name) ||
        !toupper(name) %in% demo_dataset_names()) {
    stop(
      "Unknown demo dataset '", paste(name, collapse = ", "), "'. ",
      "Choose one of: ", paste(demo_dataset_names(), collapse = ", "), ".",
      call. = FALSE
    )
  }
  if (!requireNamespace("pharmaverseadam", quietly = TRUE)) {
    stop(
      "Package 'pharmaverseadam' is required to load demo datasets.",
      call. = FALSE
    )
  }

  name <- toupper(name)
  data <- as.data.frame(
    getExportedValue("pharmaverseadam", tolower(name))
  )
  new_dataset(data, name)
}

#' Read an uploaded XPT or CSV file
#'
#' The format is chosen from the extension of `filename`, not of `path`,
#' because Shiny stores uploads under a temporary name.
#'
#' @param path Path to the file on disk.
#' @param filename Original file name, used to detect the format and to name
#'   the dataset. Defaults to `basename(path)`.
#'
#' @return A list with elements `data`, `meta` and `name`, as in
#'   `load_demo_data()`.
#' @noRd
read_uploaded_data <- function(path, filename = basename(path)) {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
        !file.exists(path)) {
    stop("File not found: ", paste(path, collapse = ", "), call. = FALSE)
  }

  ext <- tolower(tools::file_ext(filename))
  reader <- switch(
    ext,
    xpt = function(p) haven::read_xpt(p),
    csv = function(p) parse_iso_dates(
      utils::read.csv(p, stringsAsFactors = FALSE, check.names = FALSE)
    ),
    stop(
      "Unsupported file type '.", ext, "' for '", filename,
      "'. Please upload an .xpt or .csv file.",
      call. = FALSE
    )
  )

  data <- tryCatch(
    as.data.frame(reader(path)),
    error = function(e) {
      stop(
        "Could not read '", filename, "' as ", toupper(ext), ": ",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
  new_dataset(data, tools::file_path_sans_ext(filename))
}

#' Convert ISO 8601 date columns of a CSV import to `Date`
#'
#' CSV files have no date type, so dates arrive as text. A character column is
#' converted when every non-empty value is a valid `YYYY-MM-DD` date; empty
#' strings become `NA`. Any other column is left untouched.
#'
#' @param data A data frame.
#' @return `data`, with the qualifying columns converted to `Date`.
#' @noRd
parse_iso_dates <- function(data) {
  data[] <- lapply(data, function(x) {
    if (!is.character(x)) {
      return(x)
    }
    present <- !is.na(x) & x != ""
    if (!any(present) || !all(grepl("^\\d{4}-\\d{2}-\\d{2}$", x[present]))) {
      return(x)
    }
    parsed <- as.Date(x, format = "%Y-%m-%d")
    if (anyNA(parsed[present])) x else parsed
  })
  data
}

#' Build the per-variable label/type metadata table
#'
#' @param data A data frame.
#'
#' @return A data frame with columns `variable`, `label` (empty string when
#'   the variable has no label) and `type`.
#' @noRd
variable_metadata <- function(data) {
  stopifnot(is.data.frame(data))
  labels <- vapply(
    data,
    function(x) {
      lab <- attr(x, "label", exact = TRUE)
      if (is.character(lab) && length(lab) == 1L && !is.na(lab)) lab else ""
    },
    character(1)
  )
  data.frame(
    variable = names(data),
    label = unname(labels),
    type = vapply(data, variable_type, character(1), USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
}

#' Classify a variable into a small set of display types
#'
#' @param x A vector.
#'
#' @return One of `"numeric"`, `"character"`, `"factor"`, `"logical"`,
#'   `"date"`, `"datetime"` or `"other"`.
#' @noRd
variable_type <- function(x) {
  if (inherits(x, "POSIXt")) {
    "datetime"
  } else if (inherits(x, "Date")) {
    "date"
  } else if (is.factor(x)) {
    "factor"
  } else if (is.numeric(x)) {
    "numeric"
  } else if (is.character(x)) {
    "character"
  } else if (is.logical(x)) {
    "logical"
  } else {
    "other"
  }
}

#' Bundle data with its metadata
#' @noRd
new_dataset <- function(data, name) {
  list(data = data, meta = variable_metadata(data), name = name)
}
