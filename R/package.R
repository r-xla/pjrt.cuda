#' @section Installation of the CUDA components:
#' The package itself is lightweight. The CUDA components (several GB) are
#' downloaded from PyPI into [cuda_home()] the first time the package is
#' loaded, or when [install_cuda()] is called. Whether loading the package may
#' download them is controlled by the environment variable `PJRT_INSTALL`,
#' which is shared with the `pjrt` package:
#' * `PJRT_INSTALL=1`: download without asking (e.g. CI, scripts, Docker builds).
#' * `PJRT_INSTALL=0`: never download.
#' * unset: ask for confirmation in an interactive session, do nothing in a
#'   non-interactive one.
#'
#' @section Environment Variables:
#' * `PJRT_INSTALL`: Whether loading the package may download the CUDA
#'   components, see above.
#' * `PJRT_CUDA_HOME`: Directory in which the CUDA components are installed.
#'   Defaults to `tools::R_user_dir("pjrt.cuda", "cache")`.
#' * `PJRT_CUDA_COMPONENTS`: Comma-separated list of components to install
#'   (default: all components), e.g. `"runtime,cublas,cudnn"`. A component's
#'   pinned version can be overridden with `@`, e.g. `"cudnn@9.10.0.56"`.
#'   Note that the `pjrt` CUDA backend requires all components to be present.
#'
#' @section Third-Party Licenses:
#' The `pjrt.cuda` package itself is MIT-licensed. It does not bundle NVIDIA
#' software; instead it downloads NVIDIA's official redistributable binaries
#' from PyPI. Their use is governed by the
#' [NVIDIA CUDA Toolkit EULA](https://docs.nvidia.com/cuda/eula/), with the
#' exception of cuDNN, which is covered by the
#' [NVIDIA cuDNN SLA](https://docs.nvidia.com/deeplearning/cudnn/sla/index.html),
#' and NCCL, which is covered by its
#' [own license](https://github.com/NVIDIA/nccl/blob/master/LICENSE.txt).
#' By downloading them you accept those terms.
"_PACKAGE"
