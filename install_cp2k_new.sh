#!/bin/bash -e
[ "${BASH_SOURCE[0]}" ] && SCRIPT_NAME="${BASH_SOURCE[0]}" || SCRIPT_NAME=$0
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_NAME")" && pwd -P)"

source "${SCRIPT_DIR}"/scripts/common_vars.sh
source "${SCRIPT_DIR}"/scripts/package_versions.sh
source "${SCRIPT_DIR}"/scripts/tool_kit.sh

# macro for display help
show_help() {
    cat<<EOF
This script will help you compile and install, or link libraries
CP2K depends on and setup a set of ARCH files that you can use
to compile CP2K.

USAGE:

$(basename $script_name) [options]

OPTIONS:

-h, --help                Show this message

The --enable-FEATURE options follow the rules:
  --enable-FEATURE=yes    Enable this particular feature
  --enable-FEATHRE=no     Disable this particular feature
  --enable-FEATURE        The option keyword alone is equivalent to
                          --enable-FEATURE=yes

  --enable-toochain       Sets all --with-PKG to install
  --enable-tsan           If you are installing GCC using this script
                          this option enables thread sanitizer support.
                          This is only relevant for debugging purposes.
                          Default = no
  --enable-gcc-master     If you are installing GCC using this script
                          this option forces the master development version/
                          Default = no
  --enable-omp            Turn on OpenMP (threaded) support.
                          Default = yes
  --enable-cuda           Turn on GPU (CUDA) support.
                          Default = no

The --with-PKG options follow the rules:
  --with-PKG=install      Will download the package in \$PWD/build and
                          install the library package in \$PWD/install.
  --with-PKG=system       The script will then try to find the required
                          libraries of the package from the system path
                          variables such as PATH, LD_LIBRARY_PATH and
                          CPATH etc.
  --with-PKG=no           Do not use the package.
  --with-PKG=<path>       The package will be assumed to be installed in
                          the given <path>, and be linked accordingly.
  --with-PKG              The option keyword alone will be equivalent to
                          --with-PKG=install

  --with-gcc              The GCC compiler to use to compile CP2K
                          Default = system
  --with-binutils         GNU binutils
                          Default = system
  --with-cmake            Cmake utilities, required for building ParMETIS
                          Default = no
  --with-valgrind         Valgrind memory debugging tool, only used for
                          debugging purposes.
                          Default = no
  --with-lcov             LCOV code coverage utility, mainly used by CP2K developers
                          Default = no
  --with-openmpi          OpenMPI, important if you want parallel version
                          of CP2K.
                          Default = system
  --with-mpich            MPICH, MPI library like OpenMPI. one should
                          only use EITHER OpenMPI or MPICH and not both.
                          Default = no
  --with-libxc            libxc, exchange-correlation library. Needed for
                          QuickStep DFT and hybrid calculations.
                          Default = install
  --with-libint           libint, library for evaluation of two-body molecular
                          integrals, needed for hybrid functional calculations
                          Default = install
  --with-fftw             FFTW3, library for fast fourier transform
                          Default = install
  --with-reflapack        Reference (vanilla) LAPACK and BLAS linear algebra libraries.
                          One should use only ONE linear algebra library. This
                          one is really mostly used for debugging purposes as it is
                          non-optimised.
                          Default = no
  --with-acml             AMD core maths library, which provides LAPACK and BLAS
                          Default = no
  --with-mkl              Intel maths kernel library, which provides LAPACK and BLAS,
                          and depending on your system, may also provide ScaLAPACK.
                          If the MKL version of ScaLAPACK is found, then it will replace
                          the one specified by --with-scalapack option.
                          Default = no
  --with-openblas         OpenBLAS is a free high performance LAPACK and BLAS library,
                          the sucessor to GotoBLAS.
                          Default = install
  --with-scalapack        Parallel linear algebra library, needed for parallel
                          calculations.
                          Default = install
  --with-libsmm           CP2K's own small matrix multiplication library. An optimised
                          libsmm should increase the code performance. If you set
                          --with-libsmm=install, then instead of actually compiling
                          the library (which may take a long time), the script will
                          try to download a preexisting version from the CP2K website
                          that is compatable with your system.
                          Default = install
  --with-elpa             Eigenvalue SoLvers for Petaflop-Applications library.
                          Fast library for large parallel jobs.
                          Default = no
  --with-ptscotch           PT-SCOTCH, only used if PEXSI is used
                          Default = no
  --with-parmetis         ParMETIS, and if --with-parmetis=install will also install
                          METIS, only used if PEXSI is used
                          Default = no
  --with-metis            METIS, --with-metis=install actuall does nothing, because
                          METIS is installed together with ParMETIS.  This option
                          is used to specify the METIS library if it is pre-installed
                          else-where. Only used if PEXSI is used
                          Default = no
  --with-superlu          SuperLU DIST, used only if PEXSI is used
                          Default = no
  --with-pexsi            Enable interface to PEXSI library
                          Default = no
  --with-quip             Enable interface to QUIP library
                          Default = no
EOF
}

