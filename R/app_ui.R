#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'
#' @importFrom shiny fluidPage titlePanel
#' @noRd
app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),
    fluidPage(
      titlePanel("adam-review"),
      shiny::tabsetPanel(
        shiny::tabPanel("Explorer", mod_explorer_ui("explorer")),
        shiny::tabPanel("Compare", mod_compare_ui("compare")),
        shiny::tabPanel("Report", mod_report_ui("report"))
      )
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external resources inside the
#' Shiny application.
#'
#' @importFrom golem add_resource_path bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www",
    app_sys("app/www")
  )

  tags$head(
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "adam-review"
    )
  )
}
