the <- new.env(parent = emptyenv())

# Read component -> wheel_subdir mapping from components.tsv
component_subdir <- function(component) {
  if (is.null(the[["components"]])) {
    df <- read_components()
    the[["components"]] <- stats::setNames(df$wheel_subdir, df$component)
  }
  if (!component %in% names(the[["components"]])) {
    stop(sprintf(
      "Unknown component: '%s'. Available: %s",
      component,
      paste(names(the[["components"]]), collapse = ", ")
    ), call. = FALSE)
  }
  the[["components"]][[component]]
}

# Returns cuda_home(), erroring if the components are not installed.
installed_home <- function() {
  home <- cuda_home()
  if (!cuda_installed()) {
    stop(
      "The CUDA components are not installed in ", home, ". ",
      "Run `pjrt.cuda::install_cuda()` to install them.",
      call. = FALSE
    )
  }
  home
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
  path <- file.path(installed_home(), "nvidia", component_subdir(component))
  if (!dir.exists(path)) {
    stop(sprintf(
      "Component '%s' is not installed (check PJRT_CUDA_COMPONENTS).", component
    ), call. = FALSE)
  }
  path
}

#' @title Path to the Shared Library Directory
#' @description
#' All CUDA component shared libraries are installed into a single directory,
#' which this function returns.
#' @return (`character(1)`)\cr
#'   Path to the lib directory.
#' @export
lib_path <- function() {
  file.path(installed_home(), "lib")
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
