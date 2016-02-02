#!/bin/bash -e

# directories and files used by the installer
ROOTDIR=${ROOTDIR:-"$(pwd -P)"}
SCRIPTDIR=${SCRIPTDIR:-"${ROOTDIR}/scripts"}
INSTALLDIR=${INSTALLDIR:-"${ROOTDIR}/install"}
BUILDDIR=${BUILDDIR:-"${ROOTDIR}/build"}
SETUPFILE=${SETUPFILE:-"${INSTALLDIR}/setup"}
SHA256_CHECKSUMS=${SHA256_CHECKSUMS:-"${SCRIPTDIR}/checksums.sha256"}
ARCH_FILE_TEMPLATE=${ARCH_FILE_TEMPLATE:-"${SCRIPTDIR}/arch.tmpl"}

# downloader flags, used for downloading tarballs
DOWNLOADER_FLAGS="${DOWNLOADER_FLAGS:-}"

# system arch gotten from OpenBLAS prebuild
OPENBLAS_ARCH=${OPENBLAS_ARCH:-"x86_64"}
OPENBLAS_LIBCORE=${OPENBLAS_LIBCORE:-''}

# search paths
SYS_INCLUDE_PATH=${SYS_INCLUDE_PATH:-'/usr/local/include:/usr/include'}
SYS_LIB_PATH=${SYS_LIB_PATHS:-'/usr/local/lib64:/usr/local/lib:/usr/lib64:/usr/lib:/lib64:/lib'}
INCLUDE_PATHS=${INCLUDE_PATHS:-"CPATH SYS_INCLUDE_PATH"}
LIB_PATHS=${LIB_PATHS:-'LD_LIBRARY_PATH LIBRARY_PATH LD_RUN_PATH SYS_LIB_PATH'}

# number of processors
NPROCS=${NPROCS:-1}

# mode flags
ENABLE_OMP=${ENABLE_OMP:-"__TRUE__"}
ENABLE_TSAN=${ENABLE_TSAN:-"__FALSE__"}
ENABLE_VALGRIND=${ENABLE_VALGRIND:-"__FALSE__"}
ENABLE_CUDA=${ENABLE_CUDA:-"__FALSE__"}
MPI_MODE=${MPI_MODE:-"openmpi"}
FAST_MATH_MODE=${FAST_MATH_MODE:-openblas}
