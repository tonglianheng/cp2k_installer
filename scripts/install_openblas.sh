#!/bin/bash -e
[ "${BASH_SOURCE[0]}" ] && SCRIPT_NAME="${BASH_SOURCE[0]}" || SCRIPT_NAME=$0
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_NAME")" && pwd -P)"

source "${SCRIPT_DIR}"/common_vars.sh
source "${SCRIPT_DIR}"/package_versions.sh
source "${SCRIPT_DIR}"/tool_kit.sh

with_openblas=${1:-__INSTALL__}

OPENBLAS_CFLAGS=''
OPENBLAS_LDFLAGS=''
OPENBLAS_LIBS=''
! [ -d "${BUILDDIR}" ] && mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"
case "$with_openblas" in
    __INSTALL__)
        echo "==================== Installing OpenBLAS ===================="
        pkg_install_dir="${INSTALLDIR}/openblas-${openblas_ver}"
        install_lock_file="$pkg_install_dir/install_successful"
        if [ -f "${install_lock_file}" ] ; then
            echo "openblas-${openblas_ver} is already installed, skipping it."
        else
            if [ -f openblas-${openblas_ver}.tar.gz ] ; then
                echo "openblas-${openblas_ver}.tar.gz is found"
            else
                download_pkg ${DOWNLOADER_FLAGS} \
                             https://www.cp2k.org/static/downloads/xianyi-OpenBLAS-${openblas_ver}.zip
            fi
            echo "Installing from scratch into ${pkg_install_dir}"
            unzip xianyi-OpenBLAS-${openblas_ver}.zip >& unzip.log
            cd xianyi-OpenBLAS-*
            # Originally we try to install both the serial and the omp
            # threaded version. Unfortunately, neither is thread-safe
            # (i.e. the CP2K ssmp and psmp version need to link to
            # something else, the omp version is unused)
            make -j $NPROCS \
                 USE_THREAD=0 \
                 PREFIX="${pkg_install_dir}" \
                 >& make.serial.log
            make -j $NPROCS \
                 USE_THREAD=0 \
                 PREFIX="${pkg_install_dir}" \
                 install >& install.serial.log
            # make clean >& clean.log
            # make -j $nprocs \
            #      USE_THREAD=1 \
            #      USE_OPENMP=1 \
            #      LIBNAMESUFFIX=omp \
            #      PREFIX="${pkg_install_dir}" \
            #      >& make.omp.log
            # make -j $nprocs \
            #      USE_THREAD=1 \
            #      USE_OPENMP=1 \
            #      LIBNAMESUFFIX=omp \
            #      PREFIX="${pkg_install_dir}" \
            #      install >& install.omp.log
            cd ..
            touch "${install_lock_file}"
        fi
        OPENBLAS_CFLAGS="-I\"${pkg_install_dir}/include\""
        OPENBLAS_LDFLAGS="-L\"${pkg_install_dir}/lib\" -Wl,-rpath=\"${pkg_install_dir}/lib\""
        ;;
    __SYSTEM__)
        echo "==================== Finding LAPACK from system paths ===================="
        check_lib -lopenblas "OpenBLAS"
        add_include_from_paths OPENBLAS_CFLAGS "openblas_config.h" $INCLUDE_PATHS
        add_lib_from_paths OPENBLAS_LDFLAGS "libopenblas.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        echo "==================== Linking LAPACK to user paths ===================="
        pkg_install_dir="$with_openblas"
        check_dir "${pkg_install_dir}/include"
        check_dir "${pkg_install_dir}/lib"
        OPENBLAS_CFLAGS="-I\"${pkg_install_dir}/include\""
        OPENBLAS_LDFLAGS="-L\"${pkg_install_dir}/lib\" -Wl,-rpath=\"${pkg_install_dir}/lib\""
        ;;
esac
if [ "$with_openblas" != "__DONTUSE__" ] ; then
    OPENBLAS_LIBS="-lopenblas"
    if [ "$with_openblas" != "__SYSTEM__" ] ; then
        cat <<EOF > "${BUIILDDIR}/setup_openblas"
prepend_path LD_LIBRARY_PATH "$pkg_install_dir/lib"
prepend_path LD_RUN_PATH "$pkg_install_dir/lib"
prepend_path LIBRARY_PATH "$pkg_install_dir/lib"
prepend_path CPATH "$pkg_install_dir/include"
EOF
        cat "${BUIILDDIR}/setup_openblas" >> $SETUPFILE
    fi
    cat <<EOF >> "${BUIILDDIR}/setup_openblas"
export OPENBLAS_CFLAGS="${OPENBLAS_CFLAGS}"
export OPENBLAS_LDFLAGS="${OPENBLAS_LDFLAGS}"
export OPENBLAS_LIBS="${OPENBLAS_LIBS}"
export FAST_MATH_CFLAGS="\$(unique \${FAST_MATH_CFLAGS} ${OPENBLAS_CFLAGS})"
export FAST_MATH_LDFLAGS="\$(unique \${FAST_MATH_LDFLAGS} ${OPENBLAS_LDFLAGS})"
export FAST_MATH_LIBS="\$(unique \${FAST_MATH_LIBS} ${OPENBLAS_LIBS})"
EOF
fi
cd "${ROOTDIR}"