# default settings
enable_toolchain=__FALSE__
enable_tsan=__FALSE__
enable_gcc_master=__FALSE__
enable_libxsmm_master=__FALSE__
enable_omp=__TRUE__
enable_cuda=__FALSE__
with_gcc=__SYSTEM__
with_binutils=__SYSTEM__
with_cmake=__DONTUSE__
with_valgrind=__DONTUSE__
with_lcov=__DONTUSE__
with_libxc=__INSTALL__
with_libint=__INSTALL__
with_fftw=__INSTALL__
with_scalapack=__INSTALL__
with_libsmm=__INSTALL__
with_elpa=__DONTUSE__
with_ptscotch=__DONTUSE__
with_parmetis=__DONTUSE__
with_metis=__DONTUSE__
with_superlu=__DONTUSE__
with_pexsi=__DONTUSE__
with_quip=__DONTUSE__

# default math library settings, FAST_MATH_MODE picks the math library
# to use, and with_* defines the default method of installation if it
# is picked. Choices for FAST_MATH_MODE are: __REFLAPACK__, __ACML__,
# __MKL__, __OPENBLAS__ and __DONTUSE__
export FAST_MATH_MODE="__OPENBLAS__"
with_reflapack=__INSTALL__
with_acml=__SYSTEM__
with_mkl=__SYSTEM__
with_openblas=__INSTALL__

# default MPI library settins, MPI_MODE picks the MPI library to use,
# and with_* defines the default method of installation if it is picked.
# Choices for MPI_MODE are: __MPICH__, __OPENMPI__ and __DONTUSE__
export MPI_MODE="__MPICH__"
with_openmpi=__SYSTEM__
with_mpich=__SYSTEM__

# parse options
while [ $# -ge 1 ] ; do
    case $1 in
        --enable-toolchain*)
            enable_toolchain=$(read_enable $1)
            if [ $enable_toolchain = "__INVALID__" ] ; then
                echo "invalid value for --enable-toolchain, please use yes or no" >&2
                exit 1
            fi
            ;;
        --enable-tsan*)
            enable_tsan=$(read_enable $1)
            if [ $enable_tsan = "__INVALID__" ] ; then
                echo "invalid value for --enable-tsan, please use yes or no" >&2
                exit 1
            fi
            ;;
        --enable-gcc-master*)
            enable_gcc_master=$(read_enable $1)
            if [ $enable_gcc_master = "__INVALID__" ] ; then
                echo "invalid value for --enable-gcc-master, please use yes or no" >&2
                exit 1
            fi
            ;;
        --enable-omp*)
            enable_omp=$(read_enable $1)
            if [ $enable_omp = "__INVALID__" ] ; then
                echo "invalid value for --enable-omp, please use yes or no" >&2
                exit 1
            fi
            ;;
        --enable-cuda*)
            enable_cuda=$(read_enable $1)
            if [ $enable_cuda = "__INVALID__" ] ; then
                echo "invalid value for --enable-cuda, please use yes or no" >&2
                exit 1
            fi
            ;;
        --with-gcc*)
            with_gcc=$(read_with $1)
            ;;
        --with-binutils*)
            with_binutils=$(read_with $1)
            ;;
        --with-cmake*)
            with_cmake=$(read_with $1)
            ;;
        --with-lcov*)
            with_lcov=$(read_with $1)
            ;;
        --with-valgrind*)
            with_valgrind=$(read_with $1)
            ;;
        --with-openmpi*)
            with_openmpi=$(read_with $1)
            if [ "$with_openmpi" != "__DONTUSE__" ] ; then
                export MPI_MODE="__OPENMPI__"
            fi
            ;;
        --with-mpich*)
            with_mpich=$(read_with $1)
            if [ "$with_mpich" != "__DONTUSE__" ] ; then
                export MPI_MODE="__MPICH__"
            fi
            ;;
        --with-libint*)
            with_libint=$(read_with $1)
            ;;
        --with-libxc*)
            with_libxc=$(read_with $1)
            ;;
        --with-fftw*)
            with_fftw=$(read_with $1)
            ;;
        --with-reflapack*)
            with_reflapack=$(read_with $1)
            ;;
        --with-mkl*)
            with_mkl=$(read_with $1)
            if [ "$with_mkl" != "__DONTUSE__" ] ; then
                export FAST_MATH_MODE="__MKL__"
            fi
            ;;
        --with-acml*)
            with_acml=$(read_with $1)
            if [ "$with_mkl" != "__DONTUSE__" ] ; then
                export FAST_MATH_MODE="__ACML__"
            fi
            ;;
        --with-openblas*)
            with_openblas=$(read_with $1)
            if [ "$with_mkl" != "__DONTUSE__" ] ; then
                export FAST_MATH_MODE="__OPENBLAS__"
            fi
            ;;
        --with-scalapack*)
            with_scalapack=$(read_with $1)
            ;;
        --with-libsmm*)
            with_libsmm=$(read_with $1)
            ;;
        --with-elpa*)
            with_elpa=$(read_with $1)
            ;;
        --with-ptscotch*)
            with_ptscotch=$(read_with $1)
            ;;
        --with-parmetis*)
            with_parmetis=$(read_with $1)
            ;;
        --with-metis*)
            with_metis=$(read_with $1)
            ;;
        --with-superlu*)
            with_superlu=$(read_with $1)
            ;;
        --with-pexsi*)
            with_pexsi=$(read_with $1)
            ;;
        --with-quip*)
            with_quip=$(read_with $1)
            ;;
        *)
            show_help
            exit 0
            ;;
    esac
    shift
