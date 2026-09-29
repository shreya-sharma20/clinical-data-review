#' Compare module UI
#'
#' Upload two XPT/CSV files, run [diffdf::diffdf()] on demand and show the
#' differences in a table.
#'
#' @param id Module id.
#'
#' @noRd
mod_compare_ui <- function(id) {
  ns <- NS(id)
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      width = 3,
      shiny::fileInput(
        ns("base_file"), "Base dataset (XPT or CSV)",
        accept = c(".xpt", ".csv")
      ),
      shiny::fileInput(
        ns("compare_file"), "Compare dataset (XPT or CSV)",
        accept = c(".xpt", ".csv")
      ),
      shiny::actionButton(ns("run"), "Run comparison", class = "btn-primary")
    ),
    shiny::mainPanel(
      width = 9,
      shiny::textOutput(ns("status")),
      DT::DTOutput(ns("diff_table"))
    )
  )
}

#' Compare module server
#'
#' @param id Module id.
#'
#' @return A reactive returning the latest comparison (the list produced by
#'   `compare_datasets()`), or `NULL` before the first successful run.
#'
#' @noRd
mod_compare_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    comparison <- shiny::eventReactive(input$run, {
      tryCatch(
        {
          if (is.null(input$base_file) || is.null(input$compare_file)) {
            stop("Please upload both a base and a compare dataset.",
                 call. = FALSE)
          }
          base <- read_uploaded_data(input$base_file$datapath,
                                     input$base_file$name)
          compare <- read_uploaded_data(input$compare_file$datapath,
                                        input$compare_file$name)
          compare_datasets(
            base$data, compare$data,
            base_name = base$name, compare_name = compare$name
          )
        },
        error = function(e) {
          shiny::showNotification(conditionMessage(e), type = "error")
          NULL
        }
      )
    })

    output$status <- shiny::renderText({
      shiny::req(comparison())
      if (comparison()$identical) {
        "The datasets are identical."
      } else {
        sprintf("%d issue(s) found.", nrow(comparison()$table))
      }
    })

    output$diff_table <- DT::renderDT({
      shiny::req(comparison())
      DT::datatable(
        comparison()$table,
        rownames = FALSE, filter = "top",
        options = list(scrollX = TRUE, pageLength = 15)
      )
    })

    comparison
  })
}
