#' Summarise every variable of a dataset
#'
#' Character variables treat the empty string as missing, following the ADaM /
#' SAS transport convention. Numeric variables also get `min`, `median`,
#' `mean` and `max`; all other variables get their most frequent value in
#' `top_value`. Dates and factors are treated as categorical.
#'
#' @param data A data frame.
#'
#' @return A data frame with one row per variable and columns `variable`,
#'   `type`, `n`, `n_missing`, `n_distinct`, `min`, `median`, `mean`, `max`
#'   and `top_value`. Statistics that do not apply are `NA`.
#' @noRd
summarize_data <- function(data) {
  stopifnot(is.data.frame(data))

  cols <- c(
    "variable", "type", "n", "n_missing", "n_distinct",
    "min", "median", "mean", "max", "top_value"
  )
  if (ncol(data) == 0L) {
    return(stats::setNames(
      data.frame(
        character(), character(), integer(), integer(), integer(),
        numeric(), numeric(), numeric(), numeric(), character(),
        stringsAsFactors = FALSE
      ),
      cols
    ))
  }

  rows <- Map(summarize_variable, names(data), data)
  out <- dplyr::bind_rows(rows)
  out[, cols]
}

#' Summarise one variable
#'
#' @param name Variable name.
#' @param x The variable values.
#'
#' @return A one-row data frame (see `summarize_data()`).
#' @noRd
summarize_variable <- function(name, x) {
  type <- variable_type(x)
  missing <- is.na(x)
  if (type == "character") {
    missing <- missing | x == ""
  }
  present <- x[!missing]

  result <- data.frame(
    variable = name,
    type = type,
    n = length(present),
    n_missing = sum(missing),
    n_distinct = length(unique(present)),
    min = NA_real_,
    median = NA_real_,
    mean = NA_real_,
    max = NA_real_,
    top_value = NA_character_,
    stringsAsFactors = FALSE
  )

  if (length(present) == 0L) {
    return(result)
  }

  if (type == "numeric") {
    result$min <- min(present)
    result$median <- stats::median(present)
    result$mean <- mean(present)
    result$max <- max(present)
  } else {
    result$top_value <- most_frequent(present)
  }
  result
}

#' Most frequent value of a non-empty vector, as a string
#'
#' Ties are broken by first appearance.
#'
#' @param x A non-empty vector without missing values.
#' @noRd
most_frequent <- function(x) {
  x <- as.character(x)
  counts <- table(factor(x, levels = unique(x)))
  names(counts)[which.max(counts)]
}
