# Installation of the CUDA components.
#
# The source package ships only `inst/components.tsv`, which pins the NVIDIA
# PyPI wheels the CUDA PJRT plugin needs. The wheels are downloaded and
# unpacked into `cuda_home()` the first time the package is loaded (see
# `.onLoad()` in zzz.R) or when `install_cuda()` is called explicitly.

PATCHELF_VERSION <- "0.17.2.2"
PATCHELF_URLS <- c(
  x86_64 = "https://files.pythonhosted.org/packages/f2/f9/e070956e350ccdfdf059251836f757ad91ac0c01b0ba3e033ea7188d8d42/patchelf-0.17.2.2-py3-none-manylinux1_x86_64.manylinux_2_5_x86_64.musllinux_1_1_x86_64.whl",
  aarch64 = "https://files.pythonhosted.org/packages/56/0d/dc3ac6c6e9e9d0d3e40bee1abe95a07034f83627319e60a7dc9abdbfafee/patchelf-0.17.2.2-py3-none-manylinux2014_aarch64.manylinux_2_17_aarch64.musllinux_1_1_aarch64.whl"
)

#' @title Installation Directory of the CUDA Components
#' @description
#' Returns the directory into which the CUDA components are downloaded.
#' This is `tools::R_user_dir("pjrt.cuda", "cache")` unless the environment
#' variable `PJRT_CUDA_HOME` is set.
#' @return (`character(1)`)\cr
#'   Path to the installation directory (which may not exist yet).
#' @export
cuda_home <- function() {
  home <- Sys.getenv("PJRT_CUDA_HOME", "")
  if (nzchar(home)) {
    return(normalizePath(home, mustWork = FALSE))
  }
  tools::R_user_dir("pjrt.cuda", which = "cache")
}

#' @title Are the CUDA Components Installed?
#' @description
#' Checks whether the CUDA components selected by `PJRT_CUDA_COMPONENTS`
#' (default: all) are installed in [cuda_home()] with the versions pinned by
#' this version of the package.
#' @return (`logical(1)`)
#' @export
cuda_installed <- function() {
  marker <- installed_marker_path()
  if (!file.exists(marker)) {
    return(FALSE)
  }
  installed <- tryCatch(read_tsv(marker), error = function(e) NULL)
  if (is.null(installed)) {
    return(FALSE)
  }
  same_table(installed, selected_components())
}

#' @title Install the CUDA Components
#' @description
#' Downloads the CUDA components from PyPI and unpacks them into
#' [cuda_home()]. This runs automatically when the package is loaded (see
#' [pjrt.cuda-package] for how to control that), so calling it manually is
#' only needed to force a reinstallation or to install in a session where
#' automatic downloads are disabled.
#'
#' Which components are installed is controlled by the environment variable
#' `PJRT_CUDA_COMPONENTS`, see [pjrt.cuda-package].
#' @param reinstall (`logical(1)`)\cr
#'   Whether to reinstall even if the components are already installed.
#' @return (`character(1)`)\cr
#'   The installation directory, invisibly.
#' @export
install_cuda <- function(reinstall = FALSE) {
  stopifnot(is.logical(reinstall), length(reinstall) == 1L, !is.na(reinstall))
  arch <- check_platform()
  home <- cuda_home()
  components <- selected_components()

  if (!reinstall && cuda_installed()) {
    message("CUDA components are already installed in ", home, ".")
    return(invisible(home))
  }

  message("=== pjrt.cuda: installing CUDA components into ", home, " ===")
  if (nzchar(Sys.getenv("PJRT_CUDA_COMPONENTS", ""))) {
    message("* Components: ", Sys.getenv("PJRT_CUDA_COMPONENTS"))
  }

  # Only remove what we manage; PJRT_CUDA_HOME may point somewhere the user
  # keeps other things.
  unlink(c(installed_marker_path(), file.path(home, c("lib", "nvidia"))), recursive = TRUE)
  lib_dir <- file.path(home, "lib")
  dir.create(lib_dir, recursive = TRUE, showWarnings = FALSE)

  tmpdir <- tempfile("pjrt.cuda-")
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

  old <- options(timeout = max(getOption("timeout", 60), 3600))
  on.exit(options(old), add = TRUE)

  for (i in seq_len(nrow(components))) {
    install_component(components[i, ], arch, home, tmpdir)
  }

  patch_rpath(lib_dir, arch, tmpdir)

  write_tsv(components, installed_marker_path())
  message("=== All components installed successfully ===")
  invisible(home)
}