done

# consolidate settings after user input
export ENABLE_TSAN=$enable_tsan
export ENABLE_OMP=$enable_omp
export ENABLE_CUDA=$enable_cuda
[ "$enable_gcc_master" = "__TRUE__" ] && export gcc_ver=master
[ "$enable_libxsmm_master" = "__TRUE__" ] && export libxsmm_ver=master
[ "$with_valgrind" != "__DONTUSE__"  ] && export ENABLE_VALGRIND="__TRUE__"
# if [ "$enable_toolchain" = "__TRUE__" ] ; then
#     # use toolchain default settings
#     with_gcc=__SYSTEM__
#     with_binutils=__SYSTEM__
#     with_cmake=__DONTUSE__
#     with_valgrind=__DONTUSE__
#     with_lcov=__DONTUSE__
#     with_libxc=__INSTALL__
#     with_libint=__INSTALL__
#     with_fftw=__INSTALL__
#     with_scalapack=__INSTALL__
#     with_libsmm=__INSTALL__
#     with_elpa=__DONTUSE__
#     with_ptscotch=__DONTUSE__
#     with_parmetis=__DONTUSE__
#     with_metis=__DONTUSE__
#     with_superlu=__DONTUSE__
#     with_pexsi=__DONTUSE__
#     with_quip=__DONTUSE__



# ----------------------------------------------------------------------
# Check and solve known conflicts before installations proceed
# ----------------------------------------------------------------------

# GCC thread sanitizer conflicts
if [ $ENABLE_TSAN = "__TRUE__" ] ; then
    if [ "$with_openblas" != "__DONTUSE__" ] ; then
        echo "TSAN is enabled, canoot use openblas, we will use reflapack instead"
        with_openblas="__DONTUSE__"
        [ "$with_reflapack" = "__DONTUSE__" ] && with_reflapack="__INSTALL__"
        export FAST_MATH_MODE="__REFLAPACK__"
    fi
    echo "TSAN is enabled, canoot use libsmm"
    with_libsmm="__DONTUSE__"
fi

# valgrind conflicts
if [ "$ENABLE_VALGRIND" != "__TRUE__" ] ; then
    if [ "$with_reflapack" = "__DONTUSE__" ] ; then
        echo "reflapack is automatically installed when valgrind is enabled"
        with_reflapack="__INSTALL__"
    fi
fi

