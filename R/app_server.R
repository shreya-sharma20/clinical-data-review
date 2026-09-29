#' The application server-side
#'
#' Module wiring only: no business logic lives here.
#'
#' @param input,output,session Internal parameters for `{shiny}`.
#'
#' @noRd
app_server <- function(input, output, session) {
  dataset <- mod_explorer_server("explorer")
  comparison <- mod_compare_server("compare")
  mod_report_server("report", dataset, comparison)
}
