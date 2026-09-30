# Helpers -----------------------------------------------------------------------

chart_fixture <- function() {
  data <- data.frame(
    AGE = c(30, 40, 50, 60, NA, 45),
    SEX = c("F", "M", "F", "M", "F", ""),
    ARM = c("A", "A", "B", "B", NA, "A"),
    FLAG = c(TRUE, FALSE, TRUE, TRUE, FALSE, TRUE),
    DT = as.Date("2024-01-01") + 0:5,
    stringsAsFactors = FALSE
  )
  attr(data$AGE, "label") <- "Age"
  attr(data$SEX, "label") <- "Sex"
  attr(data$ARM, "label") <- "Planned Arm"
  data
}

built <- function(p) plotly::plotly_build(p)$x

built_traces <- function(p) built(p)$data

trace_types <- function(p) vapply(built_traces(p), function(t) t$type, character(1))

trace_names <- function(p) vapply(built_traces(p), function(t) t$name, character(1))

# Plotly stores a title either as a string or as list(text = ...).
plot_title <- function(title) if (is.list(title)) title$text else title

axis_text <- function(p, axis) plot_title(built(p)$layout[[axis]]$title)

annotation_text <- function(p) built(p)$layout$annotations[[1]]$text

# A chart with nothing to draw: no data trace, but an explanatory message.
expect_message_plot <- function(p, pattern) {
  expect_s3_class(p, "plotly")
  expect_false(any(trace_types(p) %in% c("bar", "histogram", "pie", "box")))
  expect_match(annotation_text(p), pattern)
}

# chart_choices() ---------------------------------------------------------------

test_that("chart_choices() splits numeric from low-cardinality categorical variables", {
  choices <- chart_choices(chart_fixture())

  expect_named(choices, c("numeric", "categorical"))
  expect_equal(unname(choices$numeric), "AGE")
  expect_equal(unname(choices$categorical), c("SEX", "ARM", "FLAG"))
  # dates are not offered
  expect_false("DT" %in% unlist(choices))
})

test_that("chart_choices() displays labels and tolerates no labels", {
  choices <- chart_choices(chart_fixture())

  expect_equal(names(choices$numeric), "AGE - Age")
  expect_equal(names(choices$categorical), c("SEX - Sex", "ARM - Planned Arm", "FLAG"))
})

test_that("chart_choices() leaves out identifiers and all-missing variables", {
  n <- 100
  data <- data.frame(
    ID = sprintf("S%03d", seq_len(n)),
    ALLNA_C = NA_character_,
    ALLNA_N = NA_real_,
    EMPTY = "",
    ONEVAL = "X",
    NUM = seq_len(n),
    stringsAsFactors = FALSE
  )
  choices <- chart_choices(data)

  expect_equal(unname(choices$categorical), "ONEVAL")
  expect_equal(unname(choices$numeric), "NUM")
})

test_that("chart_choices() applies the low-cardinality limit inclusively", {
  limit <- max_low_cardinality()
  at_limit <- data.frame(X = as.character(seq_len(limit)))
  over_limit <- data.frame(X = as.character(seq_len(limit + 1L)))

  expect_equal(unname(chart_choices(at_limit)$categorical), "X")
  expect_length(chart_choices(over_limit)$categorical, 0)
})

test_that("chart_choices() puts constant variables last so the default is informative", {
  data <- data.frame(
    STUDY = "S1", SEX = c("F", "M"), ARM = c("A", "B"), stringsAsFactors = FALSE
  )
  expect_equal(unname(chart_choices(data)$categorical), c("SEX", "ARM", "STUDY"))
})

test_that("chart_choices() handles zero-variable and zero-row data", {
  choices <- chart_choices(data.frame())
  expect_length(choices$numeric, 0)
  expect_length(choices$categorical, 0)

  choices <- chart_choices(chart_fixture()[0, ])
  expect_length(unlist(choices), 0)
})

# plot_missing() ----------------------------------------------------------------

test_that("plot_missing() draws one horizontal bar per incomplete variable", {
  p <- plot_missing(chart_fixture())

  expect_s3_class(p, "plotly")
  expect_equal(trace_types(p), "bar")
  trace <- built_traces(p)[[1]]
  expect_equal(trace$orientation, "h")
  # SEX ("" counts as missing), ARM and AGE each have one missing of six;
  # complete variables are not drawn
  expect_setequal(as.vector(trace$y), c("AGE", "SEX", "ARM"))
  expect_equal(as.vector(trace$x), rep(100 / 6, 3))
})

test_that("plot_missing() ranks variables by how much is missing", {
  data <- data.frame(A = c(1, NA, NA, NA), B = c(1, 2, NA, NA), C = c(1, 2, 3, NA))
  trace <- built_traces(plot_missing(data))[[1]]

  expect_equal(as.vector(trace$y), c("A", "B", "C"))
  expect_equal(as.vector(trace$x), c(75, 50, 25))
  expect_equal(built(plot_missing(data))$layout$yaxis$categoryarray, c("C", "B", "A"))
})