# check math library options
if [ "$FAST_MATH_MODE" = "__DONTUSE__" ] ; then
   report_error $LINENO "Must use a fast linear algebra library, currently supported for this installer are OpenBLAS, MKL and ACML."
   exit 1
fi
# enable_lapack="__FALSE__"
# lapack_option_list="$with_acml $with_mkl $with_openblas"
# for ii in $lapack_option_list ; do
#     if [ "$ii" != "__DONTUSE__" ] ; then
#         if [ $enable_lapack = "__FALSE__" ] ; then
#             enable_lapack="__TRUE__"
#         else
#             echo "Please use only one LAPACK library" >&2
#             exit 1
#         fi
#     fi
# done
# if [ $enable_lapack = "__FALSE__" ] ; then
#     echo "Must use one of the LAPACK libraries." >&2
#     exit 1
# fi

# mpi library conflicts
if [ "$MPI_MODE" = "__DONTUSE__" ] ; then
    ENABLE_MPI="__FALSE__"
else
    ENABLE_MPI="__TRUE__"
fi
export ENABLE_MPI
if [ $ENABLE_MPI = "__TRUE__" ] ; then
    # if gcc is installed, then mpi needs to be installed too
    if [ "$with_gcc" = "__INSTALL__" ] ; then
        echo "You have chosen to install GCC, therefore MPI libraries will have to be installed too"
        [ "$with_openmpi" != "__DONTUSE__" ] && with_openmpi="__INSTALL__"
        [ "$with_mpich" != "__DONTUSE__" ] && with_mpich="__INSTALL__"
    fi
else
    [ "$with_scalapack" != "__DONTUSE__"  ] && \
        echo "Not using MPI, so scalapack is disabled."
    with_scalapack="__DONTUSE__"
    [ "$with_elpa" != "__DONTUSE__" ] && \
        echo "Not using MPI, so ELPA is disabled."
    with_elpa="__DONTUSE__"
    [ "$with_pexi" != "__DONTUSE__" ] && \
        echo "Not using MPI, so PEXSI is disabled."
    with_pexsi="__DONTUSE__"
fi

# PESXI and its dependencies
if [ "$with_pexsi" = "__DONTUSE__" ] ; then
    if [ "$with_ptscotch" != "__DONTUSE__" ] ; then
        echo "Not using PEXSI, so PT-Scotch is disabled."
        with_ptscotch="__DONTUSE__"
    fi
    if [ "$with_parmetis" != "__DONTUSE__" ] ; then
        echo "Not using PEXSI, so ParMETIS is disabled."
        with_parmetis="__DONTUSE__"
    fi
    if [ "$with_metis" != "__DONTUSE__" ] ; then
        echo "Not using PEXSI, so METIS is disabled."
        with_metis="__DONTUSE__"
    fi
    if [ "$with_superlu" != "__DONTUSE__" ] ; then
        echo "Not using PEXSI, so SuperLU-DIST is disabled."
        with_superlu="__DONTUSE__"
    fi
elif [ "$with_pexsi" = "__INSTALL__" ] ; then
    [ "$with_ptscotch" = "__DONTUSE__" ] && with_ptscotch="__INSTALL__"
    [ "$with_parmetis" = "__DONTUSE__" ] && with_parmetis="__INSTALL__"
    [ "$with_superlu" = "__DONTUSE__" ] && with_superlu="__INSTALL__"
else
    if [ "$with_ptscotch" = "__DONTUSE__" ] ; then
        echo "For PEXSI to work you need a working PT-Scotch library" >&2
        echo "use --with-ptscotch option to specify if you wish to install" >&2
        echo "the library or specify its location." >&2
        exit 1
    fi
    if [ "$with_parmetis" = "__DONTUSE__" ] ; then
        echo "For PEXSI to work you need a working PARMETIS library" >&2
        echo "use --with-parmetis option to specify if you wish to install" >&2
        echo "the library or specify its location." >&2
        exit 1
    fi
    if [ "$with_metis" = "__DONTUSE__" ] ; then
        echo "For PEXSI to work you need a working METIS library" >&2
        echo "use --with-metis option to specify if you wish to install" >&2
        echo "the library or specify its location." >&2
        exit 1
    fi
    if [ "$with_superlu" = "__DONTUSE__" ] ; then
        echo "For PEXSI to work you need a working SuperLU-DIST library" >&2
        echo "use --with-superlu option to specify if you wish to install" >&2
        echo "the library or specify its location." >&2
        exit 1
    fi
