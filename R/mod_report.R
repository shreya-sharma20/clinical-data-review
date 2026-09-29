#' Report module UI
#'
#' A download button for the parameterized Quarto HTML report.
#'
#' @param id Module id.
#'
#' @noRd
mod_report_ui <- function(id) {
  ns <- NS(id)
  shiny::tagList(
    shiny::p(
      "Download an HTML report combining the Explorer summary and the",
      "latest Compare result."
    ),
    shiny::downloadButton(ns("download"), "Download report",
                          class = "btn-primary")
  )
}

#' Report module server
#'
#' @param id Module id.
#' @param dataset Reactive returning the Explorer dataset (or `NULL`).
#' @param comparison Reactive returning the Compare result (or `NULL`).
#'
#' @noRd
mod_report_server <- function(id, dataset, comparison) {
  shiny::moduleServer(id, function(input, output, session) {
    # A reactive that is not ready (e.g. no upload yet) counts as "nothing".
    value_or_null <- function(x) tryCatch(x(), error = function(e) NULL)

    output$download <- shiny::downloadHandler(
      filename = function() {
        paste0("adam-review-report-", format(Sys.Date(), "%Y%m%d"), ".html")
      },
      content = function(file) {
        tryCatch(
          render_report(value_or_null(dataset), value_or_null(comparison),
                        output_file = file),
          error = function(e) {
            shiny::showNotification(conditionMessage(e), type = "error")
            stop(e)
          }
        )
      }
    )
  })
}