# ---- components.tsv ---------------------------------------------------------

installed_marker_path <- function() {
  file.path(cuda_home(), "components.tsv")
}

read_tsv <- function(path) {
  df <- utils::read.delim(path, stringsAsFactors = FALSE, colClasses = "character")
  rownames(df) <- NULL
  df
}

write_tsv <- function(df, path) {
  utils::write.table(df, path, sep = "\t", quote = FALSE, row.names = FALSE)
}

same_table <- function(a, b) {
  identical(names(a), names(b)) &&
    nrow(a) == nrow(b) &&
    all(unlist(Map(identical, a, b)))
}

# The full component table shipped with the package.
read_components <- function() {
  tsv <- system.file("components.tsv", package = utils::packageName(), mustWork = TRUE)
  read_tsv(tsv)
}

# The component table restricted to PJRT_CUDA_COMPONENTS, with `@version`
# overrides applied. Unset means all components at their pinned versions.
selected_components <- function() {
  components <- read_components()
  spec <- Sys.getenv("PJRT_CUDA_COMPONENTS", "")
  if (!nzchar(spec)) {
    return(components)
  }

  entries <- trimws(strsplit(spec, ",", fixed = TRUE)[[1]])
  entries <- entries[nzchar(entries)]
  parts <- strsplit(entries, "@", fixed = TRUE)
  selected <- vapply(parts, `[[`, character(1), 1L)
  overrides <- vapply(parts, function(p) if (length(p) > 1L) p[[2L]] else NA_character_, character(1))

  unknown <- setdiff(selected, components$component)
  if (length(unknown)) {
    stop(sprintf(
      "Unknown component(s) in PJRT_CUDA_COMPONENTS: %s. Available: %s",
      paste(unknown, collapse = ", "),
      paste(components$component, collapse = ", ")
    ), call. = FALSE)
  }

  out <- components[components$component %in% selected, , drop = FALSE]
  idx <- match(out$component, selected)
  out$version <- ifelse(is.na(overrides[idx]), out$version, overrides[idx])
  rownames(out) <- NULL
  out
}

# ---- platform ---------------------------------------------------------------

# Returns NULL if the CUDA components can be installed on this machine,
# otherwise a string explaining why not.
platform_problem <- function() {
  info <- Sys.info()
  if (info[["sysname"]] != "Linux") {
    return(sprintf(
      "pjrt.cuda only supports Linux (detected: %s). The CUDA PJRT plugin is not available for other platforms.",
      info[["sysname"]]
    ))
  }
  if (!info[["machine"]] %in% c("x86_64", "aarch64")) {
    return(sprintf(
      "pjrt.cuda only supports x86_64 and aarch64 (detected: %s).",
      info[["machine"]]
    ))
  }
  NULL
}

# Errors on unsupported platforms, otherwise returns the architecture.
check_platform <- function() {
  problem <- platform_problem()
  if (!is.null(problem)) {
    stop(problem, call. = FALSE)
  }
  Sys.info()[["machine"]]
}

# ---- download & extraction --------------------------------------------------

download <- function(url, dest, quiet = TRUE) {
  status <- tryCatch(
    utils::download.file(url, dest, mode = "wb", quiet = quiet),
    error = function(e) {
      stop(sprintf("Download of %s failed: %s", url, conditionMessage(e)), call. = FALSE)
    }
  )
  if (!identical(status, 0L) || !file.exists(dest)) {
    stop(sprintf("Download of %s failed (status %s).", url, status), call. = FALSE)
  }
  invisible(dest)
}