fi
# ParMETIS requires cmake, it also installs METIS if it is chosen
# __INSTALL__ option
if [ "$with_parmetis" = "__INSTALL__" ] ; then
    [ "$with_cmake" = "__DONTUSE__" ] && with_cmake="__INSTALL__"
    with_metis="__INSTALL__"
fi

# ----------------------------------------------------------------------
# Preliminaries
# ----------------------------------------------------------------------
export ROOTDIR="${PWD}"
export SCRIPTDIR="${ROOTDIR}/scripts"
export BUILDDIR="${ROOTDIR}/build"
export INSTALLDIR="${ROOTDIR}/install"
export SETUPFILE="${INSTALLDIR}/setup"
export SHA256_CHECKSUM="${SCRIPTDIR}/checksums.sha256"
export ARCH_FILE_TEMPLATE="${SCRIPTDIR}/arch.tmpl"
export NPROCS=$(get_nprocs)

# mkdir -p "$BUILDDIR"
# mkdir -p "$INSTALLDIR"

# variables used for generating cp2k ARCH file
export CP_DFLAGS=''
export CP_LIBS=''
export CP_CFLAGS='IF_OMP(-fopenmp,)'
export CP_LDFLAGS="-Wl,--enable-new-dtags"

# ----------------------------------------------------------------------
# Start writing setup file
# ----------------------------------------------------------------------
cat <<EOF > "$SETUPFILE"
#!/bin/bash
prepend_path() {
    local __env_var=\$1
    local __path=\$2
    if eval [ x\"\\\$\$__env_var\" = x ] ; then
        eval \$__env_var=\"\$__path\"
        eval export \$__env_var
    elif ! eval [[ \"\\\$\$__env_var\" =~ '(^|:)'\"\$__path\"'(\$|:)' ]] ; then
        eval \$__env_var=\"\\\$__path:\\\$\$__env_var\"
        eval export \$__env_var
    fi
}
EOF

# ----------------------------------------------------------------------
# Installing tools required for building CP2K and associated libraries
# ----------------------------------------------------------------------

# set environment for compiling compilers and tools required for CP2K
# and libraries it depends on
export CC=${CC:-gcc}
export FC=${FC:-gfortran}
export F77=${F77:-gfortran}
export F90=${F90:-gfortran}
export CXX=${CXX:-g++}
export CFLAGS=${CFLAGS:-"-O2 -g -Wno-error"}
export FFLAGS=${FFLAGS:-"-O2 -g -Wno-error"}
export FCLAGS=${FCLAGS:-"-O2 -g -Wno-error"}
export F90FLAGS=${F90FLAGS:-"-O2 -g -Wno-error"}
export F77FLAGS=${F77FLAGS:-"-O2 -g -Wno-error"}
export CXXFLAGS=${CXXFLAGS:-"-O2 -g -Wno-error"}

./scripts/install_binutils.sh "${with_binutils}"; load "${BUILDDIR}/setup_binutils"
./scripts/install_cmake.sh    "${with_cmake}";    load "${BUILDDIR}/setup_cmake"
./scripts/install_lcov.sh     "${with_lcov}";     load "${BUILDDIR}/setup_lcov"
./scripts/install_valgrind.sh "${with_valgrind}"; load "${BUILDDIR}/setup_valgrind"
./scripts/install_gcc.sh      "${with_gcc}";      load "${BUILDDIR}/setup_gcc"

# ----------------------------------------------------------------------
# Now, install the dependent libraries
# ----------------------------------------------------------------------

# setup compiler flags, leading to nice stack traces on crashes but
# still optimised
export CFLAGS="-O2 -ftree-vectorize -g -fno-omit-frame-pointer -march=native -ffast-math $TSANFLAGS"
export FFLAGS="-O2 -ftree-vectorize -g -fno-omit-frame-pointer -march=native -ffast-math $TSANFLAGS"
export F77FLAGS="-O2 -ftree-vectorize -g -fno-omit-frame-pointer -march=native -ffast-math $TSANFLAGS"
export F90FLAGS="-O2 -ftree-vectorize -g -fno-omit-frame-pointer -march=native -ffast-math $TSANFLAGS"
export FCFLAGS="-O2 -ftree-vectorize -g -fno-omit-frame-pointer -march=native -ffast-math $TSANFLAGS"
export CXXFLAGS="-O2 -ftree-vectorize -g -fno-omit-frame-pointer -march=native -ffast-math $TSANFLAGS"
export LDFLAGS="$TSANFLAGS"

# get system arch information using OpenBLAS prebuild
./scripts/get_openblas_arch.sh; load "${BUILDDIR}/openblas_arch"

# MPI libraries
case "$MPI_MODE" in
    __OPENMPI__)
        ./scripts/install_openmpi.sh "${with_openmpi}"; load "${BUILDDIR}/setup_openmpi"
        ;;
    __MPICH__)
        ./scripts/install_mpich.sh "${with_mpich}"; load "${BUILDDIR}/setup_mpich"
        ;;
esac

# math core libraries, need to use reflapck for valgrind builds, as
# many fast libraries are not necesarily thread safe
export REF_MATH_CFLAGS=''
export REF_MATH_LDFLAGS=''
export REF_MATH_LIBS=''
export FAST_MATH_CFLAGS=''
export FAST_MATH_LDFLAGS=''
export FAST_MATH_LIBS=''

./scripts/install_reflapack.sh "${with_reflapack}"; load "${BUILDDIR}/setup_reflapack"
case "$FAST_MATH_MODE" in
    __MKL__)
        ./scripts/install_mkl.sh "${with_mkl}"; load "${BUILDDIR}/setup_mkl"
        ;;
    __ACML__)
        ./scripts/install_acml.sh "${with_acml}"; load "${BUILDDIR}/setup_acml"
        ;;
    __OPENBLAS__)
        ./scripts/install_openblas.sh "${with_openblas}"; load "${BUILDDIR}/setup_openblas"
        ;;
