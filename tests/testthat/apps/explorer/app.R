# Minimal host app for the Explorer module (used by test-mod_explorer.R).
# shinytest2 overrides library() so that this loads the local package source.
library(shiny)
library(adamreview)

shinyApp(
  ui = fluidPage(adamreview:::mod_explorer_ui("explorer")),
  server = function(input, output, session) {
    adamreview:::mod_explorer_server("explorer")
  }
)
