# Minimal host app for the Compare module (used by test-mod_compare.R).
# shinytest2 overrides library() so that this loads the local package source.
library(shiny)
library(adamreview)

shinyApp(
  ui = fluidPage(adamreview:::mod_compare_ui("compare")),
  server = function(input, output, session) {
    adamreview:::mod_compare_server("compare")
  }
)