esac

if [ $ENABLE_VALGRIND = "__TRUE__" ] ; then
    export MATH_CFLAGS="${REF_MATH_CFLAGS}"
    export MATH_LDFLAGS="${REF_MATH_LDFLAGS}"
    export MATH_LIBS="${REF_MATH_LIBS}"
else
    export MATH_CFLAGS="${FAST_MATH_CFLAGS}"
    export MATH_LDFLAGS="${FAST_MATH_LDFLAGS}"
    export MATH_LIBS="${FAST_MATH_LIBS}"
fi

# note that C preprocessor which we use as a mode chooser has
# difficulty in interpreting commas in macro arguments unless it is
# inside parenthesis or quotes. So we must quote the LDFLAGS, as they
# may contain -Wl, flags
export CP_CFLAGS="$(unique ${CP_CFLAGS} "IF_VALGRIND(${REF_MATH_CFLAGS},${FAST_MATH_CFLAGS})")"
export CP_LDFLAGS="$(unique ${CP_LDFLAGS} "IF_VALGRIND(\"${REF_MATH_LDFLAGS}\",\"${FAST_MATH_LDFLAGS}\")")"
export CP_LIBS="$(unique ${CP_LIBS} "IF_VALGRIND(${REF_MATH_LIBS},${FAST_MATH_LIBS})")"

# other libraries
./scripts/install_fftw.sh      "${with_fftw}";      load "${BUILDDIR}/setup_fftw"
./scripts/install_libxc.sh     "${with_libxc}";     load "${BUILDDIR}/setup_libxc"
./scripts/install_libint.sh    "${with_libint}";    load "${BUILDDIR}/setup_libint"
./scripts/install_scalapack.sh "${with_scalapack}"; load "${BUILDDIR}/setup_scalapack"
./scripts/install_libxsmm.sh   "${with_libxsmm}";   load "${BUILDDIR}/setup_libxsmm"
./scripts/install_libsmm.sh    "${with_libsmm}";    load "${BUILDDIR}/setup_libsmm"
./scripts/install_elpa.sh      "${with_elpa}";      load "${BUILDDIR}/setup_elpa"
./scripts/install_ptscotch.sh  "${with_ptscotch}";  load "${BUILDDIR}/setup_ptscotch"
./scripts/install_parmetis.sh  "${with_parmetis}";  load "${BUILDDIR}/setup_parmetis"
./scripts/install_metis.sh     "${with_metis}";     load "${BUILDDIR}/setup_metis"
./scripts/install_superlu.sh   "${with_superlu}";   load "${BUILDDIR}/setup_superlu"
./scripts/install_pexsi.sh     "${with_pexsi}";     load "${BUILDDIR}/setup_pexsi"
./scripts/install_quip.sh      "${with_quip}";      load "${BUILDDIR}/setup_quip"