# Look up the wheel for `pypi_package == version` on `arch` in PyPI's simple
# index. Returns the URL, with the sha256 from the URL fragment (if any) as
# attribute "sha256".
find_wheel_url <- function(pypi_package, version, arch, tmpdir) {
  index <- file.path(tmpdir, paste0("index_", pypi_package, ".html"))
  download(paste0("https://pypi.org/simple/", pypi_package, "/"), index)
  html <- paste(readLines(index, warn = FALSE), collapse = "\n")

  pattern <- sprintf(
    'href="([^"]*/%s-%s-[^"]*%s[^"]*\\.whl[^"]*)"',
    pypi_package, gsub(".", "\\.", version, fixed = TRUE), arch
  )
  m <- regmatches(html, regexec(pattern, html))[[1]]
  if (length(m) < 2L) {
    stop(sprintf(
      "Could not find wheel for %s==%s on %s",
      pypi_package, version, arch
    ), call. = FALSE)
  }
  href <- m[[2L]]

  url <- sub("#.*$", "", href)
  sha256 <- if (grepl("#sha256=", href, fixed = TRUE)) sub("^.*#sha256=", "", href) else NA_character_
  structure(url, sha256 = sha256)
}

verify_sha256 <- function(path, expected) {
  if (is.na(expected) || !exists("sha256sum", asNamespace("tools"))) {
    return(invisible(TRUE))
  }
  actual <- as.character(get("sha256sum", asNamespace("tools"))(path))
  if (!identical(tolower(actual), tolower(expected))) {
    stop(sprintf(
      "Checksum mismatch for %s: expected %s, got %s", basename(path), expected, actual
    ), call. = FALSE)
  }
  invisible(TRUE)
}

# Extract the `nvidia/<wheel_subdir>/<dir>/` trees from the wheel into `exdir`.
extract_wheel <- function(wheel, prefixes, exdir) {
  entries <- utils::unzip(wheel, list = TRUE, unzip = "internal")$Name
  for (prefix in prefixes) {
    files <- entries[startsWith(entries, prefix) & !endsWith(entries, "/")]
    if (!length(files)) {
      stop(sprintf("%s does not contain %s", basename(wheel), prefix), call. = FALSE)
    }
    utils::unzip(wheel, files = files, exdir = exdir, unzip = "internal", overwrite = TRUE)
  }
}

install_component <- function(spec, arch, home, tmpdir) {
  component <- spec$component
  pypi_package <- spec$pypi_package
  version <- spec$version
  subdir <- spec$wheel_subdir
  dirs <- strsplit(spec$extract, ",", fixed = TRUE)[[1]]

  message(sprintf("* Installing %s %s...", component, version))

  url <- find_wheel_url(pypi_package, version, arch, tmpdir)
  wheel <- file.path(tmpdir, basename(url))
  message("  Downloading ", basename(url), "...")
  download(url, wheel, quiet = !interactive())
  on.exit(unlink(wheel), add = TRUE)
  verify_sha256(wheel, attr(url, "sha256"))

  extract_wheel(wheel, sprintf("nvidia/%s/%s/", subdir, dirs), home)

  component_dir <- file.path(home, "nvidia", subdir)

  # Move shared libraries into the unified lib directory
  wheel_lib <- file.path(component_dir, "lib")
  if (dir.exists(wheel_lib)) {
    libs <- list.files(wheel_lib, full.names = TRUE, all.files = TRUE, no.. = TRUE)
    libs <- libs[basename(libs) != "__init__.py"]
    ok <- file.rename(libs, file.path(home, "lib", basename(libs)))
    if (!all(ok)) {
      stop(sprintf("Failed to move libraries of %s into %s", component, file.path(home, "lib")), call. = FALSE)
    }
    unlink(wheel_lib, recursive = TRUE)
  }

  # Ensure binaries are executable (for nvcc/ptxas)
  if ("bin" %in% dirs) {
    bins <- list.files(file.path(component_dir, "bin"), full.names = TRUE, recursive = TRUE)
    Sys.chmod(bins, "0755")
  }

  message("  Done.")
}

