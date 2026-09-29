# Minimal host app for the Report module (used by test-mod_report.R).
# shinytest2 overrides library() so that this loads the local package source.
library(shiny)
library(adamreview)

demo_data <- data.frame(
  USUBJID = c("S1", "S2", "S3"),
  AGE = c(30, 40, NA),
  SEX = c("F", "M", "F")
)
demo_dataset <- adamreview:::new_dataset(demo_data, "DEMO")
demo_comparison <- adamreview:::compare_datasets(
  demo_data, transform(demo_data, AGE = AGE + 1)
)

shinyApp(
  ui = fluidPage(adamreview:::mod_report_ui("report")),
  server = function(input, output, session) {
    adamreview:::mod_report_server(
      "report",
      dataset = reactive(demo_dataset),
      comparison = reactive(demo_comparison)
    )
  }
)
