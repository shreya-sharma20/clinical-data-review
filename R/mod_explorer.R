#' Explorer module UI
#'
#' Choose a demo ADaM dataset or upload an XPT/CSV file, then explore it in
#' three tabs: **Data** (a preview, with a variable-summary pop-up), **Summary**
#' (statistics per variable type) and **Charts** (four interactive plots).
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
        shiny::tabPanel(
          "Data",
          shiny::div(
            style = "display: flex; align-items: center; margin-top: 10px;",
            shiny::h4("Data Preview", style = "margin: 0 6px 0 0;"),
            shiny::actionButton(
              ns("info"), label = NULL, icon = shiny::icon("circle-info"),
              class = "btn-link btn-sm", title = "Variable summary",
              `aria-label` = "Show variable summary"
            )
          ),
          shiny::p(shiny::textOutput(ns("overview")), class = "text-muted"),
          DT::DTOutput(ns("data_table"))
        ),
        shiny::tabPanel("Summary", shiny::uiOutput(ns("summary_tables"))),
        shiny::tabPanel(
          "Charts",
          shiny::fluidRow(
            shiny::column(
              6,
              chart_panel("Missing values by variable",
                          plot = plotly::plotlyOutput(ns("missing_chart"), height = "360px"))
            ),
            shiny::column(
              6,
              chart_panel(
                "Composition of a categorical variable",
                shiny::selectInput(ns("pie_var"), "Variable", choices = NULL),
                plot = plotly::plotlyOutput(ns("pie_chart"), height = "360px")
              )
            )
          ),
          shiny::fluidRow(
            shiny::column(
              6,
              chart_panel(
                "Distribution of a numeric variable",
                shiny::fluidRow(
                  shiny::column(6, shiny::selectInput(ns("hist_var"), "Variable", choices = NULL)),
                  shiny::column(6, shiny::selectInput(ns("hist_group"), "Group by",
                                                      choices = c("None" = "")))
                ),
                plot = plotly::plotlyOutput(ns("hist_chart"), height = "360px")
              )
            ),
            shiny::column(
              6,
              chart_panel(
                "Numeric variable by category",
                shiny::fluidRow(
                  shiny::column(6, shiny::selectInput(ns("box_var"), "Variable", choices = NULL)),
                  shiny::column(6, shiny::selectInput(ns("box_cat"), "Category", choices = NULL))
                ),
                plot = plotly::plotlyOutput(ns("box_chart"), height = "360px")
              )
            )
          )
        )
      )
    )
  )
}

#' Headings of the Summary tab's per-type tables
#' @noRd
summary_headings <- function() {
  c(
    numeric = "Numeric variables",
    categorical = "Categorical variables",
    date = "Date variables"
  )
}

#' A titled panel of the Charts tab: heading, optional pickers, then the plot
#' @noRd
chart_panel <- function(title, ..., plot) {
  shiny::div(shiny::h5(title), ..., plot)
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

    # Data tab ---------------------------------------------------------------
    output$overview <- shiny::renderText({
      shiny::req(dataset())
      overview_text(dataset_overview(dataset()$data))
    })

    output$data_table <- DT::renderDT({
      shiny::req(dataset())
      DT::datatable(
        dataset()$data,
        rownames = FALSE, filter = "top",
        options = list(scrollX = TRUE, pageLength = 10)
      )
    })

    # The (i) button opens the variable summary (name, label, type).
    shiny::observeEvent(input$info, {
      shiny::req(dataset())
      shiny::showModal(shiny::modalDialog(
        title = paste("Variable summary:", dataset()$name),
        if (!any(nzchar(dataset()$meta$label))) {
          shiny::p(class = "text-muted",
                   "This dataset has no variable labels (CSV files do not carry them).")
        },
        DT::DTOutput(session$ns("meta_table")),
        size = "l", easyClose = TRUE, footer = shiny::modalButton("Close")
      ))
    })

    output$meta_table <- DT::renderDT({
      shiny::req(dataset())
      DT::datatable(
        dataset()$meta,
        rownames = FALSE, class = "compact stripe hover",
        options = list(pageLength = 10)
      )
    })

    # Summary tab: one table per variable type that is present --------------
    summaries <- shiny::reactive({
      shiny::req(dataset())
      summarize_data(dataset()$data)
    })

    output$summary_tables <- shiny::renderUI({
      tables <- summaries()
      if (length(tables) == 0L) {
        return(shiny::p("The dataset has no variables to summarise."))
      }
      shiny::tagList(lapply(names(tables), function(kind) {
        shiny::tagList(
          shiny::h4(summary_headings()[[kind]]),
          DT::DTOutput(session$ns(paste0("summary_", kind)))
        )
      }))
    })

    # Number formats per table; columns not listed are left as they are.
    summary_digits <- list(
      numeric = list(columns = c("mean", "sd", "median", "min", "max"), digits = 2),
      categorical = list(columns = "top_pct", digits = 1),
      date = NULL
    )
    for (kind in names(summary_headings())) {
      local({
        kind <- kind
        output[[paste0("summary_", kind)]] <- DT::renderDT({
          table <- summaries()[[kind]]
          shiny::req(table)
          out <- DT::datatable(
            table,
            rownames = FALSE, class = "compact stripe hover",
            options = list(scrollX = TRUE, pageLength = 10)
          )
          fmt <- summary_digits[[kind]]
          if (is.null(fmt)) out else DT::formatRound(out, fmt$columns, digits = fmt$digits)
        })
      })
    }

    # Charts tab -------------------------------------------------------------
    choices <- shiny::reactive({
      shiny::req(dataset())
      chart_choices(dataset()$data, dataset()$meta)
    })

    # Keep the pickers in step with whichever dataset is loaded.
    shiny::observe({
      ch <- choices()
      shiny::updateSelectInput(session, "pie_var", choices = ch$categorical)
      shiny::updateSelectInput(session, "hist_var", choices = ch$numeric)
      shiny::updateSelectInput(session, "hist_group",
                               choices = c("None" = "", ch$categorical))
      shiny::updateSelectInput(session, "box_var", choices = ch$numeric)
      shiny::updateSelectInput(session, "box_cat", choices = ch$categorical)
    })

    # A picker's value, or NULL when it has no choices (the plot then shows a
    # message). Waits while the picker still holds a value left over from the
    # previously loaded dataset.
    picked <- function(value, options) {
      if (length(options) == 0L) {
        return(NULL)
      }
      shiny::req(value %in% options)
      value
    }

    output$missing_chart <- plotly::renderPlotly({
      shiny::req(dataset())
      plot_missing(dataset()$data)
    })

    output$pie_chart <- plotly::renderPlotly({
      shiny::req(dataset())
      plot_composition(dataset()$data, picked(input$pie_var, choices()$categorical))
    })

    output$hist_chart <- plotly::renderPlotly({
      shiny::req(dataset())
      plot_histogram(
        dataset()$data,
        picked(input$hist_var, choices()$numeric),
        picked(input$hist_group, c("", choices()$categorical))
      )
    })

    output$box_chart <- plotly::renderPlotly({
      shiny::req(dataset())
      plot_boxplot(
        dataset()$data,
        picked(input$box_var, choices()$numeric),
        picked(input$box_cat, choices()$categorical)
      )
    })

    dataset
  })
}