# ---- RUNPATH patching -------------------------------------------------------

# Returns the path to a patchelf binary, downloading NVIDIA-independent
# static builds from PyPI when none is on the PATH. Errors if that fails.
find_patchelf <- function(arch, tmpdir) {
  bin <- Sys.which("patchelf")
  if (nzchar(bin)) {
    return(unname(bin))
  }
  dir <- file.path(tmpdir, "patchelf")
  dir.create(dir, showWarnings = FALSE)
  wheel <- file.path(dir, "patchelf.whl")
  download(PATCHELF_URLS[[arch]], wheel)
  entry <- sprintf("patchelf-%s.data/scripts/patchelf", PATCHELF_VERSION)
  utils::unzip(wheel, files = entry, exdir = dir, unzip = "internal")
  bin <- file.path(dir, entry)
  Sys.chmod(bin, "0755")
  bin
}

# Patch RUNPATH so each .so resolves dependencies from its own directory
# first, preventing LD_LIBRARY_PATH from pulling in wrong versions (e.g. a
# cluster module's older cuDNN). `--force-rpath` writes DT_RPATH, which takes
# precedence over LD_LIBRARY_PATH.
patch_rpath <- function(lib_dir, arch, tmpdir) {
  patchelf <- tryCatch(find_patchelf(arch, tmpdir), error = function(e) NULL)
  if (is.null(patchelf)) {
    warning(
      "Could not obtain patchelf, skipping RUNPATH patching. ",
      "Install patchelf for reliable CUDA library loading when ",
      "LD_LIBRARY_PATH contains other CUDA installations.",
      call. = FALSE
    )
    return(invisible(FALSE))
  }

  message("* Patching RPATH with $ORIGIN...")
  sos <- list.files(lib_dir, pattern = "\\.so(\\.|$)", full.names = TRUE)
  for (so in sos) {
    suppressWarnings(system2(
      patchelf,
      c("--force-rpath", "--add-rpath", shQuote("$ORIGIN"), shQuote(so)),
      stdout = FALSE, stderr = FALSE
    ))
  }
  message("  Done.")
  invisible(TRUE)
}

# ---- load-time installation -------------------------------------------------

# Called from .onLoad(): download the CUDA components on first load. This
# mirrors how pjrt handles its plugin downloads (and shares the PJRT_INSTALL
# environment variable):
#   - PJRT_INSTALL=1  download without asking (CI, scripts, Docker builds)
#   - PJRT_INSTALL=0  never download
#   - unset           ask in an interactive session, do nothing otherwise
# Apart from a failing download, this never errors, so the namespace always
# loads; the path accessors error with instructions if the components are
# missing.
maybe_install_cuda <- function() {
  if (cuda_installed()) {
    return(invisible(FALSE))
  }

  problem <- platform_problem()
  if (!is.null(problem)) {
    packageStartupMessage(problem)
    return(invisible(FALSE))
  }

  install <- Sys.getenv("PJRT_INSTALL", "")
  if (install == "0") {
    return(invisible(FALSE))
  }
  if (install == "1") {
    install_cuda()
    return(invisible(TRUE))
  }

  hint <- "Run `pjrt.cuda::install_cuda()` or set the environment variable PJRT_INSTALL=1 to install them."

  if (!interactive()) {
    packageStartupMessage(
      "The CUDA components used by pjrt.cuda are not installed and automatic ",
      "downloads are not performed in non-interactive sessions. ", hint
    )
    return(invisible(FALSE))
  }

  packageStartupMessage(
    "The CUDA components used by pjrt.cuda need to be downloaded from PyPI ",
    "(several GB) and installed in ", cuda_home(), ".\n",
    "Set the environment variable PJRT_INSTALL=1 to skip this prompt in the future."
  )
  response <- utils::askYesNo("Do you want to download them now?")
  if (!isTRUE(response)) {
    packageStartupMessage("Download declined. ", hint)
    return(invisible(FALSE))
  }
  install_cuda()
  invisible(TRUE)
}
