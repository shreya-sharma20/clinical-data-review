#' The application server-side
#'
#' Module wiring only: no business logic lives here.
#'
#' @param input,output,session Internal parameters for `{shiny}`.
#'
#' @noRd
app_server <- function(input, output, session) {
  mod_explorer_server("explorer")
  mod_compare_server("compare")
}
