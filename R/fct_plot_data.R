# Chart data preparation and plotly builders for the Explorer "Charts" tab.
#
# Four fixed charts make sense for any ADaM dataset:
#   * `plot_missing()`      missing values by variable (bar)
#   * `plot_composition()`  categorical composition (donut)
#   * `plot_histogram()`    numeric distribution, optionally split by group
#   * `plot_boxplot()`      numeric variable by category (box plot)
# Each returns a plotly object. When there is nothing to draw the object is an
# empty plot carrying an explanatory message, never an error. A `NULL` or
# empty variable means "no variable is available" (the picker has no choices);
# a variable that is not a column of the data is a programming error.

#' Maximum number of groups drawn as separate traces
#'
#' Groups beyond this many (ranked by frequency) are pooled into "Other". Also
#' the maximum number of slices in the composition chart.
#' @noRd
max_chart_groups <- function() 8L

#' Maximum number of bars in the missing-values chart
#'
#' Only the variables with the most missing values are kept, so that
#' wide datasets do not produce an unreadable chart.
#' @noRd
max_chart_categories <- function() 20L

#' Maximum number of distinct values of a "low-cardinality" variable
#'
#' Only such variables are offered for the composition chart, for grouping
#' histograms and as the category of the box plot. Identifiers such as
#' `USUBJID` are therefore not offered.
#' @noRd
max_low_cardinality <- function() 15L

#' List the variables offered in the chart pickers
#'
#' @param data A data frame.
#' @param meta Variable metadata as returned by `variable_metadata()` (columns
#'   `variable`, `label` and `type`); computed from `data` by default.
#'
#' @return A list with two named character vectors, `numeric` and
#'   `categorical`. `numeric` holds numeric variables with at least one finite
#'   value; `categorical` holds character, factor and logical variables with
#'   between one and `max_low_cardinality()` distinct non-missing values, in
#'   dataset order except that constant variables (one value) come last, so
#'   that the first choice makes a useful default. Each vector holds variable
#'   names and is named by a display string (`"VAR - label"`, or just `"VAR"`
#'   without a label), so it can be passed directly to `selectInput()`.
#' @noRd
chart_choices <- function(data, meta = variable_metadata(data)) {
  stopifnot(
    is.data.frame(data),
    is.data.frame(meta), all(c("variable", "label", "type") %in% names(meta))
  )

  display <- ifelse(
    nzchar(meta$label), paste0(meta$variable, " - ", meta$label), meta$variable
  )
  choices <- function(rows) stats::setNames(meta$variable[rows], display[rows])

  numeric_rows <- which(vapply(seq_len(nrow(meta)), function(i) {
    meta$type[i] == "numeric" && any(is.finite(as.numeric(data[[meta$variable[i]]])))
  }, logical(1)))

  n_levels <- vapply(seq_len(nrow(meta)), function(i) {
    x <- data[[meta$variable[i]]]
    if (meta$type[i] %in% c("character", "factor", "logical")) {
      length(unique(x[!is_missing(x)]))
    } else {
      NA_integer_
    }
  }, integer(1))
  categorical_rows <- which(n_levels >= 1L & n_levels <= max_low_cardinality())
  categorical_rows <- categorical_rows[order(n_levels[categorical_rows] < 2L)]

  list(numeric = choices(numeric_rows), categorical = choices(categorical_rows))
}

# Chart 1: missing values by variable -------------------------------------------

#' Bar chart of the percentage of missing values in each variable
#'
#' Only variables with at least one missing value are drawn, the most
#' incomplete first, up to `max_chart_categories()` bars. Missing follows
#' `is_missing()` (so `""` counts as missing for character variables).
#'
#' @param data A data frame.
#' @return A plotly object.
#' @noRd
plot_missing <- function(data) {
  stopifnot(is.data.frame(data))
  title <- "Missing values by variable"
  x_title <- "% of rows missing"
  if (nrow(data) == 0L || ncol(data) == 0L) {
    return(message_plot("No data to chart", title))
  }

  n_missing <- vapply(data, function(x) sum(is_missing(x)), numeric(1))
  incomplete <- which(n_missing > 0)
  if (length(incomplete) == 0L) {
    return(message_plot("No missing values in any variable", title))
  }

  ranked <- incomplete[order(n_missing[incomplete], decreasing = TRUE)]
  shown <- utils::head(ranked, max_chart_categories())
  variables <- names(data)[shown]
  if (length(ranked) > length(shown)) {
    x_title <- sprintf("%s (top %d of %d variables with missing values)",
                       x_title, length(shown), length(ranked))
  }

  p <- plotly::plot_ly(
    x = 100 * n_missing[shown] / nrow(data), y = variables,
    type = "bar", orientation = "h",
    text = sprintf("%s: %s of %s missing", variables,
                   format(n_missing[shown], big.mark = ","),
                   format(nrow(data), big.mark = ",")),
    hoverinfo = "text", textposition = "none"
  )
  plotly::layout(
    p,
    xaxis = list(title = x_title, range = c(0, 100)),
    # categoryarray runs bottom to top, so reverse it to put the worst on top;
    # dtick = 1 labels every bar
    yaxis = list(title = "", categoryorder = "array",
                 categoryarray = rev(variables), dtick = 1)
  )
}

