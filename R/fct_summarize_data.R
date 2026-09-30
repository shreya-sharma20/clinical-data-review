#' Is each value of a vector missing?
#'
#' `NA` is missing everywhere. Character variables also treat the empty string
#' as missing, following the ADaM / SAS transport convention.
#'
#' @param x A vector.
#' @return A logical vector the same length as `x`.
#' @noRd
is_missing <- function(x) {
  missing <- is.na(x)
  if (is.character(x)) {
    missing <- missing | x == ""
  }
  missing
}

#' Overview of a dataset's size and completeness
#'
#' @param data A data frame.
#' @return A list with `n_rows`, `n_cols` and `pct_missing` (the percentage of
#'   all cells that are missing, `0` for a dataset without cells).
#' @noRd
dataset_overview <- function(data) {
  stopifnot(is.data.frame(data))
  cells <- nrow(data) * ncol(data)
  n_missing <- sum(vapply(data, function(x) sum(is_missing(x)), numeric(1)))
  list(
    n_rows = nrow(data),
    n_cols = ncol(data),
    pct_missing = if (cells == 0) 0 else 100 * n_missing / cells
  )
}

#' One-line description of a dataset overview
#'
#' @param overview A list as returned by `dataset_overview()`.
#' @return A single string, e.g. `"60 rows | 16 columns | 2.3% of cells missing"`.
#' @noRd
overview_text <- function(overview) {
  sprintf(
    "%s %s | %s %s | %.1f%% of cells missing",
    format(overview$n_rows, big.mark = ","),
    if (overview$n_rows == 1L) "row" else "rows",
    format(overview$n_cols, big.mark = ","),
    if (overview$n_cols == 1L) "column" else "columns",
    overview$pct_missing
  )
}

#' Summarise a dataset, one table per kind of variable
#'
#' Each variable is summarised in the table for its type, so no table has
#' columns that do not apply to it:
#'
#' * `numeric`: `variable`, `n`, `missing`, `mean`, `sd`, `median`, `min`,
#'   `max`;
#' * `categorical` (character, factor, logical and any other type):
#'   `variable`, `n`, `missing`, `distinct`, `top_value`, `top_n`, `top_pct`;
#' * `date` (dates and date-times): `variable`, `n`, `missing`, `earliest`,
#'   `latest`.
#'
#' `n` is the number of non-missing values and `missing` the number of missing
#' ones (see `is_missing()`), so `n + missing` is the number of rows.
#' `top_pct` is the percentage of the non-missing values that are the most
#' frequent value; ties are broken by first appearance.
#'
#' @param data A data frame.
#'
#' @return A named list holding only the tables that apply to `data`, in the
#'   order `numeric`, `categorical`, `date`. It is empty for a data frame
#'   without columns.
#' @noRd
summarize_data <- function(data) {
  stopifnot(is.data.frame(data))

  types <- vapply(data, variable_type, character(1), USE.NAMES = FALSE)
  tables <- list(
    numeric = list(types = "numeric", build = summarize_numeric),
    categorical = list(
      types = c("character", "factor", "logical", "other"),
      build = summarize_categorical
    ),
    date = list(types = c("date", "datetime"), build = summarize_dates)
  )

  out <- lapply(tables, function(table) {
    columns <- data[types %in% table$types]
    if (ncol(columns) > 0L) table$build(columns)
  })
  Filter(Negate(is.null), out)
}

#' Summarise numeric variables
#' @param data A data frame whose columns are all numeric.
#' @return A data frame (see `summarize_data()`).
#' @noRd
summarize_numeric <- function(data) {
  rows <- Map(function(name, x) {
    present <- as.numeric(x[!is_missing(x)])
    has_values <- length(present) > 0L
    data.frame(
      variable = name,
      n = length(present),
      missing = length(x) - length(present),
      mean = if (has_values) mean(present) else NA_real_,
      sd = if (length(present) > 1L) stats::sd(present) else NA_real_,
      median = if (has_values) stats::median(present) else NA_real_,
      min = if (has_values) min(present) else NA_real_,
      max = if (has_values) max(present) else NA_real_,
      stringsAsFactors = FALSE
    )
  }, names(data), data)
  dplyr::bind_rows(rows)
}

#' Summarise categorical variables
#' @param data A data frame of character, factor, logical or other columns.
#' @return A data frame (see `summarize_data()`).
#' @noRd
summarize_categorical <- function(data) {
  rows <- Map(function(name, x) {
    present <- as.character(x[!is_missing(x)])
    top <- most_frequent(present)
    data.frame(
      variable = name,
      n = length(present),
      missing = length(x) - length(present),
      distinct = length(unique(present)),
      top_value = top$value,
      top_n = top$n,
      top_pct = if (length(present) > 0L) 100 * top$n / length(present) else NA_real_,
      stringsAsFactors = FALSE
    )
  }, names(data), data)
  dplyr::bind_rows(rows)
}

#' Summarise date and date-time variables
#' @param data A data frame of Date or POSIXt columns.
#' @return A data frame (see `summarize_data()`). `earliest` and `latest` are
#'   formatted as text, because dates and date-times cannot share a column.
#' @noRd
summarize_dates <- function(data) {
  rows <- Map(function(name, x) {
    present <- x[!is_missing(x)]
    has_values <- length(present) > 0L
    data.frame(
      variable = name,
      n = length(present),
      missing = length(x) - length(present),
      earliest = if (has_values) format(min(present)) else NA_character_,
      latest = if (has_values) format(max(present)) else NA_character_,
      stringsAsFactors = FALSE
    )
  }, names(data), data)
  dplyr::bind_rows(rows)
}

#' Most frequent value of a character vector
#'
#' Ties are broken by first appearance.
#'
#' @param x A character vector without missing values (may be empty).
#' @return A list with `value` (`NA_character_` for an empty `x`) and `n`
#'   (`0L` for an empty `x`).
#' @noRd
most_frequent <- function(x) {
  if (length(x) == 0L) {
    return(list(value = NA_character_, n = 0L))
  }
  counts <- table(factor(x, levels = unique(x)))
  list(value = names(counts)[which.max(counts)], n = max(as.integer(counts)))
}
