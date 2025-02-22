#' Start the QRAP shiny App
#'
#' @importFrom dplyr %>%
#' @importFrom shiny shinyApp runApp addResourcePath
#' @export
#'

startQRAP <- function(launch.browser = TRUE, port = getOption("shiny.port"), host = getOption("shiny.host", "127.0.0.1")) {

  # set upload file size limit as 100MB
  options(shiny.maxRequestSize = 1000 * 1024^2, warn = -1, shiny.sanitize.errors = TRUE)

  source(system.file("shiny", "global.R", package = "QRAP"), local = T)
  addResourcePath(prefix = "www", directoryPath = system.file("shiny", "www", package = "QRAP"))
  addResourcePath(prefix = "images", directoryPath = system.file("shiny", "www/images", package = "QRAP"))
  addResourcePath(prefix = "Kegg_dir", directoryPath = system.file("shiny", "www/Kegg_dir", package = "QRAP"))

  # kegg_dir <- system.file("shiny", "www/Kegg_dir", package = "QRAP")
  # lapply(dir(kegg_dir, full.names = TRUE), function(x){file.remove(x)})

  shinyApp(ui = mainUI, server = mainServer) %>% runApp(launch.browser = launch.browser, host = host, port = port)

  # appDir <- system.file("shiny", "myApp", package = "QRAP")
  #
  # if (appDir == "") {
  #   stop("Could not find App directory. Try re-installing `QRAP`.", call. = FALSE)
  # }
  #
  # shiny::runApp(appDir, display.mode = "normal")
}
