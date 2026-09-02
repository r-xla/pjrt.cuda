# pjrt.cuda

Provides the CUDA 13.3 native libraries required by the CUDA PJRT plugin used
by the [pjrt](https://github.com/r-xla/pjrt) package. The package itself is
lightweight — all CUDA components are downloaded as NVIDIA's official
redistributable binaries from PyPI the first time the package is loaded.

The component set is what `libpjrt_cuda.so` (from
[zml/pjrt-artifacts](https://github.com/zml/pjrt-artifacts)) links against,
plus what pjrt itself needs at runtime: `nvcc` (for `ptxas`) and `nvvm` (for
`libdevice`), which XLA uses to compile PTX, and `cusolver`, which pjrt's
linalg custom calls dlopen:

runtime, cublas, cupti, nvrtc, cufft, cusolver, cusparse, nvjitlink, nvcc,
nvvm, cudnn, nccl

Adapted from [mlverse/cudatoolkit](https://github.com/mlverse/cudatoolkit).

## Installation

Users of `pjrt` do not install this package directly — `pjrt::install_pjrt()`
installs it automatically when a CUDA-capable GPU is detected. To install it
manually:

```r
install.packages("pjrt.cuda", repos = "https://r-xla.r-universe.dev")
```

Installing the package does not download anything. The CUDA components
(several GB) are fetched into `pjrt.cuda::cuda_home()` — by default
`tools::R_user_dir("pjrt.cuda", "cache")`, or `PJRT_CUDA_HOME` if set — the
first time the package is loaded:

```r
Sys.setenv(PJRT_INSTALL = "1")
loadNamespace("pjrt.cuda")
# or, equivalently
pjrt.cuda::install_cuda()
```

Whether loading the package may download the components is controlled by the
`PJRT_INSTALL` environment variable, which is shared with `pjrt`:

- `PJRT_INSTALL=1`: download without asking (e.g. CI, scripts, Docker builds).
- `PJRT_INSTALL=0`: never download.
- unset: ask for confirmation in an interactive session, do nothing in a
  non-interactive one.

The components are re-downloaded when the pinned versions change (e.g. after
updating the package) or the selected components change.

### Installing specific components

By default, all components are installed. Set the `PJRT_CUDA_COMPONENTS`
environment variable to install only what you need, optionally overriding a
component's pinned version with `@`:

```r
Sys.setenv(PJRT_CUDA_COMPONENTS = "runtime,cublas,cudnn@9.10.0.56")
pjrt.cuda::install_cuda()
```

Note that the `pjrt` CUDA backend requires all components.

## Usage

```r
# Installation root of all components
pjrt.cuda::cuda_home()

# Directory containing all shared libraries (*.so)
pjrt.cuda::lib_path()

# Installation root of a component (e.g. nvcc, containing bin/ptxas and
# nvvm/libdevice)
pjrt.cuda::cuda_path("nvcc")

# Component headers and binaries
pjrt.cuda::include_path("cudnn")
pjrt.cuda::bin_path("nvcc")
```

## Supported platforms

Linux x86_64 and aarch64 only — the CUDA PJRT plugin is not published for
other platforms. An NVIDIA driver (`libcuda.so.1`) new enough for CUDA 13
must be present at runtime; it is not part of this package.

## Updating component versions

The pinned versions live in `inst/components.tsv`. They must stay compatible
with the PJRT plugin version that `pjrt` downloads; in particular `nvrtc` is
pinned to the exact CUDA minor version the plugin was built against (the
plugin links `libnvrtc-builtins.so.<major>.<minor>`). When bumping the plugin
version in `pjrt`, check its `NEEDED` entries:

```sh
readelf -d libpjrt_cuda.so | grep NEEDED
```

## License

The package code is MIT-licensed. The downloaded NVIDIA binaries are governed
by the [NVIDIA CUDA Toolkit EULA](https://docs.nvidia.com/cuda/eula/), the
[NVIDIA cuDNN SLA](https://docs.nvidia.com/deeplearning/cudnn/sla/index.html)
for cuDNN, and NCCL's
[own license](https://github.com/NVIDIA/nccl/blob/master/LICENSE.txt).
