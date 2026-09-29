#' Run the adam-review Shiny application
#'
#' @param onStart A function that will be called before the app is actually run.
#'   This is only needed for `shinyAppObj`, since in the case of `shinyAppDir`
#'   you can place code in `global.R`.
#' @param options Named options that should be passed to the `runApp` call
#'   (these can be any of the following: "port", "launch.browser", "host",
#'   "quiet", "display.mode" and "test.mode"). You can also specify `width` and
#'   `height` parameters which provide a hint to the embedding environment about
#'   the ideal height/width for the app.
#' @param enableBookmarking Can be one of `"url"`, `"server"`, or `"disable"`.
#'   The default, `NULL`, respects any previous call to
#'   [shiny::enableBookmarking()], and otherwise defaults to `"disable"`.
#' @param uiPattern A regular expression that will be applied to each `GET`
#'   request to determine whether the `ui` should be used to handle the request.
#' @param ... Arguments to pass to `golem::get_golem_options()`. See `?golem::get_golem_options`
#'   for more details.
#'
#' @export
#' @importFrom shiny shinyApp
#' @importFrom golem with_golem_options
run_app <- function(
  onStart = NULL,
  options = list(),
  enableBookmarking = NULL,
  uiPattern = "/",
  ...
) {
  with_golem_options(
    app = shinyApp(
      ui = app_ui,
      server = app_server,
      onStart = onStart,
      options = options,
      enableBookmarking = enableBookmarking,
      uiPattern = uiPattern
    ),
    golem_opts = list(...)
  )
}
