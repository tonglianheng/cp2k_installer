#!/bin/bash -e
[ "${BASH_SOURCE[0]}" ] && SCRIPT_NAME="${BASH_SOURCE[0]}" || SCRIPT_NAME=$0
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_NAME")" && pwd -P)"

source "${SCRIPT_DIR}"/common_vars.sh
source "${SCRIPT_DIR}"/package_versions.sh
source "${SCRIPT_DIR}"/tool_kit.sh

with_pexsi=${1:-__INSTALL__}

PEXSI_CFLAGS=''
PEXSI_LDFLAGS=''
PEXSI_LIBS=''
! [ -d "${BUILDDIR}" ] && mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"
case "$with_pexsi" in
    __INSTALL__)
        echo "==================== Installing PEXSI ===================="
        require_env PARMTEIS_LDFLAGS
        require_env PARMTEIS_LIBS
        require_env METIS_LDFLAGS
        require_env METIS_LIBS
        require_env SUPERLU_LDFLAGS
        require_env SUPERLU_LIBS
        require_env MATH_LDFLAGS
        require_env MATH_LIBS
        pkg_install_dir="${INSTALLDIR}/pexsi-${pexsi_ver}"
        install_lock_file="$pkg_install_dir/install_successful"
        if [ -f "${install_lock_file}" ] ; then
            echo "pexsi_dist-${pexsi_ver} is already installed, skipping it."
        else
            if [ -f pexsi_v${pexsi_ver}.tar.gz ] ; then
                echo "pexsi_v${pexsi_ver}.tar.gz is found"
            else
                download_pkg ${DOWNLOADER_FLAGS} \
                             https://www.cp2k.org/static/downloads/pexsi_v${pexsi_ver}.tar.gz
            fi
            echo "Installing from scratch into ${pkg_install_dir}"
            tar -xzf pexsi_v${pexsi_ver}.tar.gz
            cd pexsi_v${pexsi_ver}
            cat config/make.inc.linux.gnu | \
                sed -e "s|\(PAR_ND_LIBRARY *=\).*|\1 parmetis|" \
                    -e "s|\(SEQ_ND_LIBRARY *=\).*|\1 metis|" \
                    -e "s|\(PEXSI_DIR *=\).*|\1 ${PWD}|" \
                    -e "s|\(CPP_LIB *=\).*|\1 -lstdc++ -lmpi_cxx |" \
                    -e "s|\(LAPACK_LIB *=\).*|\1 ${MATH_LDFLAGS} ${MATH_LIBS}|" \
                    -e "s|\(BLAS_LIB *=\).*|\1|" \
                    -e "s|\(\bMETIS_LIB *=\).*|\1 ${METIS_LDFLAGS} ${METIS_LIBS}|" \
                    -e "s|\(PARMETIS_LIB *=\).*|\1 ${PARMETIS_LDFLAGS} ${PARMETIS_LIBS}|" \
                    -e "s|\(DSUPERLU_LIB *=\).*|\1 ${SUPERLU_LDFLAGS} ${SUPERLU_LIBS}|" \
                    -e "s|\(SCOTCH_LIB *=\).*|\1 ${SCOTCH_LDFLAGS} -lscotchmetis -lscotch -lscotcherr|" \
                    -e "s|\(PTSCOTCH_LIB *=\).*|\1 ${SCOTCH_LDFLAGS} -lptscotchparmetis -lptscotch -lptscotcherr -lscotch|" \
                    -e "s|#FLOADOPTS *=.*|FLOADOPTS    = \${LIBS} \${CPP_LIB}|" \
                    -e "s|\(DSUPERLU_INCLUDE *=\).*|\1 ${SUPERLU_CFLAGS}|" \
                    -e "s|\(INCLUDES *=\).*|\1 ${METIS_CFLAGS} ${PARMETIS_CFLAGS} ${MATH_CFLAGS} \${DSUPERLU_INCLUDE} \${PEXSI_INCLUDE}|" \
                    -e "s|\(COMPILE_FLAG *=\).*|\1 ${CFLAGS} -fpermissive|" \
                    -e "s|\(SUFFIX *=\).*|\1|" \
                    -e "s|\(DSUPERLU_DIR *=\).*|\1|" \
                    -e "s|\(METIS_DIR *=\).*|\1|" \
                    -e "s|\(PARMETIS_DIR *=\).*|\1|" \
                    -e "s|\(PTSCOTCH_DIR *=\).*|\1|" \
                    -e "s|\(LAPACK_DIR *=\).*|\1|" \
                    -e "s|\(BLAS_DIR *=\).*|\1|" \
                    -e "s|\(GFORTRAN_LIB *=\).*|\1|" > make.inc
            cd src
            make -j $NPROCS >& make.log
            # no make install, need to do install manually
            chmod a+r libpexsi.a
            ! [ -d "${pkg_install_dir}/lib" ] && mkdir -p "${pkg_install_dir}/lib"
            cp libpexsi_linux.a "${pkg_install_dir}/lib"
            # make fortran interface
            cd ../fortran
            make >& make.log #-j $nprocs will crash
            chmod a+r f_ppexsi_interface.mod
            ! [ -d "${pkg_install_dir}/include" ] && mkdir -p "${pkg_install_dir}/include"
            cp f_ppexsi_interface.mod "${pkg_install_dir}/include"
            cd ..
            cp include/* "${pkg_install_dir}/include"
            cd ..
            touch "${install_lock_file}"
        fi
        PEXSI_CFLAGS="-I'${pkg_install_dir}/include'"
        PEXSI_LDFLAGS="-L'${pkg_install_dir}/lib' -Wl,-rpath='${pkg_install_dir}/lib'"
        ;;
    __SYSTEM__)
        echo "==================== Finding Pexsi_DIST from system paths ===================="
        check_lib -lpexsi "PEXSI"
        # add_include_from_paths PEXSI_CFLAGS "pexsi*" $INCLUDE_PATHS
        add_lib_from_paths PEXSI_LDFLAGS "libpexsi.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        echo "==================== Linking Pexsi_Dist to user paths ===================="
        pkg_install_dir="$with_pexsi"
        check_dir "${pkg_install_dir}/lib"
        check_dir "${pkg_install_dir}/include"
        PEXSI_CFLAGS="-I'${pkg_install_dir}/include'"
        PEXSI_LDFLAGS="-L'${pkg_install_dir}/lib' -Wl,-rpath='${pkg_install_dir}/lib'"
        ;;
esac
if [ "$with_pexsi" != "__DONTUSE__" ] ; then
    [ -f "${BUILDDIR}/setup_pexsi" ] && rm "${BUILDDIR}/setup_pexsi"
    PEXSI_LIBS="-lpexsi"
    if [ "$with_pexsi" != "__SYSTEM__" ] ; then
        cat <<EOF > "${BUILDDIR}/setup_pexsi"
prepend_path LD_LIBRARY_PATH "$pkg_install_dir/lib"
prepend_path LD_RUN_PATH "$pkg_install_dir/lib"
prepend_path LIBRARY_PATH "$pkg_install_dir/lib"
prepend_path CPATH "$pkg_install_dir/include"
EOF
        cat "${BUILDDIR}/setup_pexsi" >> $SETUPFILE
    fi
    cat <<EOF >> "${BUILDDIR}/setup_pexsi"
export PEXSI_CFLAGS="${PEXSI_CFLAGS}"
export PEXSI_LDFLAGS="${PEXSI_LDFLAGS}"
export PEXSI_LIBS="${PEXSI_LIBS}"
export CP_DFLAGS="\${CP_DFLAGS} IF_MPI(-D__LIBPEXSI,)"
export CP_CFLAGS="\${CP_CFLAGS} IF_MPI(${PEXSI_CFLAGS},)"
export CP_LDFLAGS="\${CP_LDFLAGS} IF_MPI(\"${PEXSI_LDFLAGS}\",)"
export CP_LIBS="IF_MPI(${PEXSI_LIBS},) \${CP_LIBS}"
EOF
fi
cd "${ROOTDIR}"