test_that("plot_missing() caps the number of bars on wide data", {
  wide <- as.data.frame(
    matrix(NA_real_, nrow = 3, ncol = 50, dimnames = list(NULL, paste0("V", 1:50)))
  )
  p <- plot_missing(wide)

  expect_length(built_traces(p)[[1]]$y, max_chart_categories())
  expect_match(
    axis_text(p, "xaxis"),
    sprintf("top %d of 50", max_chart_categories()), fixed = TRUE
  )
})

test_that("plot_missing() gives a message when nothing is missing or there is no data", {
  expect_message_plot(plot_missing(data.frame(A = 1:3, B = c("x", "y", "z"))),
                      "No missing values")
  expect_message_plot(plot_missing(chart_fixture()[0, ]), "No data")
  expect_message_plot(plot_missing(data.frame()), "No data")
})

# plot_composition() -------------------------------------------------------------

test_that("plot_composition() draws a donut of category counts", {
  p <- plot_composition(chart_fixture(), "SEX")

  expect_s3_class(p, "plotly")
  expect_equal(trace_types(p), "pie")
  trace <- built_traces(p)[[1]]
  expect_gt(trace$hole, 0)
  # the empty string counts as missing and is not drawn
  expect_equal(setNames(as.vector(trace$values), as.vector(trace$labels)), c(F = 3, M = 2))
  expect_equal(plot_title(built(p)$layout$title), "Sex (SEX)")
})

test_that("plot_composition() works for logical and factor variables", {
  data <- chart_fixture()
  data$SEX <- factor(data$SEX)

  expect_equal(trace_types(plot_composition(data, "FLAG")), "pie")
  expect_equal(trace_types(plot_composition(data, "SEX")), "pie")
})

test_that("plot_composition() pools the tail of many categories into 'Other'", {
  data <- data.frame(X = c(rep("a", 5), letters[2:13]), stringsAsFactors = FALSE)
  trace <- built_traces(plot_composition(data, "X"))[[1]]

  labels <- as.vector(trace$labels)
  expect_length(labels, max_chart_groups() + 1L)
  expect_equal(labels[1], "a")
  expect_equal(labels[max_chart_groups() + 1L], "Other")
  expect_equal(sum(trace$values), nrow(data)) # no rows lost
})

test_that("plot_composition() handles all-missing, empty and unavailable input", {
  data <- data.frame(X = c(NA_character_, ""), stringsAsFactors = FALSE)
  expect_message_plot(plot_composition(data, "X"), "No non-missing")
  expect_message_plot(plot_composition(chart_fixture()[0, ], "SEX"), "No non-missing")
  expect_message_plot(plot_composition(chart_fixture(), NULL), "No suitable categorical")
  expect_message_plot(plot_composition(chart_fixture(), ""), "No suitable categorical")
})

test_that("plot_composition() errors clearly for unknown or non-categorical columns", {
  expect_error(plot_composition(chart_fixture(), "NOPE"), "not a column")
  expect_error(plot_composition(chart_fixture(), "AGE"), "not categorical")
  expect_error(plot_composition(chart_fixture(), "DT"), "not categorical")
  expect_error(plot_composition(list(), "AGE"))
})

# plot_histogram() ---------------------------------------------------------------

test_that("plot_histogram() draws a histogram and drops missing values", {
  p <- plot_histogram(chart_fixture(), "AGE")

  expect_s3_class(p, "plotly")
  expect_equal(trace_types(p), "histogram")
  expect_equal(sort(built_traces(p)[[1]]$x), c(30, 40, 45, 50, 60))
})

test_that("axis titles use the variable label, falling back to the name", {
  data <- chart_fixture()
  data$PLAIN <- as.numeric(1:6)

  expect_equal(axis_text(plot_histogram(data, "AGE"), "xaxis"), "Age (AGE)")
  expect_equal(axis_text(plot_histogram(data, "PLAIN"), "xaxis"), "PLAIN")
  expect_equal(axis_text(plot_histogram(data, "AGE"), "yaxis"), "Count")
})

test_that("grouping produces one trace per group, with missing groups labelled", {
  data <- chart_fixture()
  data$AGE[5] <- 55 # the row with a missing ARM now has an age

  p <- plot_histogram(data, "AGE", group = "ARM")
  expect_setequal(trace_names(p), c("A", "B", "(Missing)"))
  expect_equal(trace_types(p), rep("histogram", 3))
  expect_equal(plot_title(built(p)$layout$legend$title), "Planned Arm (ARM)")
})

test_that("NULL, empty and self grouping all mean no grouping", {
  data <- chart_fixture()
  expect_length(built_traces(plot_histogram(data, "AGE", group = NULL)), 1)
  expect_length(built_traces(plot_histogram(data, "AGE", group = "")), 1)
  expect_length(built_traces(plot_histogram(data, "AGE", group = "AGE")), 1)
})