# ----------------------------------------------------------------------
# generate arch file for compiling cp2k
# ----------------------------------------------------------------------

echo "==================== generating arch files ===================="
echo "arch files can be found in the ${INSTALLDIR}/arch subdirectory"
mkdir -p ${INSTALLDIR}/arch
cd ${INSTALLDIR}/arch

# BEG:DEBUG:LT:2016/02/01
echo ${CP_LIBS}
echo ${CP_LDFLAGS}
echo ${CP_CFLAGS}
# END:DEBUG:LT:2016/02/01


# add standard libs
LIBS="${CP_LIBS} -lstdc++"

# we always want good line information and backtraces
BASEFLAGS="${BASEFLAGS} -march=native -fno-omit-frame-pointer -g ${TSANFLAGS}"
#For gcc 6.0 use -O1 -coverage -fkeep-static-functions -D__NO_ABORT
BASEFLAGS="${BASEFLAGS} IF_COVERAGE(-O0 -coverage -D__NO_ABORT, IF_DEBUG(-O1,-O2 -ffast-math))"
# those flags that do not influence code generation are used always, the others if debug
FCDEBFLAGS="IF_DEBUG(-fsanitize=leak -fcheck='bounds,do,recursion,pointer' -ffpe-trap='invalid,zero,overflow' -finit-real=snan -fno-fast-math,) -std=f2003 -fimplicit-none "
DFLAGS="${CP_DFLAGS} IF_DEBUG(-D__HAS_IEEE_EXCEPTIONS,)"
# profile based optimization, see https://www.cp2k.org/howto:pgo
BASEFLAGS="${BASEFLAGS} IF_DEBUG(,\$(PROFOPT))"

# Special flags for gfortran
# https://gcc.gnu.org/onlinedocs/gfortran/Error-and-Warning-Options.html
# we error out for these warnings (-Werror=uninitialized -Wno-maybe-uninitialized -> error on variables that must be used uninitialized)
WFLAGSERROR="-Werror=aliasing -Werror=ampersand -Werror=c-binding-type -Werror=intrinsic-shadow -Werror=intrinsics-std -Werror=line-truncation -Werror=tabs -Werror=realloc-lhs-all -Werror=target-lifetime -Werror=underflow -Werror=unused-but-set-variable -Werror=unused-variable -Werror=unused-dummy-argument -Werror=conversion -Werror=zerotrip -Werror=uninitialized -Wno-maybe-uninitialized"
# we just warn for those (that eventually might be promoted to WFLAGSERROR). It is useless to put something here with 100s of warnings.
#WFLAGSWARN="-Wuse-without-only"
WFLAGSWARN=""
# while here we collect all other warnings, some we'll ignore
WFLAGSWARNALL="-pedantic -Wall -Wextra -Wsurprising -Wunused-parameter -Warray-temporaries -Wcharacter-truncation -Wconversion-extra -Wimplicit-interface -Wimplicit-procedure -Wreal-q-constant -Wunused-parameter -Walign-commons -Wfunction-elimination -Wrealloc-lhs -Wcompare-reals -Wzerotrip"
# combine warn/error flags
WFLAGS="$WFLAGSERROR $WFLAGSWARN IF_WARNALL(${WFLAGSWARNALL},)"
FCFLAGS="${BASEFLAGS} -ffree-form ${CP_CFLAGS} \$(FCDEBFLAGS) \$(WFLAGS) \$(DFLAGS)"
LDFLAGS="${CP_LDFLAGS} \$(FCFLAGS)"

# Spcial flags for gcc (currently none)
CFLAGS="${BASEFLAGS} ${CP_CFLAGS} \$(DFLAGS)"

# CUDA stuff
if [ "$ENABLE_CUDA" = __TRUE__ ] ; then
    LIBS="${LIBS} IF_CUDA(-lcudart -lcufft -lcublas -lrt IF_DEBUG(-lnvToolsExt,),)"
    DFLAGS="IF_CUDA(-D__ACC -D__DBCSR_ACC -D__PW_CUDA IF_DEBUG(-D__CUDA_PROFILING,),) ${DFLAGS}"
    NVFLAGS="-arch sm_35 \$(DFLAGS) "
fi