# Chart 2: categorical composition ---------------------------------------------

#' Donut chart of the composition of a categorical variable
#'
#' The `max_chart_groups()` most frequent categories get a slice each and the
#' rest are pooled into "Other". Missing values are not drawn (see
#' `plot_missing()`).
#'
#' @param data A data frame.
#' @param variable Name of a character, factor or logical variable.
#' @return A plotly object.
#' @noRd
plot_composition <- function(data, variable) {
  stopifnot(is.data.frame(data))
  if (no_variable(variable)) {
    return(message_plot("No suitable categorical variables to chart"))
  }
  check_column(data, variable, "Variable")
  x <- data[[variable]]
  if (!variable_type(x) %in% c("character", "factor", "logical")) {
    stop("Variable '", variable, "' is not categorical.", call. = FALSE)
  }

  present <- as.character(x[!is_missing(x)])
  if (length(present) == 0L) {
    return(message_plot("No non-missing values to plot", axis_title(data, variable)))
  }

  counts <- sort(table(present), decreasing = TRUE)
  labels <- names(counts)
  values <- as.integer(counts)
  if (length(counts) > max_chart_groups()) {
    top <- seq_len(max_chart_groups())
    labels <- c(labels[top], "Other")
    values <- c(values[top], sum(values[-top]))
  }

  plotly::layout(
    plotly::plot_ly(
      labels = labels, values = values, type = "pie", hole = 0.45,
      sort = FALSE, direction = "clockwise", textinfo = "percent"
    ),
    title = axis_title(data, variable),
    legend = list(title = list(text = "Category"))
  )
}

# Chart 3: numeric distribution -------------------------------------------------

#' Histogram of a numeric variable, optionally split by group
#'
#' Non-finite values are dropped. Groups are stacked and share the same bins.
#'
#' @param data A data frame.
#' @param variable Name of a numeric variable.
#' @param group Optional name of a grouping variable, or `NULL` / `""` for no
#'   grouping. Missing group values form a "(Missing)" group, and groups
#'   beyond `max_chart_groups()` are pooled into "Other". Ignored when it equals
#'   `variable`.
#' @return A plotly object.
#' @noRd
plot_histogram <- function(data, variable, group = NULL) {
  stopifnot(is.data.frame(data))
  if (no_variable(variable)) {
    return(message_plot("No numeric variables to chart"))
  }
  check_numeric_column(data, variable)
  group <- normalize_group(data, group, variable)

  x <- data[[variable]]
  keep <- is.finite(x)
  if (!any(keep)) {
    return(message_plot("No non-missing values to plot", axis_title(data, variable)))
  }
  groups <- group_values(data, group)[keep]
  x <- as.numeric(x[keep])

  # Shared bins keep the groups comparable and let them stack cleanly.
  breaks <- pretty(range(x), n = 15)
  bins <- list(
    start = breaks[1], end = breaks[length(breaks)], size = breaks[2] - breaks[1]
  )

  p <- plotly::plot_ly()
  for (g in ordered_groups(groups)) {
    p <- plotly::add_trace(
      p,
      x = x[groups == g], type = "histogram", name = g, xbins = bins,
      showlegend = !is.null(group)
    )
  }
  plotly::layout(
    p,
    barmode = "stack",
    xaxis = list(title = axis_title(data, variable)),
    yaxis = list(title = "Count"),
    legend = legend_layout(data, group)
  )
}

# Chart 4: numeric by category --------------------------------------------------