test_that("high-cardinality grouping pools the tail into 'Other'", {
  n <- 100
  data <- data.frame(
    AGE = seq_len(n),
    ID = sprintf("S%03d", seq_len(n)),
    stringsAsFactors = FALSE
  )

  expect_no_error(p <- plot_histogram(data, "AGE", group = "ID"))
  names <- trace_names(p)
  expect_lte(length(names), max_chart_groups() + 1L)
  expect_true("Other" %in% names)
  # no rows are lost by pooling
  expect_equal(sum(vapply(built_traces(p), function(t) length(t$x), integer(1))), n)
})

test_that("histogram groups share the same bins, and constant data still plots", {
  p <- plot_histogram(chart_fixture(), "AGE", group = "ARM")
  bins <- lapply(built_traces(p), function(t) t$xbins)
  expect_length(unique(bins), 1)

  expect_equal(trace_types(plot_histogram(data.frame(X = c(5, 5, 5)), "X")), "histogram")
})

test_that("non-finite numeric values are ignored", {
  p <- plot_histogram(data.frame(X = c(1, Inf, -Inf, NaN, 2)), "X")
  expect_equal(sort(built_traces(p)[[1]]$x), c(1, 2))
})

test_that("plot_histogram() handles all-missing, empty and unavailable input", {
  expect_message_plot(
    plot_histogram(data.frame(AGE = c(NA_real_, NA_real_)), "AGE"), "No non-missing"
  )
  expect_no_error(p <- plot_histogram(chart_fixture()[0, ], "AGE", group = "ARM"))
  expect_message_plot(p, "No non-missing")
  expect_message_plot(plot_histogram(chart_fixture(), NULL), "No numeric variables")
})

test_that("plot_histogram() errors clearly for unknown or non-numeric columns", {
  data <- chart_fixture()
  expect_error(plot_histogram(data, "NOPE"), "not a column")
  expect_error(plot_histogram(data, "AGE", group = "NOPE"), "Group variable 'NOPE'")
  expect_error(plot_histogram(data, "SEX"), "not numeric")
  expect_error(plot_histogram(data, "DT"), "not numeric")
})

# plot_boxplot() -----------------------------------------------------------------

test_that("plot_boxplot() draws one box per category", {
  p <- plot_boxplot(chart_fixture(), "AGE", "SEX")

  expect_s3_class(p, "plotly")
  # categories are ordered by frequency; the empty SEX forms a "(Missing)" box
  # and the missing age is dropped
  expect_equal(trace_types(p), rep("box", 3))
  expect_equal(trace_names(p), c("F", "M", "(Missing)"))
  expect_equal(sort(built_traces(p)[[1]]$y), c(30, 50))
  expect_equal(axis_text(p, "xaxis"), "Sex (SEX)")
  expect_equal(axis_text(p, "yaxis"), "Age (AGE)")
})

test_that("plot_boxplot() labels missing categories and pools many categories", {
  data <- chart_fixture()
  data$AGE[5] <- 55
  expect_true("(Missing)" %in% trace_names(plot_boxplot(data, "AGE", "ARM")))

  many <- data.frame(Y = 1:100, G = sprintf("G%03d", 1:100), stringsAsFactors = FALSE)
  p <- plot_boxplot(many, "Y", "G")
  expect_lte(length(built_traces(p)), max_chart_groups() + 1L)
  expect_true("Other" %in% trace_names(p))
})

test_that("plot_boxplot() handles all-missing, empty and unavailable input", {
  data <- chart_fixture()
  expect_message_plot(
    plot_boxplot(data.frame(Y = NA_real_, G = "a"), "Y", "G"), "No non-missing"
  )
  expect_no_error(p <- plot_boxplot(data[0, ], "AGE", "SEX"))
  expect_message_plot(p, "No non-missing")
  expect_message_plot(plot_boxplot(data, NULL, "SEX"), "No numeric variables")
  expect_message_plot(plot_boxplot(data, "AGE", NULL), "No suitable categorical")
  expect_message_plot(plot_boxplot(data, "AGE", ""), "No suitable categorical")
})

test_that("plot_boxplot() errors clearly for unknown or non-numeric columns", {
  data <- chart_fixture()
  expect_error(plot_boxplot(data, "NOPE", "SEX"), "not a column")
  expect_error(plot_boxplot(data, "AGE", "NOPE"), "Category variable 'NOPE'")
  expect_error(plot_boxplot(data, "SEX", "ARM"), "not numeric")
})

# Real data ---------------------------------------------------------------------

test_that("all four charts work on real demo data", {
  skip_if_not_installed("pharmaverseadam")
  for (name in demo_dataset_names()) {
    data <- load_demo_data(name)$data
    choices <- chart_choices(data)

    expect_s3_class(plot_missing(data), "plotly")
    expect_gt(length(choices$categorical), 0)
    expect_equal(trace_types(plot_composition(data, choices$categorical[[1]])), "pie")
    expect_gt(length(choices$numeric), 0)
    expect_equal(trace_types(plot_histogram(data, choices$numeric[[1]])), "histogram")
    expect_s3_class(
      plot_boxplot(data, choices$numeric[[1]], choices$categorical[[1]]), "plotly"
    )
  }
})