# helper routine for instantiating the arch.tmpl
gen_arch_file() {
 local filename=$1
 local flags=$2
 local TMPL=$(cat ${ARCH_FILE_TEMPLATE})
 eval "printf \"$TMPL\"" | cpp -traditional-cpp -P ${flags} - > $filename
 echo "Wrote install/arch/"$filename
}

rm -f ${INSTALLDIR}/arch/local*
# normal production arch files
    { gen_arch_file "local.sopt" "";              arch_vers="sopt"; }
    { gen_arch_file "local.sdbg" "-DDEBUG";       arch_vers="${arch_vers} sdbg"; }
[ "$ENABLE_OMP" = __TRUE__ ] && \
    { gen_arch_file "local.ssmp" "-DOMP";         arch_vers="${arch_vers} ssmp"; }
[ "$ENABLE_MPI" = __TRUE__ ] && \
    { gen_arch_file "local.popt" "-DMPI";         arch_vers="${arch_vers} popt"; }
[ "$ENABLE_MPI" = __TRUE__ ] && \
    { gen_arch_file "local.pdbg" "-DMPI -DDEBUG"; arch_vers="${arch_vers} pdbg"; }
[ "$ENABLE_MPI" = __TRUE__ ] && \
[ "$ENABLE_OMP" = __TRUE__ ] && \
    { gen_arch_file "local.psmp" "-DMPI -DOMP";   arch_vers="${arch_vers} psmp"; }
# cuda enabled arch files
if [ "$ENABLE_CUDA" = __TRUE__ ] ; then
    [ "$ENABLE_OMP" = __TRUE__ ] && \
        { gen_arch_file "local_cuda.ssmp" "-DCUDA -DOMP";               arch_cuda="ssmp"; }
    [ "$ENABLE_MPI" = __TRUE__ ] && \
    [ "$ENABLE_OMP" = __TRUE__ ] && \
        { gen_arch_file "local_cuda.psmp" "-DCUDA -DOMP -DMPI";         arch_cuda="${arch_cuda} psmp"; }
    [ "$ENABLE_OMP" = __TRUE__ ] && \
        { gen_arch_file "local_cuda.sdbg" "-DCUDA -DDEBUG -DOMP";       arch_cuda="${arch_cuda} sdbg"; }
    [ "$ENABLE_MPI" = __TRUE__ ] && \
    [ "$ENABLE_OMP" = __TRUE__ ] && \
        { gen_arch_file "local_cuda.pdbg" "-DCUDA -DDEBUG -DOMP -DMPI"; arch_cuda="${arch_cuda} pdbg"; }
    [ "$ENABLE_MPI" = __TRUE__ ] && \
    [ "$ENABLE_OMP" = __TRUE__ ] && \
        { gen_arch_file "local_cuda_warn.psmp" "-DCUDA -DMPI -DOMP -DWARNALL"; }
fi
# valgrind enabled arch files
if [ "$ENABLE_VALGRIND" != __TRUE__ ] ; then
        { gen_arch_file "local_valgrind.sdbg" "-DVALGRIND";       arch_valg="sdbg"; }
    [ "$ENABLE_MPI" = __TRUE__ ] && \
        { gen_arch_file "local_valgrind.pdbg" "-DVALGRIND -DMPI"; arch_valg="${arch_valgrind} pdbg"; }
fi
# coverage enabled arch files
if [ "$with_lcov" != __DONTUSE__ ]; then
        { gen_arch_file "local_coverage.sdbg" "-DCOVERAGE";       arch_cov="sdbg"; }
    [ "$ENABLE_MPI" = __TRUE__ ] && \
        { gen_arch_file "local_coverage.pdbg" "-DCOVERAGE -DMPI"; arch_cov="${arch_cov} pdbg"; }
    [ "$ENABLE_CUDA" = __TRUE__ ] && \
        { gen_arch_file "local_coverage_cuda.pdbg"   "-DCOVERAGE -DMPI -DCUDA"; }
fi

cat <<EOF
========================== usage =========================
Done!
Now copy: cp ${INSTALLDIR}/arch/* to the cp2k/arch/ directory
to use the installed tools and libraries and cp2k version
compiled with it you will first need to execute at the prompt:
  source ${SETUPFILE}
To build CP2K you should change directory:
  cd cp2k/makefiles/
  make -j ${nprocs} ARCH=local VERSION="${arch_vers}"
EOF

#EOF
