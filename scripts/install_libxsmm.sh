#!/bin/bash -e
[ "${BASH_SOURCE[0]}" ] && SCRIPT_NAME="${BASH_SOURCE[0]}" || SCRIPT_NAME=$0
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_NAME")" && pwd -P)"

source "${SCRIPT_DIR}"/common_vars.sh
source "${SCRIPT_DIR}"/package_versions.sh
source "${SCRIPT_DIR}"/tool_kit.sh

with_libxsmm=${1:-__INSTALL__}

LIBXSMM_CFLAGS=''
LIBXSMM_LDFLAGS=''
LIBXSMM_LIBS=''
! [ -d "${BUILDDIR}" ] && mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"
case "$with_libxsmm" in
    __INSTALL__)
        echo "==================== Installing Libxsmm ===================="
        if [ "$OPENBLAS_ARCH" != "x86_64" ] ; then
            report_warning $LINENO "libxsmm not suported on arch ${OPENBLAS_ARCH}"
            cat <<EOF > "${BUILDDIR}/setup_libxsmm"
with_libxsmm="__DONTUSE__"
EOF
            exit 0
        fi
        pkg_install_dir="${INSTALLDIR}/libxsmm-${libxsmm_ver}"
        install_lock_file="$pkg_install_dir/install_successful"
        if [ -f "${install_lock_file}" ] ; then
            echo "libxsmm-${libxsmm_ver} is already installed, skipping it."
        else
            if [ "$libxsmm_ver" = "master" ] ; then
                download_pkg ${DOWNLOADER_FLAGS} \
                             https://github.com/hfp/libxsmm/archive/master.zip
                mv master.zip libxsmm-master.zip
                unzip libxsmm-master.zip  >& libxsmm-unzip.log
            else
                if [ -f libxsmm-${libxsmm_ver}.tar.gz ] ; then
                    echo "libxsmm-${libxsmm_ver}.tar.gz is found"
                else
                    download_pkg ${DOWNLOADER_FLAGS} \
                                 https://www.cp2k.org/static/downloads/libxsmm-${libxsmm_ver}.tar.gz
                    tar -xzf libxsmm-${libxsmm_ver}.tar.gz
                fi
            fi
            echo "Installing from scratch into ${pkg_install_dir}"
            # choose which math library should libxsmm use as a
            # fall-back option, currently libxsmm make supports
            # openblas, mkl or system lapack. We will just use
            # reflapack in place of the system lapack here.
            case $FAST_MATH_MODE in
                openblas)
                    require_env OPENBLAS_LDFLAGS
                    openblas_flag=1
                    mkl_flag=0
                    # find possible openblas lib and record its suffix if exists
                    blas_threads="$(find_in_paths "libopenblas*.*" $LIB_PATHS)"
                    blas_threads="${blas_threads#*libopenblas}"
                    blas_threads="${blas_threads%%.*}"
                    ;;
                mkl)
                    # mkl exists if MKLROOT is set, and libxsmm make
                    # only recognizes MKLROOT
                    require_env MKLROOT
                    mkl_flag=1
                    openblas_flag=0
                    ;;
                *)
                    # check reflapack. reflapack exists if
                    # REFLAPACK_LDFLAGS is set
                    require_env REFLAPACK_LDFLAGS
                    openblas_flag=0
                    mkl_flag=0
                    blas_threads=''
                    ;;
            esac
            # note that we do not have to set -L flags to ld for the
            # linked math libraries for the libxsmm build, as for a
            # library this is not required, you just have to provide
            # the appropriate -L flags (LDFLAGS) during the linking
            # stage of building an executable that uses the libxsmm
            # library
            cd libxsmm-${libxsmm_ver}
            # we rely on the jit, but as it is not available for SSE,
            # we also generate a subset statically.
            make -j $NPROCS \
                 CXX=g++ \
                 CC=gcc \
                 FC=gfortran \
                 MNK="1 4 5 6 8 9 13 16 17 22 23 24 26 32" \
                 SSE=1 \
                 JIT=1 \
                 PREFETCH=1 \
                 MKL=${mkl_flag} \
                 OPENBLAS=${openblas_flag} \
                 BLAS_THREADS=${blas_threads} \
                 PREFIX=${pkg_install_dir} \
                 >& make.log
            make -j $NPROCS \
                 CXX=g++ \
                 CC=gcc \
                 FC=gfortran \
                 MNK="1 4 5 6 8 9 13 16 17 22 23 24 26 32" \
                 SSE=1 \
                 JIT=1 \
                 PREFETCH=1 \
                 MKL=${mkl_flag} \
                 OPENBLAS=${openblas_flag} \
                 BLAS_THREADS=${blas_threads} \
                 PREFIX=${pkg_install_dir} \
                 install >& install.log
            cd ..
            touch "${install_lock_file}"
        fi
        LIBXSMM_CFLAGS="-I'${pkg_install_dir}/include'"
        LIBXSMM_LDFLAGS="-L'${pkg_install_dir}/lib' -Wl,-rpath='${pkg_install_dir}/lib'"
        ;;
    __SYSTEM__)
        echo "==================== Finding Libxsmm from system paths ===================="
        check_command libxsmm_generator "libxsmm"
        check_lib -lxsmm "libxsmm"
        add_include_from_paths LIBXSMM_CFLAGS "libxsmm.h" $INCLUDE_PATHS
        add_lib_from_paths LIBXSMM_LDFLAGS "libxsmm.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        echo "==================== Linking Libxsmm to user paths ===================="
        pkg_install_dir="$with_libxsmm"
        check_dir "${pkg_install_dir}/bin"
        check_dir "${pkg_install_dir}/include"
        check_dir "${pkg_install_dir}/lib"
        LIBXSMM_CFLAGS="-I'${pkg_install_dir}/include'"
        LIBXSMM_LDFLAGS="-L'${pkg_install_dir}/lib' -Wl,-rpath='${pkg_install_dir}/lib'"
        ;;
esac
if [ "$with_libxsmm" != "__DONTUSE__" ] ; then
    [ -f "${BUILDDIR}/setup_libxsmm" ] && rm "${BUILDDIR}/setup_libxsmm"
    LIBXSMM_LIBS="-lxmm"
    if [ "$with_libxsmm" != "__SYSTEM__" ] ; then
        cat <<EOF > "${BUILDDIR}/setup_libxsmm"
prepend_path PATH "${pkg_install_dir}/bin"
prepend_path LD_LIBRARY_PATH "${pkg_install_dir}/lib"
prepend_path LD_RUN_PATH "${pkg_install_dir}/lib"
prepend_path LIBRARY_PATH "${pkg_install_dir}/lib"
EOF
        cat "${BUILDDIR}/setup_libxsmm" >> $SETUPFILE
    fi
    cat <<EOF >> "${BUILDDIR}/setup_libxsmm"
export LIBXSMM_CFLAGS="${LIBXSMM_CFLAGS}"
export LIBXSMM_LDFLAGS="${LIBXSMM_LDFLAGS}"
export LIBXSMM_LIBS="${LIBXSMM_LIBS}"
export CP_DFLAGS="-D__LIBXSMM \${CP_DFLAGS}"
export CP_CFLAGS="\${CP_CFLAGS} ${LIBXSMM_CFLAGS}"
export CP_LDFLAGS="\${CP_LDFLAGS} ${LIBXSMM_LDFLAGS}"
export CP_LIBS="-lxsmm \${CP_LIBS}"
EOF
fi
cd "${ROOTDIR}"
