# Read component -> wheel_subdir mapping from the installed components.tsv
read_components <- function() {
  tsv <- system.file(
    "components.tsv",
    package = utils::packageName(),
    mustWork = TRUE
  )
  df <- utils::read.delim(tsv, stringsAsFactors = FALSE)
  stats::setNames(df$wheel_subdir, df$component)
}

the <- new.env(parent = emptyenv())

component_subdir <- function(component) {
  if (is.null(the[["components"]])) {
    the[["components"]] <- read_components()
  }
  if (!component %in% names(the[["components"]])) {
    stop(sprintf(
      "Unknown component: '%s'. Available: %s",
      component,
      paste(names(the[["components"]]), collapse = ", ")
    ))
  }
  the[["components"]][[component]]
}

#' @title Path to a CUDA Component Installation
#' @description
#' Returns the installation root of a single CUDA component.
#' @param component (`character(1)`)\cr
#'   Component name (e.g., `"runtime"`, `"cublas"`, `"nvcc"`).
#'   See `inst/components.tsv` for the full list.
#' @return (`character(1)`)\cr
#'   Path to the installed component files.
#' @export
cuda_path <- function(component) {
  system.file(
    "nvidia",
    component_subdir(component),
    package = utils::packageName(),
    mustWork = TRUE
  )
}

#' @title Path to the Shared Library Directory
#' @description
#' All CUDA component shared libraries are installed into a single directory,
#' which this function returns.
#' @return (`character(1)`)\cr
#'   Path to the lib directory.
#' @export
lib_path <- function() {
  system.file("lib", package = utils::packageName(), mustWork = TRUE)
}

#' @title Path to a CUDA Component's Headers
#' @description
#' Returns the include directory of a single CUDA component.
#' @inheritParams cuda_path
#' @return (`character(1)`)\cr
#'   Path to the component's include directory.
#' @export
include_path <- function(component) {
  file.path(cuda_path(component), "include")
}

#' @title Path to a CUDA Component's Binaries
#' @description
#' Returns the bin directory of a single CUDA component (e.g. `ptxas` for
#' `"nvcc"`).
#' @inheritParams cuda_path
#' @return (`character(1)`)\cr
#'   Path to the component's bin directory.
#' @export
bin_path <- function(component) {
  file.path(cuda_path(component), "bin")
}