#' Box plot of a numeric variable for each category of another variable
#'
#' Non-finite values are dropped. Missing categories form a "(Missing)" box
#' and categories beyond `max_chart_groups()` are pooled into "Other".
#'
#' @param data A data frame.
#' @param variable Name of a numeric variable.
#' @param category Name of the variable that defines the boxes.
#' @return A plotly object.
#' @noRd
plot_boxplot <- function(data, variable, category) {
  stopifnot(is.data.frame(data))
  if (no_variable(variable)) {
    return(message_plot("No numeric variables to chart"))
  }
  if (no_variable(category)) {
    return(message_plot("No suitable categorical variables to group by"))
  }
  check_numeric_column(data, variable)
  check_column(data, category, "Category variable")

  x <- data[[variable]]
  keep <- is.finite(x)
  if (!any(keep)) {
    return(message_plot("No non-missing values to plot", axis_title(data, variable)))
  }
  groups <- group_values(data, category)[keep]
  x <- as.numeric(x[keep])

  p <- plotly::plot_ly()
  for (g in ordered_groups(groups)) {
    p <- plotly::add_trace(
      p, y = x[groups == g], type = "box", name = g, showlegend = FALSE
    )
  }
  plotly::layout(
    p,
    xaxis = list(title = axis_title(data, category)),
    yaxis = list(title = axis_title(data, variable))
  )
}

# Helpers -----------------------------------------------------------------------

#' Group labels for each row
#'
#' Returns a single group for every row when `group` is `NULL`. Otherwise
#' missing (and empty-string) values become "(Missing)", and all but the
#' `max_chart_groups()` most frequent groups are pooled into "Other".
#'
#' @param data A data frame.
#' @param group `NULL` or a column name.
#' @return A character vector with one element per row of `data`.
#' @noRd
group_values <- function(data, group = NULL) {
  if (is.null(group)) {
    return(rep("All", nrow(data)))
  }
  g <- as.character(data[[group]])
  g[is_missing(data[[group]])] <- "(Missing)"

  counts <- sort(table(g), decreasing = TRUE)
  if (length(counts) > max_chart_groups()) {
    top <- names(counts)[seq_len(max_chart_groups())]
    g[!g %in% top] <- "Other"
  }
  g
}

#' Group names, most frequent first
#' @noRd
ordered_groups <- function(groups) {
  names(sort(table(groups), decreasing = TRUE))
}

#' Validate an optional grouping variable
#'
#' @return `NULL` when there is no grouping (`NULL`, `""` or the same variable
#'   as `variable`), otherwise `group`. Errors for an unknown column.
#' @noRd
normalize_group <- function(data, group, variable) {
  if (no_variable(group)) {
    return(NULL)
  }
  check_column(data, group, "Group variable")
  if (identical(group, variable)) NULL else group
}

#' Was no variable given (`NULL` or the empty string)?
#' @noRd
no_variable <- function(variable) {
  is.null(variable) || identical(variable, "")
}

#' Axis title for a variable: its label plus name, or just the name
#' @noRd
axis_title <- function(data, variable) {
  label <- attr(data[[variable]], "label", exact = TRUE)
  if (is.character(label) && length(label) == 1L && !is.na(label) && nzchar(label)) {
    paste0(label, " (", variable, ")")
  } else {
    variable
  }
}

#' Legend title layout, using the group variable's label
#' @noRd
legend_layout <- function(data, group) {
  if (is.null(group)) {
    return(list())
  }
  list(title = list(text = axis_title(data, group)))
}

#' An empty plotly chart that shows a message instead of data
#' @noRd
message_plot <- function(message, title = NULL) {
  plotly::layout(
    plotly::plot_ly(
      x = numeric(), y = numeric(), type = "scatter", mode = "markers"
    ),
    title = title,
    xaxis = list(visible = FALSE),
    yaxis = list(visible = FALSE),
    annotations = list(
      text = message, x = 0.5, y = 0.5, xref = "paper", yref = "paper",
      showarrow = FALSE, font = list(size = 14)
    )
  )
}

#' Stop with a clear message unless `name` is a column of `data`
#' @noRd
check_column <- function(data, name, what) {
  if (!is.character(name) || length(name) != 1L || is.na(name) ||
        !name %in% names(data)) {
    stop(
      what, " '", paste(name, collapse = ", "), "' is not a column of the data.",
      call. = FALSE
    )
  }
  invisible(name)
}

#' Stop with a clear message unless `name` is a numeric column of `data`
#' @noRd
check_numeric_column <- function(data, name) {
  check_column(data, name, "Variable")
  if (variable_type(data[[name]]) != "numeric") {
    stop("Variable '", name, "' is not numeric.", call. = FALSE)
  }
  invisible(name)
}
