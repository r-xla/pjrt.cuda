#' @section Environment Variables:
#' * `PJRT_CUDA_COMPONENTS`: Comma-separated list of components to install
#'   at package installation time (default: all components), e.g.
#'   `"runtime,cublas,cudnn"`. A component's pinned version can be overridden
#'   with `@`, e.g. `"cudnn@9.10.0.56"`. Note that the `pjrt` CUDA backend
#'   requires all components to be present.
#'
#' @section Third-Party Licenses:
#' The `pjrt.cuda` package itself is MIT-licensed. It does not bundle NVIDIA
#' software; instead it downloads NVIDIA's official redistributable binaries
#' from PyPI at install time. Their use is governed by the
#' [NVIDIA CUDA Toolkit EULA](https://docs.nvidia.com/cuda/eula/), with the
#' exception of cuDNN, which is covered by the
#' [NVIDIA cuDNN SLA](https://docs.nvidia.com/deeplearning/cudnn/sla/index.html),
#' and NCCL, which is covered by its
#' [own license](https://github.com/NVIDIA/nccl/blob/master/LICENSE.txt).
#' By installing this package you accept those terms.
"_PACKAGE"
