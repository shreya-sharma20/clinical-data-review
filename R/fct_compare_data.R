#' Compare two datasets with diffdf
#'
#' Wraps [diffdf::diffdf()] and reshapes its list of issue tables into one
#' tidy table with one row per issue.
#'
#' @param base,compare Data frames to compare. `compare` is checked against
#'   `base`.
#' @param keys Optional character vector of key columns used to match rows.
#'   When `NULL`, rows are matched by position.
#' @param base_name,compare_name Labels used in the issue details.
#'
#' @return A list with elements
#'   * `identical`: `TRUE` when no differences were found;
#'   * `table`: a data frame with columns `issue`, `variable` and `detail`.
#'     When the datasets are identical it holds a single row whose `issue` is
#'     `"identical"`;
#'   * `base_name`, `compare_name`: the labels used.
#'
#' Issue types are `value_difference`, `column_only_in_base`,
#' `column_only_in_compare`, `type_mismatch`, `row_count`,
#' `rows_only_in_base` and `rows_only_in_compare`.
#' @noRd
compare_datasets <- function(base, compare, keys = NULL,
                             base_name = "BASE", compare_name = "COMPARE") {
  stopifnot(is.data.frame(base), is.data.frame(compare))

  diff <- tryCatch(
    diffdf::diffdf(
      base, compare,
      keys = keys,
      suppress_warnings = TRUE
    ),
    error = function(e) {
      stop("Could not compare the datasets: ", conditionMessage(e),
           call. = FALSE)
    }
  )

  issues <- rbind(
    diff_columns(diff$ExtColsBase, "column_only_in_base", base_name,
                 compare_name),
    diff_columns(diff$ExtColsComp, "column_only_in_compare", compare_name,
                 base_name),
    diff_types(diff),
    diff_row_count(base, compare, base_name, compare_name),
    diff_rows(diff$ExtRowsBase, "rows_only_in_base", base_name, compare_name),
    diff_rows(diff$ExtRowsComp, "rows_only_in_compare", compare_name,
              base_name),
    diff_values(diff)
  )

  identical <- length(diff) == 0L && nrow(issues) == 0L
  if (identical) {
    issues <- new_issues("identical", "", "No differences found")
  }

  list(
    identical = identical,
    table = issues,
    base_name = base_name,
    compare_name = compare_name
  )
}

#' Build an issue table (zero or more rows)
#' @noRd
new_issues <- function(issue = character(), variable = character(),
                       detail = character()) {
  n <- max(length(issue), length(variable), length(detail))
  if (n == 0L) {
    return(data.frame(issue = character(), variable = character(),
                      detail = character(), stringsAsFactors = FALSE))
  }
  data.frame(
    issue = rep_len(as.character(issue), n),
    variable = rep_len(as.character(variable), n),
    detail = rep_len(as.character(detail), n),
    stringsAsFactors = FALSE
  )
}

#' Columns present in only one dataset
#' @noRd
diff_columns <- function(tbl, issue, present_in, missing_from) {
  if (is.null(tbl) || nrow(tbl) == 0L) return(new_issues())
  new_issues(
    issue, tbl$COLUMNS,
    paste0("Column is in ", present_in, " but not in ", missing_from)
  )
}

#' Type (class) mismatches on columns present in both datasets
#'
#' Uses the class differences, plus any mode-only difference diffdf reports.
#' @noRd
diff_types <- function(diff) {
  collapse_class <- function(x) {
    vapply(x, paste, character(1), collapse = "/")
  }
  out <- new_issues()

  cls <- diff$VarClassDiffs
  if (!is.null(cls) && nrow(cls) > 0L) {
    out <- new_issues(
      "type_mismatch", cls$VARIABLE,
      paste0("Class is ", collapse_class(cls$CLASS.BASE), " in base but ",
             collapse_class(cls$CLASS.COMP), " in compare")
    )
  }

  mode <- diff$VarModeDiffs
  if (!is.null(mode) && nrow(mode) > 0L) {
    mode <- mode[!mode$VARIABLE %in% out$variable, , drop = FALSE]
    if (nrow(mode) > 0L) {
      out <- rbind(out, new_issues(
        "type_mismatch", mode$VARIABLE,
        paste0("Mode is ", mode$MODE.BASE, " in base but ", mode$MODE.COMP,
               " in compare")
      ))
    }
  }
  out
}

#' Differing number of rows
#' @noRd
diff_row_count <- function(base, compare, base_name, compare_name) {
  if (nrow(base) == nrow(compare)) return(new_issues())
  new_issues(
    "row_count", "",
    paste0(base_name, " has ", nrow(base), " rows but ", compare_name,
           " has ", nrow(compare))
  )
}

#' Rows present in only one dataset
#'
#' diffdf identifies these rows by the key columns, or by `..ROWNUMBER..`
#' when no keys were given.
#' @noRd
diff_rows <- function(tbl, issue, present_in, missing_from) {
  if (is.null(tbl) || nrow(tbl) == 0L) return(new_issues())
  new_issues(
    issue, "",
    paste0(nrow(tbl), " row(s) in ", present_in, " but not in ",
           missing_from, ": ", summarize_row_ids(tbl))
  )
}

#' One row per variable with differing values
#' @noRd
diff_values <- function(diff) {
  value_tables <- diff[startsWith(names(diff), "VarDiff_")]
  if (length(value_tables) == 0L) return(new_issues())

  do.call(rbind, unname(lapply(value_tables, function(tbl) {
    n <- nrow(tbl)
    shown <- utils::head(tbl, 3L)
    ids <- row_ids(shown[setdiff(names(shown),
                                 c("VARIABLE", "BASE", "COMPARE"))])
    examples <- paste0(ids, ": base ", format_value(shown$BASE),
                       " vs compare ", format_value(shown$COMPARE),
                       collapse = "; ")
    new_issues(
      "value_difference", tbl$VARIABLE[[1]],
      paste0(n, " value(s) differ (", examples,
             if (n > 3L) "; ..." else "", ")")
    )
  })))
}

#' Human-readable identifiers, one per row, from a key / row-number table
#' @noRd
row_ids <- function(tbl) {
  if (ncol(tbl) == 0L) return(character(nrow(tbl)))
  if (identical(names(tbl), "..ROWNUMBER..")) {
    return(paste("row", tbl[[1]]))
  }
  do.call(paste, c(
    Map(function(nm, col) paste0(nm, "=", col), names(tbl), tbl),
    sep = ", "
  ))
}

#' Comma-separated ids, truncated to the first few
#' @noRd
summarize_row_ids <- function(tbl, max_ids = 5L) {
  ids <- row_ids(tbl)
  out <- paste(utils::head(ids, max_ids), collapse = ", ")
  if (length(ids) > max_ids) paste0(out, ", ...") else out
}

#' Format values for display in a detail string
#' @noRd
format_value <- function(x) {
  ifelse(is.na(x), "NA", paste0("'", as.character(x), "'"))
}
