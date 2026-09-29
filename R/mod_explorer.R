#' Explorer module UI
#'
#' Choose a demo ADaM dataset or upload an XPT/CSV file, then browse the data,
#' its variable labels/types and a per-variable summary.
#'
#' @param id Module id.
#'
#' @noRd
mod_explorer_ui <- function(id) {
  ns <- NS(id)
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      width = 3,
      shiny::radioButtons(
        ns("source"), "Data source",
        choices = c("Demo dataset" = "demo", "Upload file" = "upload")
      ),
      shiny::conditionalPanel(
        condition = sprintf("input['%s'] == 'demo'", ns("source")),
        shiny::selectInput(ns("demo"), "Demo dataset", demo_dataset_names())
      ),
      shiny::conditionalPanel(
        condition = sprintf("input['%s'] == 'upload'", ns("source")),
        shiny::fileInput(
          ns("file"), "XPT or CSV file",
          accept = c(".xpt", ".csv")
        )
      )
    ),
    shiny::mainPanel(
      width = 9,
      shiny::tabsetPanel(
        id = ns("tabs"),
        shiny::tabPanel("Data", DT::DTOutput(ns("data_table"))),
        shiny::tabPanel("Variables", DT::DTOutput(ns("meta_table"))),
        shiny::tabPanel("Summary", DT::DTOutput(ns("summary_table")))
      )
    )
  )
}

#' Explorer module server
#'
#' @param id Module id.
#'
#' @return A reactive returning the loaded dataset (a list with `data`, `meta`
#'   and `name`), or `NULL` when nothing valid is loaded.
#'
#' @noRd
mod_explorer_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    dataset <- shiny::reactive({
      tryCatch(
        if (identical(input$source, "demo")) {
          shiny::req(input$demo)
          load_demo_data(input$demo)
        } else {
          shiny::req(input$file)
          read_uploaded_data(input$file$datapath, input$file$name)
        },
        error = function(e) {
          shiny::showNotification(conditionMessage(e), type = "error")
          NULL
        }
      )
    })

    output$data_table <- DT::renderDT({
      shiny::req(dataset())
      DT::datatable(
        dataset()$data,
        rownames = FALSE, filter = "top",
        options = list(scrollX = TRUE, pageLength = 10)
      )
    })

    output$meta_table <- DT::renderDT({
      shiny::req(dataset())
      DT::datatable(
        dataset()$meta,
        rownames = FALSE, filter = "top",
        options = list(pageLength = 15)
      )
    })

    output$summary_table <- DT::renderDT({
      shiny::req(dataset())
      DT::datatable(
        summarize_data(dataset()$data),
        rownames = FALSE, filter = "top",
        options = list(scrollX = TRUE, pageLength = 15)
      ) |>
        DT::formatRound(c("min", "median", "mean", "max"), digits = 2)
    })

    dataset
  })
}
