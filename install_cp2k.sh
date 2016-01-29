#!/bin/bash -e
[ "${BASH_SOURCE[0]}" ] && SCRIPT_NAME="${BASH_SOURCE[0]}" || SCRIPT_NAME=$0
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_NAME")" && pwd -P)"

# trap errors
error_handler() {
   echo "Non-zero exit code in this script on line $1"
   exit 1
}
trap 'error_handler ${LINENO}' ERR

# system search paths, can be redefined when running the script
SYS_INCLUDE_PATH=${SYS_INCLUDE_PATH:-'/usr/local/include:/usr/include'}
SYS_LIB_PATH=${SYS_LIB_PATH:-'/user/local/lib64:/usr/local/lib:/usr/lib64:/usr/lib:/lib64:/lib'}
INCLUDE_PATHS=${INCLUDE_PATHS:-"CPATH SYS_INCLUDE_PATH"}
LIB_PATHS=${LIB_PATHS:-"LIBRARY_PATH LD_LIBRARY_PATH LD_RUN_PATH SYS_LIB_PATH"}
source ./tool_kit.sh

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
  --with-scotch           PT-SCOTCH, only used if PEXSI is used
                          Default = no
  --with-parmetis         ParMETIS, and if --with-parmetis=install will also install
                          METIS, only used if PEXSI is used
                          Default = no
  --with-metis            METIS, --with-metis=install actuall does nothing, because
                          METIS is installed together with ParMETIS.  This option
                          is used to specify the METIS library if it is pre-installed
                          else-where. Only used if PEXSI is used
                          Default = no
  --with-superlu_dist     SuperLU DIST, used only if PEXSI is used
                          Default = no
  --with-pexsi            Enable interface to PEXSI library
                          Default = no
  --with-quip             Enable interface to QUIP library
                          Default = no
EOF
}

# processor arch, used for MKL selection and others (use in document
# search) avaliable choices: x86_64 ia_32
ARCH=${ARCH:-x86_64}

# default versions
binutils_ver=2.25
cmake_ver=3.1.1
elpa_ver=2015.11.001
fftw_ver=3.3.4
gcc_ver=5.2.0
lapack_ver=3.5.0
lcov_ver=1.11
libint_ver=1.1.4
libxc_ver=2.2.2
mpich_ver=3.1.2
openblas_ver=v0.2.14-0-gd0c51c4
openmpi_ver=1.8.6
parmetis_ver=4.0.2
pexsi_ver=0.9.0
plumed_ver=2.2b
quip_ver=cc83ceea5776c40fcb5ab224a25ab04d62175449
scalapack_ver=2.0.2
scotch_ver=6.0.0
superlu_ver=3.3
valgrind_ver=3.11.0

# default settings
enable_toolchain=__FALSE__
enable_tsan=__FALSE__
enable_gcc_master=__FALSE__
enable_omp=__TRUE__
enable_cuda=__FALSE__
with_gcc=__SYSTEM__
with_binutils=__SYSTEM__
with_cmake=__DONTUSE__
with_valgrind=__DONTUSE__
with_lcov=__DONTUSE__
with_openmpi=__SYSTEM__
with_mpich=__DONTUSE__
with_libxc=__INSTALL__
with_libint=__INSTALL__
with_fftw=__INSTALL__
with_reflapack=__DONTUSE__
with_acml=__DONTUSE__
with_mkl=__DONTUSE__
with_openblas=__INSTALL__
with_scalapack=__INSTALL__
with_libsmm=__INSTALL__
with_elpa=__DONTUSE__
with_scotch=__DONTUSE__
with_parmetis=__DONTUSE__
with_metis=__DONTUSE__
with_superlu_dist=__DONTUSE__
with_pexsi=__DONTUSE__
with_quip=__DONTUSE__

# toolchain mode default options
# toolchain mode settings
if [ $enable_toolchain = "__TRUE__" ] ; then
    with_gcc=__INSTALL__
    with_binutils=__INSTALL__
    with_cmake=__INSTALL__
    with_valgrind=__INSTALL__
    with_lcov=__INSTALL__
    with_openmpi=__DONTUSE__
    with_mpich=__INSTALL__
    with_libxc=__INSTALL__
    with_libint=__INSTALL__
    with_fftw=__INSTALL__
    with_reflapack=__INSTALL__
    with_acml=__DONTUSE__
    with_mkl=__DONTUSE__
    with_openblas=__INSTALL__
    with_scalapack=__INSTALL__
    with_libsmm=__INSTALL__
    with_elpa=__INSTALL__
    with_scotch=__INSTALL__
    with_parmetis=__INSTALL__
    with_metis=__INSTALL__
    with_superlu_dist=__INSTALL__
    with_pexsi=__INSTALL__
    with_quip=__INSTALL__    
fi

# parse options
toolchain_options=''
while [ $# -ge 1 ] ; do
    case $1 in
        --enable-toolchain*)
            enable_toolchain=$(read_enable $1)
            if [ $enable_toolchain = "__INVALID__" ] ; then
                echo "invalid value for --enable-toolchain, please use yes or no" >&2
                exit 1
            fi
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
                with_mpich='__DONTUSE__'
            fi
            ;;
        --with-mpich*)
            with_mpich=$(read_with $1)
            if [ "$with_mpich" != "__DONTUSE__" ] ; then
                with_openmpi='__DONTUSE__'
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
            ;;
        --with-acml*)
            with_acml=$(read_with $1)
            ;;
        --with-openblas*)
            with_openblas=$(read_with $1)
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
        --with-scotch*)
            with_scotch=$(read_with $1)
            ;;
        --with-parmetis*)
            with_parmetis=$(read_with $1)
            ;;
        --with-metis*)
            with_metis=$(read_with $1)
            ;;
        --with-superlu*)
            with_superlu_dist=$(read_with $1)
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

# ----------------------------------------------------------------------
# Check and solve known conflicts before installations proceed
# ----------------------------------------------------------------------

# GCC thread sanitizer conflicts
if [ $enable_tsan = "__TRUE__" ] ; then
    echo "TSAN is enabled, canoot use openblas"
    with_openblas="__DONTUSE__"
    echo "TSAN is enabled, canoot use libsmm"
    with_libsmm="__DONTUSE__"
fi
# valgrind conflicts
if [ "$with_valgrind" != "__DONTUSE__" ] ; then
    echo "openblas is not thread safe, use reflapack instead when use with valgrind"
    with_openblas="__DONTUSE__"
    with_reflapack="__INSTALL__"
fi
# math library conflicts
enable_lapack="__FALSE__"
lapack_option_list="$with_acml $with_mkl $with_openblas"
for ii in $lapack_option_list ; do
    if [ "$ii" != "__DONTUSE__" ] ; then
        if [ $enable_lapack = "__FALSE__" ] ; then
            enable_lapack="__TRUE__"
        else
            echo "Please use only one LAPACK library" >&2
            exit 1
        fi
    fi
done
if [ $enable_lapack = "__FALSE__" ] ; then
    echo "Must use one of the LAPACK libraries." >&2
    exit 1
fi
# mpi library conflicts
enable_mpi="__FALSE__"
mpi_option_list="$with_openmpi $with_mpich"
for ii in $mpi_option_list ; do
    if [ "$ii" != "__DONTUSE__" ] ; then
        if [ $enable_mpi = "__FALSE__" ] ; then
            enable_mpi="__TRUE__"
        else
            echo "Please use only one MPI implementation" >&2
            exit 1
        fi
    fi
done
if [ $enable_mpi = "__TRUE__" ] ; then
    if [ "$with_gcc" = "__INSTALL__" ] ; then
        echo "You have chosen to install GCC, therefore MPI libraries will have to be installed too"
        [ "$with_openmpi" != "__DONTUSE__" ] && \
            with_openmpi="__INSTALL__"
        [ "$with_mpich" != "__DONTUSE__" ] && \
            with_mpich="__INSTALL__"
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
    if [ "$with_scotch" != "__DONTUSE__" ] ; then
        echo "Not using PEXSI, so PT-Scotch is disabled."
        with_scotch="__DONTUSE__"
    fi
    if [ "$with_parmetis" != "__DONTUSE__" ] ; then
        echo "Not using PEXSI, so ParMETIS is disabled."
        with_parmetis="__DONTUSE__"
    fi
    if [ "$with_metis" != "__DONTUSE__" ] ; then
        echo "Not using PEXSI, so METIS is disabled."
        with_metis="__DONTUSE__"
    fi
    if [ "$with_superlu_dist" != "__DONTUSE__" ] ; then
        echo "Not using PEXSI, so SuperLU-DIST is disabled."
        with_superlu_dist="__DONTUSE__"
    fi
elif [ "$with_pexsi" = "__INSTALL__" ] ; then
    [ "$with_scotch" = "__DONTUSE__" ] && with_scotch="__INSTALL__"
    [ "$with_parmetis" = "__DONTUSE__" ] && with_parmetis="__INSTALL__"
    [ "$with_superlu_dist" = "__DONTUSE__" ] && with_superlu_dist="__INSTALL__"
else
    if [ "$with_scotch" = "__DONTUSE__" ] ; then
        echo "For PEXSI to work you need a working PT-Scotch library" >&2
        echo "use --with-scotch option to specify if you wish to install" >&2
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
    if [ "$with_superlu_dist" = "__DONTUSE__" ] ; then
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
ROOTDIR="${PWD}"
mkdir -p build
cd build
INSTALLDIR="${ROOTDIR}/install"
echo "All required tools and packages will be installed in ${INSTALLDIR}"
mkdir -p "${INSTALLDIR}"
nprocs=$(get_nprocs)

# variables used for generating cp2k ARCH file
CP_DFLAGS=''
CP_LIBS=''
CP_CFLAGS='IF_OMP(-fopenmp,)'
CP_LDFLAGS="-Wl,--enable-new-dtags"

# libs variable for LAPACK related compilation
REF_MATH_CFLAGS=''
REF_MATH_LDFLAGS='-Wl,--enable-new-dtags'
REF_MATH_LIBS=''
FAST_MATH_CFLAGS=''
FAST_MATH_LDFLAGS="-Wl,--enable-new-dtags"
FAST_MATH_LIBS=''
# must use CP_MATH_* flags with eval
CP_MATH_CFLAGS='IF_VALGRIND\($REF_MATH_CFLAGS,$FAST_MATH_CFLAGS\)'
CP_MATH_LDFLAGS='IF_VALGRIND\($REF_MATH_LDFLAGS,$FAST_MATH_LDFLAGS\)'
CP_MATH_LIBS='IF_VALGRIND\($REF_MATH_LIBS,$FAST_MATH_LIBS\)'


# ----------------------------------------------------------------------
# Start writing setup file
# ----------------------------------------------------------------------
SETUPFILE="${INSTALLDIR}/setup"
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

# ----------------------------------------------------------------------
# GNU binutils
# ----------------------------------------------------------------------
case "$with_binutils" in
    __INSTALL__)
        echo "==================== Installing binutils ===================="
        if [ -f binutils-${binutils_ver}.tar.gz ] ; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://ftp.gnu.org/gnu/binutils/binutils-${binutils_ver}.tar.gz
            checksum binutils-${binutils_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf binutils-${binutils_ver}.tar.gz
            cd binutils-${binutils_ver}
            ./configure --prefix=${INSTALLDIR} --enable-gold --enable-plugins >& config.log
            make -j $nprocs >& make.log
            make -j $nprocs install >& install.log
            cd ..
        fi
        ;;
    __SYSTEM__)
        check_command ar "gnu binutils"
        check_command ld "gnu binutils"
        check_command ranlib "gnu binutils"
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_binutils" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path PATH "$with_binutils/bin"
prepend_path LD_LIBRARY_PATH "$with_binutils/lib"
prepend_path LD_LIBRARY_PATH "$with_binutils/lib64"
prepend_path LD_RUN_PATH "$with_binutils/lib"
prepend_path LD_RUN_PATH "$with_binutils/lib64"
prepend_path LIBRARY_PATH "$with_binutils/lib"
prepend_path LIBRARY_PATH "$with_binutils/lib64"
EOF
        else
            echo "Cannot find $with_binutils" >&2
            exit 1
        fi
        ;;
esac

# ----------------------------------------------------------------------
# CMAKE
# ----------------------------------------------------------------------
case "$with_cmake" in
    __INSTALL__)
        echo "==================== Installing CMake ===================="
        if [ -f cmake-${cmake_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/cmake-${cmake_ver}.tar.gz
            checksum cmake-${cmake_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf cmake-${cmake_ver}.tar.gz
            cd cmake-${cmake_ver}
            ./bootstrap --prefix=${INSTALLDIR} >& config.log
            make -j $nprocs >&  make.log
            make install >& install.log
            cd ..
        fi
        ;;
    __SYSTEM__)
        check_command cmake "cmake"
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_cmake" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path PATH "$with_cmake/bin"
EOF
        else
            echo "Cannot find $with_cmake" >&2
            exit 1
        fi
        ;;
esac

# ----------------------------------------------------------------------
# LCOV
# ----------------------------------------------------------------------
case "$with_lcov" in
    __INSTALL__)
        echo "==================== Installing lcov ====================="
        if [ -f lcov-${lcov_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/lcov-${lcov_ver}.tar.gz
            checksum lcov-${lcov_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf lcov-${lcov_ver}.tar.gz
            cd lcov-${lcov_ver}
            # note.... this installs in ${INSTALLDIR}/usr/bin
            make PREFIX=${INSTALLDIR} install >& make.log
            cd ..
        fi
        ;;
    __SYSTEM__)
        check_command lcov "lcov"
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_lcov" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path PATH "$with_lcov/bin"
EOF
        else
            echo "Cannot find $with_lcov" >&2
            exit 1
        fi
        ;;
esac

# ----------------------------------------------------------------------
# Valgrind
# ----------------------------------------------------------------------
case "$with_valgrind" in
    __INSTALL__)
        echo "==================== Installing valgrind ===================="
        if [ -f valgrind-${valgrind_ver}.tar.bz2 ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/valgrind-${valgrind_ver}.tar.bz2
            checksum valgrind-${valgrind_ver}.tar.bz2 "$ROOTDIR/checksums.sha256"
            tar -xjf valgrind-${valgrind_ver}.tar.bz2
            cd valgrind-${valgrind_ver}
            ./configure --prefix=${INSTALLDIR} >& config.log
            make -j $nprocs >& make.log
            make -j $nprocs install >& install.log
            cd ..
        fi
        ;;
    __SYSTEM__)
        check_command valgrind "valgrind"
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_valgrind" ] ; then
            car <<EOF >> $SETUPFILE
prepend_path PATH "$with_valgrind/bin"
prepend_path LD_LIBRARY_PATH "$with_valgrind/lib"
EOF
        else
            echo "Cannot find $with_valgrind" >&2
            exit 1
        fi
        ;;
esac

# ----------------------------------------------------------------------
# GCC with or without tsan
# ----------------------------------------------------------------------
if [ $enable_gcc_master = "__TRUE__" ] ; then
    echo "Trying to install gcc master (developer) version"
    gcc_ver="master"
fi
case "$with_gcc" in
    __INSTALL__)
        echo "==================== Installing gcc ===================="
        if [ -f gcc-${gcc_ver}.tar.gz -o -f gcc-${gcc_ver}.zip ]; then
            echo "Installation already started, skipping it."
        else
            if [ "${gcc_ver}" == "master" ]; then
                # no check since this follows the gcc trunk svn repo and changes constantly
                wget --no-check-certificate -O gcc-master.zip https://github.com/gcc-mirror/gcc/archive/master.zip
                unzip -q gcc-master.zip
            else
                wget --no-check-certificate https://ftp.gnu.org/gnu/gcc/gcc-${gcc_ver}/gcc-${gcc_ver}.tar.gz
                checksum gcc-${gcc_ver}.tar.gz "$ROOTDIR/checksums.sha256"
                tar -xzf gcc-${gcc_ver}.tar.gz
            fi
            cd gcc-${gcc_ver}
            ./contrib/download_prerequisites >& prereq.log
            GCCROOT=${PWD}
            mkdir obj
            cd obj
            ${GCCROOT}/configure --prefix=${INSTALLDIR}  \
                                 --enable-languages=c,c++,fortran \
                                 --disable-multilib --disable-bootstrap \
                                 --enable-lto \
                                 --enable-plugins \
                                 >& config.log
            make -j $nprocs >& make.log
            make -j $nprocs install >& install.log

            if [ $enable_tsan = "__TRUE__" ] ; then
                # now the tricky bit... we need to recompile in particular
                # libgomp with -fsanitize=thread.. there is not configure
                # option for this (as far as I know).  we need to go in
                # the build tree and recompile / reinstall with proper
                # options...  this is likely to break for later version of
                # gcc, tested with 5.1.0 based on
                # https://gcc.gnu.org/bugzilla/show_bug.cgi?id=55374#c10
                cd x86_64*/libgfortran
                make clean >& clean.log
                make -j $nprocs \
                     CFLAGS="-std=gnu99 -g -O2 -fsanitize=thread " \
                     FCFLAGS="-g -O2 -fsanitize=thread" \
                     CXXFLAGS="-std=gnu99 -g -O2 -fsanitize=thread " \
                     LDFLAGS="-B`pwd`/../libsanitizer/tsan/.libs/ -Wl,-rpath,`pwd`/../libsanitizer/tsan/.libs/ -fsanitize=thread" \
                     >& make.log
                make install >& install.log
                cd ../libgomp
                make clean >& clean.log
                make -j $nprocs \
                     CFLAGS="-std=gnu99 -g -O2 -fsanitize=thread " \
                     FCFLAGS="-g -O2 -fsanitize=thread" \
                     CXXFLAGS="-std=gnu99 -g -O2 -fsanitize=thread " \
                     LDFLAGS="-B`pwd`/../libsanitizer/tsan/.libs/ -Wl,-rpath,`pwd`/../libsanitizer/tsan/.libs/ -fsanitize=thread" \
                     >& make.log
                make install >& install.log
                cd $GCCROOT/obj/
            fi
            cd ../..
        fi
        ;;
    __SYSTEM__)
        check_command gcc "gcc"
        check_command g++ "gcc"
        check_command gfortran "gcc"
        add_lib_from_paths GCC_LDFLAGS "libgfortran.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_gcc" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path PATH "$with_gcc/bin"
prepend_path LD_LIBRARY_PATH "$with_gcc/lib"
prepend_path LD_LIBRARY_PATH "$with_gcc/lib64"
prepend_path LD_RUN_PATH "$with_gcc/lib"
prepend_path LD_RUN_PATH "$with_gcc/lib64"
prepend_path LIBRARY_PATH "$with_gcc/lib"
prepend_path LIBRARY_PATH "$with_gcc/lib64"
prepend_path CPATH "$with_gcc/include"
EOF
            GCC_LDFLAGS="-L'${with_gcc}/lib64' -L'${with_gcc}/lib' -Wl,-rpath='${with_gcc}/lib64' -Wl,-rpath='${with_gcc}/lib64'"
        else
            echo "Cannot find $with_gcc" >&2
            exit 1
        fi
        ;;
esac
if [ $enable_tsan = "__TRUE__" ] ; then
    TSANFLAGS="-fsanitize=thread"
else
    TSANFLAGS=""
fi

# ----------------------------------------------------------------------
# Suppress reporting of known leaks
# ----------------------------------------------------------------------
# valgrind suppressions
cat <<EOF > ${INSTALLDIR}/valgrind.supp
{
   BuggySUPERLU
   Memcheck:Cond
   ...
   fun:SymbolicFactorize
}
EOF

# lsan & tsan suppressions for known leaks are created as well,
# this might need to be adjusted for the versions of the software
# employed
cat <<EOF > ${INSTALLDIR}/lsan.supp
# known leak either related to mpi or scalapack  (e.g. showing randomly for Fist/regtest-7-2/UO2-2x2x2-genpot_units.inp)
leak:__cp_fm_types_MOD_cp_fm_write_unformatted
# leaks related to PEXSI
leak:PPEXSIDFTDriver
# tsan bugs likely related to gcc
# PR66756
deadlock:_gfortran_st_open
mutex:_gfortran_st_open
# PR66761
race:do_spin
race:gomp_team_end
#PR67303
race:gomp_iter_guided_next
# bugs related to removing/filtering blocks in DBCSR.. to be fixed
race:__dbcsr_block_access_MOD_dbcsr_remove_block
race:__dbcsr_operations_MOD_dbcsr_filter_anytype
race:__dbcsr_transformations_MOD_dbcsr_make_untransposed_blocks
EOF

# ----------------------------------------------------------------------
# Write setup file for the installed tools and libraries
# ----------------------------------------------------------------------
cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH "${INSTALLDIR}/lib"
prepend_path LD_LIBRARY_PATH "${INSTALLDIR}/lib64"
prepend_path LD_RUN_PATH "${INSTALLDIR}/lib"
prepend_path LD_RUN_PATH "${INSTALLDIR}/lib64"
prepend_path LIBRARY_PATH "${INSTALLDIR}/lib"
prepend_path LIBRARY_PATH "${INSTALLDIR}/lib64"
prepend_path PATH "${INSTALLDIR}/bin"
prepend_path CPATH "${INSTALLDIR}/include"
export CP2KINSTALLDIR=${INSTALLDIR}
export LSAN_OPTIONS=suppressions=${INSTALLDIR}/lsan.supp
export TSAN_OPTIONS=suppressions=${INSTALLDIR}/lsan.supp
export VALGRIND_OPTIONS="--suppressions=${INSTALLDIR}/valgrind.supp --max-stackframe=2168152 --error-exitcode=42"
export CC=gcc
export CXX=g++
export FC=gfortran
export F77=gfortran
export F90=gfortran
EOF

# load the setup file
source ${SETUPFILE}

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

# ----------------------------------------------------------------------
# openmpi
# ----------------------------------------------------------------------
case "$with_openmpi" in
    __INSTALL__)
        echo "==================== Installing OpenMPI ===================="
        if [ -f openmpi-${openmpi_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.open-mpi.org/software/ompi/v1.8/downloads/openmpi-${openmpi_ver}.tar.gz
            checksum openmpi-${openmpi_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf openmpi-${openmpi_ver}.tar.gz
            cd openmpi-${openmpi_ver}
            # can have issue with older glibc libraries, in which case
            # we need to add the -fgnu89-inline to CFLAGS. We can check
            # the version of glibc using ldd --version, as ldd is part of
            # glibc package
            glibc_version=$(ldd --version | awk '(NR == 1){print $4}')
            glibc_major_ver=$(echo $glibc_version | cut -d . -f 1)
            glibc_minor_ver=$(echo $glibc_version | cut -d . -f 2)
            if [ $glibc_major_ver -le 2 ] && \
               [ $glibc_minor_ver -lt 12 ] ; then
                CFLAGS="${CFLAGS} -fgnu89-inline"
            fi
            ./configure --prefix=${INSTALLDIR} CFLAGS="${CFLAGS}" >& config.log
            make -j $nprocs >& make.log
            make -j $nprocs install >& install.log
            cd ..
        fi
        ;;
    __SYSTEM__)
        check_command mpirun "openmpi"
        check_command mpicc "openmpi"
        check_command mpif90 "openmpi"
        check_command mpic++ "openmpi"
        check_lib -lmpi "openmpi"
        check_lib -lmpi_cxx "openmpi"
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_openmpi" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path PATH "$with_openmpi/bin"
prepend_path LD_LIBRARY_PATH "$with_openmpi/lib"
prepend_path LD_RUN_PATH "$with_openmpi/lib"
prepend_path LIBRARY_PATH "$with_openmpi/lib"
prepend_path CPATH "$with_openmpi/include"
EOF
        else
            echo "Cannot find $with_openmpi" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_openmpi" != "__DONTUSE__" ] ; then
    CP_DFLAGS="${CP_DFLAGS} IF_MPI(-D__parallel,)"
    # extra libs needed to link with mpif90 also applications based on C++
    CP_LIBS="${CP_LIBS} IF_MPI(-lmpi -lmpi_cxx,)"
fi

# ----------------------------------------------------------------------
# mpich
# ----------------------------------------------------------------------
case "$with_mpich" in
    __INSTALL__)
        echo "==================== Installing MPICH ===================="
        if [ -f mpich-${mpich_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            # needed to install mpich ??
            unset F90; unset F90FLAGS
            wget --no-check-certificate https://www.cp2k.org/static/downloads/mpich-${mpich_ver}.tar.gz
            checksum mpich-${mpich_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf mpich-${mpich_ver}.tar.gz
            cd mpich-${mpich_ver}
            ./configure --prefix=${INSTALLDIR} >& config.log
            make -j $nprocs >& make.log
            make -j $nprocs install >& install.log
            cd ..
        fi
        ;;
    __SYSTEM__)
        check_command mpirun "mpich"
        check_command mpicc "mpich"
        check_command mpif90 "mpich"
        check_command mpic++ "mpich"
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_mpich" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path PATH "$with_mpich/bin"
prepend_path LD_LIBRARY_PATH "$with_mpich/lib"
prepend_path LD_RUN_PATH "$with_mpich/lib"
prepend_path LIBRARY_PATH "$with_mpich/lib"
prepend_path CPATH "$with_mpich/include"
EOF
        else
            echo "Cannot find $with_mpich" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_mpich" != "__DONTUSE__" ] ; then
    CP_DFLAGS="${CP_DFLAGS} IF_MPI(-D__parallel -D__MPI_VERSION=3,)"
fi

# run setup again
source $SETUPFILE

# ----------------------------------------------------------------------
# FFTW3
# ----------------------------------------------------------------------
case "$with_fftw" in
    __INSTALL__)
        echo "==================== Installing FFTW3 ===================="
        if [ -f fftw-${fftw_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/fftw-${fftw_ver}.tar.gz
            checksum fftw-${fftw_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf fftw-${fftw_ver}.tar.gz
            cd fftw-${fftw_ver}
            if [ $enable_omp = "__TRUE__" ] ; then
                ./configure  --prefix=${INSTALLDIR} --enable-openmp >& config.log
            else
                ./configure  --prefix=${INSTALLDIR} >& config.logw
            fi
            make -j $nprocs >& make.log
            make install >& install.log
            cd ..
        fi
        FFTW3_CFLAGS="-I'${INSTALLDIR}/include'"
        FFTW3_LDFLAGS="-L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib'"
        ;;
    __SYSTEM__)
        check_lib -lfftw3 "FFTW3"
        [ $enable_omp = "__TRUE__" ] && check_lib -lfftw3_omp "FFTW3"
        add_include_from_paths FFTW3_CFLAGS "fftw3.h" $INCLUDE_PATHS
        add_lib_from_paths FFTW3_LDFLAGS "libfftw3.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_fftw" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH "$with_fftw/lib"
prepend_path LD_RUN_PATH "$with_fftw/lib"
prepend_path LIBRARY_PATH "$with_fftw/lib"
prepend_path CPATH "$with_fftw/include"
EOF
            FFTW3_CFLAGS="-I'${with_fftw}/include'"
            FFTW3_LDFLAGS="-L'${with_fftw}/lib' -Wl,-rpath='${with_fftw}/lib'"
        else
            echo "Cannot find $with_fftw" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_fftw" != "__DONTUSE__" ] ; then
    CP_DFLAGS="${CP_DFLAGS} -D__FFTW3"
    CP_DFLAGS="${CP_DFLAGS} IF_COVERAGE(IF_MPI(,-U__FFTW3),)" # also want to cover FFT_SG
    CP_CFLAGS="$(unique ${CP_CFLAGS} ${FFTW3_CFLAGS})"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${FFTW3_LDFLAGS})"
    CP_LIBS="-lfftw3 IF_OMP(-lfftw3_omp,) ${CP_LIBS}"
fi

# ----------------------------------------------------------------------
# LibXC
# ----------------------------------------------------------------------
case "$with_libxc" in
    __INSTALL__)
        echo "==================== Installing libxc ===================="
        if [ -f libxc-${libxc_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/libxc-${libxc_ver}.tar.gz
            checksum libxc-${libxc_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf libxc-${libxc_ver}.tar.gz
            cd libxc-${libxc_ver}
            # patch buggy configure macro (fails with gcc trunk)
            sed -i 's/ax_cv_f90_modext=$(ls | sed/ax_cv_f90_modext=)ls -1 | grep -iv smod | sed/g' configure
            ./configure  --prefix=${INSTALLDIR} >& config.log
            make -j $nprocs >& make.log
            make install >& install.log
            cd ..
        fi
        LIBXC_CFLAGS="-I'${INSTALLDIR}/include'"
        LIBXC_LDFLAGS="-L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib'"
        ;;
    __SYSTEM__)
        check_lib -lxcf90 "libxc"
        check_lib -lxc "libxc"
        add_include_from_paths LIBXC_CFLAGS "xc.h" $INCLUDE_PATHS
        add_lib_from_paths LIBXC_LDFLAGS "libxc.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_libxc" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH $with_libxc/lib
prepend_path LD_RUN_PATH $with_libxc/lib
prepend_path LIBRARY_PATH $with_libxc/lib
prepend_path CPATH $with_libxc/include
EOF
            LIBXC_CFLAGS="-I'$with_libxc/include'"
            LIBXC_LDFLAGS="-L'$with_libxc/lib' -Wl,-rpath='$with_libxc/lib'"
        else
            echo "Cannot find $with_libxc" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_libxc" != "__DONTUSE__" ] ; then
    CP_DFLAGS="${CP_DFLAGS} -D__LIBXC"
    CP_CFLAGS="$(unique ${CP_CFLAGS} ${LIBXC_CFLAGS})"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${LIBXC_LDFLAGS})"
    CP_LIBS="-lxcf90 -lxc ${CP_LIBS}"
fi

# ----------------------------------------------------------------------
# LibInt
# ----------------------------------------------------------------------
case "$with_libint" in
    __INSTALL__)
        echo "==================== Installing libint ===================="
        if [ -f libint-${libint_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/libint-${libint_ver}.tar.gz
            checksum libint-${libint_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf libint-${libint_ver}.tar.gz
            cd libint-${libint_ver}
            # hack for -with-cc, needed for -fsanitize=thread that also
            # needs to be passed to the linker, but seemingly ldflags is
            # ignored by libint configure
            ./configure --prefix=${INSTALLDIR} \
                        --with-libint-max-am=5 \
                        --with-libderiv-max-am1=4 \
                        --with-cc="gcc $CFLAGS" \
                        --with-cc-optflags="$CFLAGS" \
                        --with-cxx-optflags="$CXXFLAGS" \
                        >& config.log
            make -j $nprocs >&  make.log
            make install >& install.log
            cd ..
        fi
        LIBINT_CFLAGS="-I'${INSTALLDIR}/include'"
        LIBINT_LDFLAGS="-L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib'"
        ;;
    __SYSTEM__)
        check_lib -lderiv "libint"
        check_lib -lint "libint"
        add_include_from_paths -p LIBINT_CFLAGS "libint" $INCLUDE_PATHS
        add_lib_from_paths LIBINT_LDFLAGS "libint.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_libint" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH "$with_libint/lib"
prepend_path LD_RUN_PATH "$with_libint/lib"
prepend_path LIBRARY_PATH "$with_libint/lib"
prepend_path CPATH "$with_libint/include"
EOF
            LIBINT_CFLAGS="-I'$with_libint/include'"
            LIBINT_LDFLAGS="-L'$with_libint/lib' -Wl,-rpath='$with_libint/lib'"
        else
            echo "Cannot find $with_libint" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_libxc" != "__DONTUSE__" ] ; then
    CP_DFLAGS="${CP_DFLAGS} -D__LIBINT -D__LIBINT_MAX_AM=6 -D__LIBDERIV_MAX_AM1=5"
    CP_CFLAGS="$(unique ${CP_CFLAGS} ${LIBINT_CFLAGS})"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${LIBINT_LDFLAGS})"
    CP_LIBS="-lderiv -lint ${CP_LIBS}"
fi


# ----------------------------------------------------------------------
# reference LAPACK
# ----------------------------------------------------------------------
case "$with_reflapack" in
    __INSTALL__)
        echo "==================== Installing reference LAPACK ===================="
        if [ -f lapack-${lapack_ver}.tgz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/lapack-${lapack_ver}.tgz
            checksum lapack-${lapack_ver}.tgz "$ROOTDIR/checksums.sha256"
            tar -xzf lapack-${lapack_ver}.tgz
            cd lapack-${lapack_ver}
            cat <<EOF > make.inc
SHELL    = /bin/sh
FORTRAN  = gfortran
OPTS     = $FFLAGS -frecursive
DRVOPTS  = $FFLAGS -frecursive
NOOPT    = $FFLAGS -O0 -frecursive -fno-fast-math
LOADER   = gfortran
LOADOPTS = $FFLAGS
TIMER    = INT_ETIME
CC       = gcc
CFLAGS   = $CFLAGS
ARCH     = ar
ARCHFLAGS= cr
RANLIB   = ranlib
XBLASLIB     =
BLASLIB      = ../../libblas.a
LAPACKLIB    = liblapack.a
TMGLIB       = libtmglib.a
LAPACKELIB   = liblapacke.a
EOF
            # lapack/blas build is *not* parallel safe (updates to the archive race)
            make -j 1  lib blaslib >& make.log
            ! [ -d "${INSTALLDIR}/lib" ] && mkdir -p "${INSTALLDIR}/lib"
            cp libblas.a liblapack.a "${INSTALLDIR}/lib/"
            cd ..
        fi
        REF_MATH_LDFLAGS="$(unique ${REF_MATH_LDFLAGS} '-L${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib')"
        ;;
    __SYSTEM__)
        check_lib -lblas
        check_lib -llapack
        add_lib_from_paths MATH_LDFLAGS "liblapack.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_reflapack" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH "$with_reflapack/lib"
prepend_path LD_RUN_PATH "$with_reflapack/lib"
prepend_path LIBRARY_PATH "$with_reflapack/lib"
prepend_path CPATH "with_reflapack/include"
EOF
            REF_MATH_LDFLAGS="${MATH_LDFLAGS} -L'$with_reflapack/lib' -Wl,-rpath='$with_reflapack/lib'"
        else
            echo "Cannot find $with_reflapack" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_reflapack" != "__DONTUSE__" ] ; then
    REF_MATH_LIBS="-lblas -llapack"

    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${REF_MATH_LDFLAGS})"
fi

# ----------------------------------------------------------------------
# ACML
# ----------------------------------------------------------------------
case "$with_acml" in
    __INSTALL__)
        echo "Cannot install ACML automatically, please contact your system "
        echo "administrator or go to"
        echo "https://developer.amd.com/tools-and-sdks/archive/amd-core-math-library-acml/acml-downloads-resources/"
        echo "and download and install the correct version for your system" >&2
        exit 1
        ;;
    __SYSTEM__)
        check_lib -lacml
        add_include_from_paths MATH_CFLAGS "acml.h" $INCLUDE_PATHS
        add_lib_from_paths MATH_LDFLAGS "libacml.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_acml" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH "$with_acml/lib"
prepend_path LD_RUN_PATH "$with_acml/lib"
prepend_path LIBRARY_PATH "$with_acml/lib"
prepend_path CPATH "$with_acml/include"
EOF
            MATH_CFLAGS="${MATH_CFLAGS} -I'$with_acml/include'"
            MATH_LDFLAGS="${MATH_LDFLAGS} -L'$with_acml/lib' -Wl,-rpath='$with_acml/lib'"
        else
            echo "Cannot find $with_acml" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_acml" != "__DONTUSE__" ] ; then
    MATH_LIBS="-lacml"
    CP_CFLAGS="$(unique ${CP_CFLAGS} ${MATH_CFLAGS})"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${MATH_LDFLAGS})"
    CP_LIBS="${MATH_LIBS} ${CP_LIBS}"
fi

# ----------------------------------------------------------------------
# MKL
# ----------------------------------------------------------------------
case "$with_mkl" in
    __INSTALL__)
        echo "Cannot install Intel MKL automatically, please contact your system administrator" >&2
        exit 1
        ;;
    __DONTUSE__)
        ;;
    __SYSTEM__)
        if [ ! -z "MKLROOT" ] ; then
            echo "MKLROOT is found to be $MKLROOT"
        else
            echo "Cannot find env variable $MKLROOT, it seems mkl is not properly installed on your system" >&2
            exit 1
        fi
        ;;
    *)
        if [ -d "$with_mkl" ] ; then
            cat <<EOF >> $SETUPFILE
export MKLROOT="$with_mlk"
EOF
            export MKLROOT=$with_mkl
        else
            echo "Cannot find $with_mkl" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_mkl" != "__DONTUSE__" ] ; then
    case $ARCH in
        x86_64)
            mkl_arch_dir=intel64
            MATH_CFLAGS="${MATH_CFLAGS} -m64"
            ;;
        ia_32)
            mkl_arch_dir=ia32
            MATH_CFLAGS="${MATH_CFLAGS} -m32"
            ;;
        *)
            echo "ARCH can only be x86_64 or ia_32" >&2
            exit 1
            ;;
    esac
    mkl_lib_dir="${MKLROOT}/lib/${mkl_arch_dir}"
    # check we have required libraries
    mkl_required_libs="libmkl_gf_lp64.a libmkl_core.a libmkl_sequential.a"
    for ii in $mkl_required_libs ; do
        if [ ! -f $mkl_lib_dir/${ii} ] ; then
            echo "missing MKL library ${ii}" >&2
            exit 1
        fi
    done
    # set the correct lib flags from  MLK link adviser
    MATH_LIBS="-Wl,--start-group ${mkl_lib_dir}/libmkl_gf_lp64.a ${mkl_lib_dir}/libmkl_core.a ${mkl_lib_dir}/libmkl_sequential.a"
    # check optional libraries
    if [ $enable_mpi = "__TRUE__" ] ; then
        enable_mkl_scalapack="__TRUE__"
        mkl_optional_libs="libmkl_scalapack_lp64.a"
        if [ "$with_openmpi" != "__DONTUSE__" ] ; then
            mkl_optional_libs="$mkl_optional_libs libmkl_blacs_openmpi_lp64.a"
            mkl_blacs_lib="libmkl_blacs_openmpi_lp64.a"
        elif [ "$with_mpich" != "__DONTUSE__" ] ; then
            mkl_optional_libs="$mkl_optional_libs libmkl_blacs_lp64.a"
            mkl_blacs_lib="libmkl_blacs_lp64.a"
        else
            enable_mkl_scalapack="__FALSE__"
        fi
        for ii in $mkl_optional_libs ; do
            if [ ! -f ${mkl_lib_dir}/${ii} ] ; then
                enable_mlk_scalapack="__FALSE__"
            fi
        done
        if [ $enable_mlk_scalapack = "__TRUE__" ] ; then
            echo "using MKL provided ScaLAPACK and BLACS"
            with_scalapack="__DONTUSE__"
            CP_DFLAGS="${CP_DFLAGS} IF_MPI(-D__SCALAPACK,)"
            MATH_LIBS="${mkl_lib_dir}/libmkl_scalapack_lp64.a ${MATH_LIBS} ${mkl_lib_dir}/${mkl_blacs_lib}"
        fi
    fi
    MATH_LIBS="${MATH_LIBS} -Wl,--end-group -lpthread -lm -ldl"
    MATH_CFLAGS="${MATH_CFLAGS} -I${MKLROOT}/include"
    CP_CFLAGS="$(unique ${CP_CFLAGS} ${MATH_CFLAGS})"
    CP_LIBS="$(unique ${MATH_LIBS} ${CP_LIBS})"
fi

# ----------------------------------------------------------------------
# OpenBLAS
# ----------------------------------------------------------------------
case "$with_openblas" in
    __INSTALL__)
        echo "==================== Installing OpenBLAS===================="
        if [ -f xianyi-OpenBLAS-${openblas_ver}.zip ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/xianyi-OpenBLAS-${openblas_ver}.zip
            checksum xianyi-OpenBLAS-${openblas_ver}.zip "$ROOTDIR/checksums.sha256"
            unzip xianyi-OpenBLAS-${openblas_ver}.zip >& unzip.log
            cd xianyi-OpenBLAS-*
            # Originally we try to install both the serial and the omp
            # threaded version. Unfortunately, neither is thread-safe
            # (i.e. the CP2K ssmp and psmp version need to link to
            # something else, the omp version is unused)
            make -j $nprocs \
                 USE_THREAD=0 \
                 PREFIX=${INSTALLDIR} \
                 >& make.serial.log
            make -j $nprocs \
                 USE_THREAD=0 \
                 PREFIX=${INSTALLDIR} \
                 install >& install.serial.log
            # make clean >& clean.log
            # make -j $nprocs \
            #      USE_THREAD=1 \
            #      USE_OPENMP=1 \
            #      LIBNAMESUFFIX=omp \
            #      PREFIX=${INSTALLDIR} \
            #      >& make.omp.log
            # make -j $nprocs \
            #      USE_THREAD=1 \
            #      USE_OPENMP=1 \
            #      LIBNAMESUFFIX=omp \
            #      PREFIX=${INSTALLDIR} \
            #      install >& install.omp.log
            cd ..
        fi
        MATH_CFLAGS="$(unique ${MATH_CFLAGS} -I'${INSTALLDIR}/include')"
        MATH_LDFLAGS="$(unique ${MATH_LDFLAGS} -L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib')"
        ;;
    __SYSTEM__)
        check_lib -lopenblas
        add_include_from_paths MATH_CFLAGS "openblas_config.h" $INCLUDE_PATHS
        add_lib_from_paths MATH_LDFLAGS "libopenblas.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_openblas" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH "$with_openblas/lib"
prepend_path LD_RUN_PATH "$with_openblas/lib"
prepend_path LIBRARY_PATH "$with_openblas/lib"
prepend_path CPATH "$with_openblas/include"
EOF
            MATH_CFLAGS="${MATH_CFLAGS} -I'$with_openblas/include'"
            MATH_LDFLAGS="${MATH_LDFLAGS} -L'$with_openblas/lib' -Wl,-rpath='$with_openblas/lib'"
        else
            echo "Cannot find $with_openblas" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_openblas" != "__DONTUSE__" ] ; then
    MATH_LIBS="-lopenblas"
    CP_CFLAGS="$(unique ${CP_CFLAGS} ${MATH_CFLAGS})"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${MATH_LDFLAGS})"
    CP_LIBS="${MATH_LIBS} ${CP_LIBS}"
fi

# ----------------------------------------------------------------------
# LibSMM
# ----------------------------------------------------------------------
case "$with_libsmm" in
    __INSTALL__)
        echo "==================== Installing libsmm ===================="
        # Here we attempt to determine which libsmm to download, and
        # do that if it exists.
        #
        # If openblas is also installed using this script, then we
        # use info on the architecture / core from the openblas
        # build. Otherwise, we use the architecture info defined from
        # ARCH variable passed to this script

        # helper to check if libsmm is available (uses https-redirect
        # to find latest version)
        libsmm_exists() {
            query_url=https://www.cp2k.org/static/downloads/libsmm/$1-latest.a
            reply_url=`curl $query_url -s -L -I -o /dev/null -w '%{url_effective}'`
            if [ "$query_url" != "$reply_url" ]; then
                echo $reply_url | cut -d/ -f7
            fi
        }

        libsmm=''
        if [ "$with_openblas" = "__INSTALL__" ] ; then
            # where is the openblas configuration file, which gives us the
            # core
            openblas_conf=$(echo ${ROOTDIR}/build/*OpenBLAS*/Makefile.conf)
            if [ ! -f "$openblas_conf" ]; then
                echo "Could not find OpenBLAS' Makefile.conf: $openblas_conf" >&2
                exit 1
            fi
            openblas_libcore=$(grep 'LIBCORE=' $openblas_conf | cut -f2 -d=)
            openblas_arch=$(grep 'ARCH=' $openblas_conf | cut -f2 -d=)
            libsmm=$(libsmm_exists libsmm_dnn_${openblas_libcore})
            if [ "x$libsmm" != "x" ] ; then
                echo "An optimized libsmm $libsmm is available"
            else
                libsmm=$(libsmm_exists libsmm_dnn_${openblas_arch})
                if [ "x$libsmm" != "x" ] ; then
                    echo "A generic libsmm $libsmm is available."
                    echo "Consider building and contributing to CP2K an optimized"
                    echo "libsmm for your $openblas_arch $openblas_libcore using"
                    echo "the toolkit in tools/build_libsmm provided in cp2k package"
                fi
            fi
        else
            # use ARCH to find a generic libsmm binary
            libsmm=$(libsmm_exists libsmm_dnn_${ARCH})
            if [ "x$libsmm" != "x" ] ; then
                echo "A generic libsmm $libsmm is available."
                echo "Consider building an optimized libsmm on your system yourself"
                echo "using the toolkit in tools/build_libsmm provided in cp2k package"
            fi
        fi
        # we know what to get, proceed with install
        if [ "x$libsmm" != "x" ]; then
            if [ -f $libsmm ]; then
                echo "Installation already started, skipping it."
            else
                wget --no-check-certificate https://www.cp2k.org/static/downloads/libsmm/$libsmm
                checksum $libsmm "$ROOTDIR/checksums.sha256"
                ! [ -d "${INSTALLDIR}/lib" ] && mkdir -p "${INSTALLDIR}/lib"
                cp $libsmm "${INSTALLDIR}/lib/"
                ln -s "${INSTALLDIR}/lib/$libsmm" "${INSTALLDIR}/lib/libsmm_dnn.a"
            fi
        else
            echo "No libsmm is available"
            echo "Consider building an optimized libsmm on your system yourself"
            echo "using the toolkid in tools/build_libsmm provided in cp2k package"
            with_libsmm="__DONTUSE__"
        fi
        LIBSMM_LDFLAGS="-L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib'"
        ;;
    __SYSTEM__)
        check_lib -lsmm_dnn
        add_lib_from_paths LIBSMM_LDFLAGS "libsmm_dnn.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_libsmm" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH $with_libsmm/lib
prepend_path LD_RUN_PATH $with_libsmm/lib
prepend_path LIBRARY_PATH $with_libsmm/lib
EOF
            LIBSMM_LDFLAGS="-L'${with_libsmm}/lib' -Wl,-rpath='${with_libsmm}/lib'"
        else
            echo "Cannot find $with_libsmm" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_libsmm" != "__DONTUSE__" ] ; then
    CP_DFLAGS="${CP_DFLAGS} IF_VALGRIND(,-D__HAS_smm_dnn)"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${LIBSMM_LDFLAGS})"
    CP_LIBS="IF_VALGRIND(,-lsmm_dnn) ${CP_LIBS}"
fi

# run setup file to update environment again before proceeding
source $SETUPFILE

# ----------------------------------------------------------------------
# ScaLAPACK
# ----------------------------------------------------------------------
case "$with_scalapack" in
    __INSTALL__)
        echo "==================== Installing ScaLAPACK ===================="
        if [ -f scalapack-${scalapack_ver}.tgz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/scalapack-${scalapack_ver}.tgz
            checksum scalapack-${scalapack_ver}.tgz "$ROOTDIR/checksums.sha256"
            tar -xzf scalapack-${scalapack_ver}.tgz
            # we dont know the version
            cd scalapack-${scalapack_ver}
            cat << EOF > SLmake.inc
CDEFS         = -DAdd_
FC            = mpif90
CC            = mpicc
NOOPT         = ${FFLAGS} -O0 -fno-fast-math
FCFLAGS       = ${FFLAGS} ${MATH_CFLAGS}
CCFLAGS       = ${CFLAGS} ${MATH_CFLAGS}
FCLOADER      = \$(FC)
CCLOADER      = \$(CC)
FCLOADFLAGS   = \$(FCFLAGS) ${MATH_LDFLAGS}
CCLOADFLAGS   = \$(CCFLAGS) ${MATH_LDFLAGS}
ARCH          = ar
ARCHFLAGS     = cr
RANLIB        = ranlib
SCALAPACKLIB  = libscalapack.a
BLASLIB       =
LAPACKLIB     = ${MATH_LIBS}
LIBS          = \$(LAPACKLIB) \$(BLASLIB)
EOF
            # scalapack build not parallel safe (update to the archive race)
            make -j 1 lib >& make.log
            ! [ -d "${INSTALLDIR}/lib" ] && mkdir -p "${INSTALLDIR}/lib"
            cp libscalapack.a "${INSTALLDIR}/lib/"
            cd ..
        fi
        MATH_LDFLAGS="$(unique ${MATH_LDFLAGS} -L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib')"
        ;;
    __SYSTEM__)
        check_lib -lscalapack
        add_lib_from_paths MATH_LDFLAGS "libscalapack.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_scalapack" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH "$with_scalapack/lib"
prepend_path LD_RUN_PATH "$with_scalapack/lib"
prepend_path LIBRARY_PATH "$with_scalapack/lib"
prepend_path CPATH "$with_scalapack/include"
EOF
            MATH_LDFLAGS="${MATH_LDFLAGS} -L'$with_scalapack/lib' -Wl,-rpath='$with_scalapack/lib'"
        else
            echo "Cannot find $with_scalapack" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_scalapack" != "__DONTUSE__" ] ; then
    CP_DFLAGS="${CP_DFLAGS} IF_MPI(-D__SCALAPACK,)"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${MATH_LDFLAGS})"
    CP_LIBS="IF_MPI(-lscalapack,) ${CP_LIBS}"
    MATH_LIBS="${MATH_LIBS} -lscalapack"
fi

# reload the setup file again to get the correct paths for ELPA
source $SETUPFILE

case "$with_elpa" in
    __INSTALL__)
        echo "==================== Installing ELPA ===================="
        if [ -f elpa-${elpa_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/elpa-${elpa_ver}.tar.gz
            checksum elpa-${elpa_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf elpa-${elpa_ver}.tar.gz

            # need both flavors ?

            # elpa expect FC to be an mpi fortran compiler that is happy
            # with long lines, and that a bunch of libs can be found
            cd elpa-${elpa_ver}
            # non-threaded version
            ./configure  --prefix=${INSTALLDIR} \
                         --enable-openmp=no \
                         FC="mpif90 -ffree-line-length-none" \
                         CC="mpicc" \
                         CXX="mpic++" \
                         FCFLAGS="${FCFLAGS} ${MATH_CFLAGS}" \
                         CFLAGS="${CFLAGS} ${MATH_CFLAGS}" \
                         CXXFLAGS="${CXXFLAGS} ${MATH_CFLAGS}" \
                         LDFLAGS="${MATH_LDFLAGS}" \
                         LIBS="${MATH_LIBS}" \
                         >& config.log
            make -j $nprocs >&  make.log
            make install >& install.log
            ELPA_CFLAGS="-I${INSTALLDIR}/include/elpa-${elpa_ver}/modules"
            # threaded version
            if [ $enable_omp = "__TRUE__" ] ; then
                make -j $nprocs clean
                ./configure  --prefix=${INSTALLDIR} \
                             --enable-openmp=yes \
                             FC="mpif90 -ffree-line-length-none" \
                             CC="mpicc" \
                             CXX="mpic++" \
                             FCFLAGS="${FCFLAGS} ${MATH_CFLAGS}" \
                             CFLAGS="${CFLAGS} ${MATH_CFLAGS}" \
                             CXXFLAGS="${CXXFLAGS} ${MATH_CFLAGS}" \
                             LDFLAGS="${MATH_LDFLAGS}" \
                             LIBS="${MATH_LIBS}" \
                             >& config.log
                make -j $nprocs >&  make.log
                make install >& install.log
                ELPA_CFLAGS_OMP="-I${INSTALLDIR}/include/elpa_openmp-${elpa_ver}/modules"
            fi
            cd ..
        fi
        ELPA_LDFLAGS="-L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib'"
        ;;
    __SYSTEM__)
        check_lib -lelpa "ELPA"
        check_lib -lelpa_openmp "ELPA"
        ELPA_CFLAGS="$(find_in_paths "elpa-*" $INCLUDE_PATHS)"
        if [ "$ELPA_CFLAGS" != "__FALSE__" ] ; then
            echo "ELPA include directory is found to be $ELPA_CFLAGS/modules"
            ELPA_CFLAGS="-I'$ELPA_CFLAGS/modules'"
        else
            echo "Cannot find elpa-* from paths $INCLUDE_PATHS"
            exit 1
        fi
        if [ $enable_omp = "__TRUE__" ] ; then
            ELPA_CFLAGS_OMP="$(find_in_paths "elpa_openmp-*" $INCLUDE_PATHS)"
            if [ "$ELPA_CFLAGS_OMP" != "__FALSE__" ] ; then
                echo "ELPA include directory threaded version is found to be $ELPA_CFLAGS_OMP/modules"
                ELPA_CFLAGS_OMP="-I'$ELPA_CFLAGS_OMP/modules'"
            else
                echo "Cannot find elpa_openmp-${elpa_ver} from paths $INCLUDE_PATHS"
                exit 1
            fi
        fi
        add_lib_from_paths ELPA_LDFLAGS "libelpa.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_elpa" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH "$with_elpa/lib"
prepend_path LD_RUN_PATH "$with_elpa/lib"
prepend_path LIBRARY_PATH "$with_elpa/lib"
prepend_path CPATH "$with_elpa/include"
EOF
            user_include_path="$with_elpa/include"
            ELPA_CFLAGS="$(find_in_paths "elpa-*" user_include_path)"
            if [ "$ELPA_CFLAGS" != "__FALSE__" ] ; then
                echo "ELPA include directory is found to be $ELPA_CFLAGS/modules"
                ELPA_CFLAGS="-I'$ELPA_CFLAGS/modules'"
            else
                echo "Cannot find elpa-* from path $user_include_path"
                exit 1
            fi
            ELPA_CFLAGS_OMP="$(find_in_paths "elpa_openmp-*" user_include_path)"
            if [ "$ELPA_CFLAGS_OMP" != "__FALSE__" ] ; then
                echo "ELPA include directory threaded version is found to be $ELPA_CFLAGS_OMP/modules"
                ELPA_CFLAGS_OMP="-I'$ELPA_CFLAGS_OMP/modules'"
            else
                echo "Cannot find elpa_openmp-* from path $user_include_path"
                exit 1
            fi
            ELPA_LDFLAGS="${ELPA_LDFLAGS} -L'$with_elpa/lib' -Wl,-rpath='$with_elpa/lib'"
        else
            echo "Cannot find $with_elpa" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_elpa" != "__DONTUSE__" ] ; then
    CP_DFLAGS="${CP_DFLAGS} IF_MPI(-D__ELPA3,)"
    CP_CFLAGS="${CP_CFLAGS} IF_MPI(IF_OMP(${ELPA_CFLAGS_OMP},${ELPA_CFLAGS}),)"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${ELPA_LDFLAGS})"
    CP_LIBS="IF_MPI(IF_OMP(-lelpa_openmp,-lelpa),) ${CP_LIBS}"
fi


# ----------------------------------------------------------------------
# PT-Scotch
# ----------------------------------------------------------------------
case "$with_scotch" in
    __INSTALL__)
        echo "==================== Installing PT-Scotch ===================="
        if [ -f scotch_${scotch_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/scotch_${scotch_ver}.tar.gz
            checksum scotch_${scotch_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf scotch_${scotch_ver}.tar.gz
            cd scotch_${scotch_ver}/src
            cat Make.inc/Makefile.inc.x86-64_pc_linux2 | \
                sed "s|\(^CFLAGS\).*|\1 =  $CFLAGS -DCOMMON_RANDOM_FIXED_SEED -DSCOTCH_RENAME -Drestrict=__restrict -DIDXSIZE64|" > Makefile.inc
            make scotch -j $nprocs >& make.log
            make ptscotch -j $nrocs >& make.log
            make install prefix=${INSTALLDIR} >& install.log
            cd ../..
        fi
        SCOTCH_CFLAGS="-I'${INSTALLDIR}/include'"
        SCOTCH_LDFLAGS="-L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib'"
        ;;
    __SYSTEM__)
        check_lib -lptscotch "PT-Scotch"
        check_lib -lptscotcherr "PT-Scotch"
        check_lib -lscotchmetis "PT-Scotch"
        check_lib -lscotch "PT-Scotch"
        check_lib -lscotcherr "PT-Scotch"
        check_lib -lptscotchparmetis "PT-Scotch"
        add_include_from_paths SCOTCH_CFLAGS "ptscotch.h" $INCLUDE_PATHS
        add_lib_from_paths SCOTCH_LDFLAGS "libptscotch.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_scotch" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path PATH "$with_scotch/bin"
prepend_path LD_LIBRARY_PATH "$with_scotch/lib"
prepend_path LD_RUN_PATH "$with_scotch/lib"
prepend_path LIBRARY_PATH "$with_scotch/lib"
prepend_path CPATH "$with_scotch/include"
EOF
            SCOTCH_CFLAGS="-I'$with_scotch/include'"
            SCOTCH_LDFLAGS="-L'$with_scotch/lib' -Wl,-rpath='$with_scotch/lib'"
        else
            echo "Cannot find $with_scotch" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_scotch" != "__DONTUSE__" ] ; then
    CP_CFLAGS="$(unique ${CP_CFLAGS} $SCOTCH_CFLAGS)"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${SCOTCH_LDFLAGS})"
    CP_LIBS="IF_MPI(-lptscotch -lptscotcherr -lscotchmetis -lscotch -lscotcherr,) ${CP_LIBS}"
fi

case "$with_parmetis" in
    __INSTALL__)
        echo "==================== Installing ParMETIS ===================="
        if [ -f parmetis-${parmetis_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/parmetis-${parmetis_ver}.tar.gz
            checksum parmetis-${parmetis_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf parmetis-${parmetis_ver}.tar.gz
            cd parmetis-${parmetis_ver}
            make config prefix=${INSTALLDIR} >& config.log
            make -j $nprocs >& make.log
            make install >& install.log
            # Have to build METIS again independently due to bug in ParMETIS make install
            echo "==================== Installing METIS ===================="
            cd metis
            make config prefix=${INSTALLDIR} >& config.log
            make -j $nprocs >& make.log
            make install >& install.log
            cd ../..
        fi
        PARMETIS_CFLAGS="-I'${INSTALLDIR}/include'"
        PARMETIS_LDFLAGS="-L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib'"
        ;;
    __SYSTEM__)
        check_lib -lparmetis "ParMETIS"
        add_include_from_paths PARMETIS_CFLAGS "parmetis.h" $INCLUDE_PATHS
        add_lib_from_paths PARMETIS_LDFLAGS "libparmetis.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_parmetis" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path PATH "$with_parmetis/bin"
prepend_path LD_LIBRARY_PATH "$with_parmetis/lib"
prepend_path LD_RUN_PATH "$with_parmetis/lib"
prepend_path LIBRARY_PATH "$with_parmetis/lib"
prepend_path CPATH "$with_parmetis/include"
EOF
            PARMETIS_CFLAGS="-I'$with_parmetis/include'"
            PARMETIS_LDFLAGS="-L'$with_parmetis/lib' -Wl,-rpath='$with_parmetis/lib'"
        else
            echo "Cannot find $with_parmetis" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_parmetis" != "__DONTUSE__" ] ; then
    CP_CFLAGS="$(unique ${CP_CFLAGS} ${PARMETIS_CFLAGS})"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${PARMETIS_LDFLAGS})"
    CP_LIBS="IF_MPI(-lptscotchparmetis,) ${CP_LIBS}"
fi


case "$with_metis" in
    __INSTALL__)
        echo "METIS is installed together with ParMETIS"
        if [ "$with_parmetis" = "__INSTALL__" ] ; then
            METIS_CFLAGS="-I'${INSTALLDIR}/include'"
            METIS_LDFLAGS="-L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib'"
        else
            echo "Use option --with-parmetis=install to install METIS"
            exit 1
        fi
        ;;
    __SYSTEM__)
        check_lib -lmetis "METIS"
        add_include_from_paths METIS_CFLAGS "metis.h" $INCLUDE_PATHS
        add_lib_from_paths METIS_LDFLAGS "libmetis.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_metis" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path PATH "$with_metis/bin"
prepend_path LD_LIBRARY_PATH "$with_metis/lib"
prepend_path LD_RUN_PATH "$with_metis/lib"
prepend_path LIBRARY_PATH "$with_metis/lib"
prepend_path CPATH "$with_metis/include"
EOF
            METIS_CFLAGS="-I'$with_metis/include'"
            METIS_LDFLAGS="-L'$with_metis/lib' -Wl,-rpath='$with_metis/lib'"
        else
            echo "Cannot find $with_metis" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_metis" != "__DONTUSE__" ] ; then
    CP_CFLAGS="$(unique ${CP_CFLAGS} ${METIS_CFLAGS})"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${METIS_LDFLAGS})"
fi

case "$with_superlu_dist" in
    __INSTALL__)
        echo "==================== Installing SuperLU_DIST ===================="
        if [ -f superlu_dist_${superlu_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/superlu_dist_${superlu_ver}.tar.gz
            checksum superlu_dist_${superlu_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf superlu_dist_${superlu_ver}.tar.gz
            cd SuperLU_DIST_${superlu_ver}
            mv make.inc make.inc.orig
            cat <<EOF >> make.inc
PLAT=_${ARCH}
DSUPERLULIB= ${PWD}/lib/libsuperlu_dist_${superlu_ver}.a
LIBS=\$(DSUPERLULIB) $(unique ${PARMETIS_LDFLAGS} ${METIS_LDFLAGS} ${MATH_LDFLAGS}) -lparmetis -lmetis  ${MATH_LIBS}
ARCH=ar
ARCHFLAGS=cr
RANLIB=ranlib
CC=mpicc
CFLAGS=${CFLAGS} $(unique ${PARMETIS_CFLAGS} ${METIS_CFLAGS} ${MATH_CFLAGS})
NOOPTS=-O0
FORTRAN=mpif90
F90FLAGS=${FFLAGS}
LOADER=\$(CC)
LOADOPTS=${CFLAGS}
CDEFS=-DAdd_
EOF
            make &> make.log #-j $nprocs will crash
            # no make install
            chmod a+r lib/* SRC/*.h
            ! [ -d "${INSTALLDIR}/lib" ] && mkdir -p "${INSTALLDIR}/lib"
            cp lib/libsuperlu_dist_${superlu_ver}.a "${INSTALLDIR}/lib/"
            mkdir -p "${INSTALLDIR}/include/superlu_dist_${superlu_ver}"
            cp SRC/*.h "${INSTALLDIR}/include/superlu_dist_${superlu_ver}/"
            cd ..
        fi
        SUPERLU_DIST_CFLAGS="-I'${INSTALLDIR}/include/superlu_dist_${superlu_ver}'"
        SUPERLU_DIST_LDFLAGS="-L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib'"
        SUPERLU_DIST_LIBS="-lsuperlu_dist_${superlu_ver}"
        ;;
    __SYSTEM__)
        check_lib -lsuperlu_dist "SuperLU_DIST"
        add_include_from_paths SUPERLU_DIST_CFLAGS "superlu*" $INCLUDE_PATHS
        add_lib_from_paths SUPERLU_DIST_LDFLAGS "libsuperlu*" $LIB_PATHS
        SUPERLU_DIST_LIBS="-lsuperlu_dist"
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_superlu_dist" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path PATH "$with_superlu_dist/bin"
prepend_path LD_LIBRARY_PATH "$with_superlu_dist/lib"
prepend_path LD_RUN_PATH "$with_superlu_dist/lib"
prepend_path LIBRARY_PATH "$with_superlu_dist/lib"
prepend_path CPATH "$with_superlu_dist/include"
EOF
            SUPERLU_DIST_CFLAGS="-I'$with_superlu_dist/include'"
            SUPERLU_DIST_LDFLAGS="-L'$with_superlu_dist/lib' -Wl,-rpath='$with_superlu_dist/lib'"
            SUPERLU_DIST_LIBS="-lsuperlu_dist"
        else
            echo "Cannot find $with_superlu_dist" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_superlu_dist" != "__DONTUSE__" ] ; then
    CP_CFLAGS="$(unique ${CP_CFLAGS} ${SUPER_DIST_CFLAGS})"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${SUPER_DIST_LDFLAGS})"
    CP_LIBS="IF_MPI(${SUPERLU_DIST_LIBS},) ${CP_LIBS}"
fi

# ----------------------------------------------------------------------
# PEXSI
# ----------------------------------------------------------------------
case "$with_pexsi" in
    __INSTALL__)
        echo "==================== Installing PEXSI ===================="
        if [ -f pexsi_v${pexsi_ver}.tar.gz ]; then
            echo "Installation already started, skipping it."
        else
            wget --no-check-certificate https://www.cp2k.org/static/downloads/pexsi_v${pexsi_ver}.tar.gz
            #wget --no-check-certificate https://math.berkeley.edu/~linlin/pexsi/download/pexsi_v${pexsi_ver}.tar.gz
            checksum pexsi_v${pexsi_ver}.tar.gz "$ROOTDIR/checksums.sha256"
            tar -xzf pexsi_v${pexsi_ver}.tar.gz
            cd pexsi_v${pexsi_ver}
            cat config/make.inc.linux.gnu | \
                sed -e "s|\(PAR_ND_LIBRARY *=\).*|\1 parmetis|" \
                    -e "s|\(SEQ_ND_LIBRARY *=\).*|\1 metis|" \
                    -e "s|\(PEXSI_DIR *=\).*|\1 ${PWD}|" \
                    -e "s|\(CPP_LIB *=\).*|\1 -lstdc++ ${mpiextralibs} -lmpi -lmpi_cxx |" \
                    -e "s|\(LAPACK_LIB *=\).*|\1 ${MATH_LDFLAGS} ${MATH_LIBS}|" \
                    -e "s|\(BLAS_LIB *=\).*|\1|" \
                    -e "s|\(\bMETIS_LIB *=\).*|\1 ${METIS_LDFLAGS} -lmetis|" \
                    -e "s|\(PARMETIS_LIB *=\).*|\1 ${PARMETIS_LDFLAGS} -lparmetis|" \
                    -e "s|\(DSUPERLU_LIB *=\).*|\1 ${SUPERLU_DIST_LDFLAGS} ${SUPERLU_DIST_LIBS}|" \
                    -e "s|\(SCOTCH_LIB *=\).*|\1 ${SCOTCH_LDFLAGS} -lscotchmetis -lscotch -lscotcherr|" \
                    -e "s|\(PTSCOTCH_LIB *=\).*|\1 ${SCOTCH_LDFLAGS} -lptscotchparmetis -lptscotch -lptscotcherr -lscotch|" \
                    -e "s|#FLOADOPTS *=.*|FLOADOPTS    = \${LIBS} \${CPP_LIB}|" \
                    -e "s|\(DSUPERLU_INCLUDE *=\).*|\1 ${SUPERLU_DIST_CFLAGS}|" \
                    -e "s|\(INCLUDES *=\).*|\1 $(unique ${METIS_CFLAGS} ${PARMETIS_CFLAGS} ${MATH_CFLAGS}) \${DSUPERLU_INCLUDE} \${PEXSI_INCLUDE}|" \
                    -e "s|\(COMPILE_FLAG *=\).*|\1 ${CFLAGS} -fpermissive|" \
                    -e "s|\(SUFFIX *=\).*|\1 linux_v${pexsi_ver}|" \
                    -e "s|\(DSUPERLU_DIR *=\).*|\1|" \
                    -e "s|\(METIS_DIR *=\).*|\1|" \
                    -e "s|\(PARMETIS_DIR *=\).*|\1|" \
                    -e "s|\(PTSCOTCH_DIR *=\).*|\1|" \
                    -e "s|\(LAPACK_DIR *=\).*|\1|" \
                    -e "s|\(BLAS_DIR *=\).*|\1|" \
                    -e "s|\(GFORTRAN_LIB *=\).*|\1|" > make.inc
            cd src
            make -j $nprocs >& make.log
            # no make install
            chmod a+r libpexsi_linux_v${pexsi_ver}.a
            ! [ -d "${INSTALLDIR}/lib" ] && mkdir -p "${INSTALLDIR}/lib"
            cp libpexsi_linux_v${pexsi_ver}.a "${INSTALLDIR}/lib/"
            # make fortran interface
            cd ../fortran
            make >& make.log #-j $nprocs will crash
            chmod a+r f_ppexsi_interface.mod
            cp f_ppexsi_interface.mod ${INSTALLDIR}/include/
            cd ..
            # no need to install PEXSI headers
            #mkdir -p ${INSTALLDIR}/include/pexsi_v${pexsi_ver}
            #cp include/* ${INSTALLDIR}/include/pexsi_v${pexsi_ver}/
            cd ..
        fi
        PEXSI_LDFLAGS="-L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib'"
        PEXSI_LIB="-lpexsi_linux_v${pexsi_ver}"
        ;;
    __SYSTEM__)
        check_lib -lpexsi "PEXSI"
        add_lib_from_paths PEXSI_LDFLAGS "libpexsi.*" $LIB_PATHS
        PEXSI_LIB="-lpexsi"
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_pexsi" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH "$with_pexsi/lib"
prepend_path LD_RUN_PATH "$with_pexsi/lib"
prepend_path LIBRARY_PATH "$with_pexsi/lib"
prepend_path CPATH "$with_pexsi/include"
EOF
            PEXSI_LDFLAGS="-L'${with_pexsi}/lib' -Wl,-rpath='${with_pexsi}/lib'"
            PEXSI_LIB="-lpexsi"
        else
            echo "Cannot find $with_pexsi" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_pexsi" != "__DONTUSE__" ] ; then
    CP_DFLAGS="${CP_DFLAGS} IF_MPI(-D__LIBPEXSI,)"
    CP_LDFLAGS=$(unique ${CP_LDFLAGS} ${PEXSI_LDFLAGS})
    CP_LIBS="IF_MPI(${PEXSI_LIB},) ${CP_LIBS}"
fi

case "$with_quip" in
    __INSTALL__)
        echo "==================== Installing QUIP ===================="
        if [ $enable_tsan = __TRUE__ ] ; then
            echo "TSAN build ... will not use QUIP"
        else
            if [ -f QUIP-${quip_ver}.zip  ]; then
                echo "Installation already started, skipping it."
            else
                wget --no-check-certificate https://www.cp2k.org/static/downloads/QUIP-${quip_ver}.zip
                checksum QUIP-${quip_ver}.zip "$ROOTDIR/checksums.sha256"
                unzip QUIP-${quip_ver}.zip >& unzip.log
                cd QUIP-${quip_ver}
                # enable debug symbols
                echo "F95FLAGS       += -g" >> arch/Makefile.linux_${ARCH}_gfortran
                echo "F77FLAGS       += -g" >> arch/Makefile.linux_${ARCH}_gfortran
                echo "CFLAGS         += -g" >> arch/Makefile.linux_${ARCH}_gfortran
                echo "CPLUSPLUSFLAGS += -g" >> arch/Makefile.linux_${ARCH}_gfortran
                export QUIP_ARCH=linux_${ARCH}_gfortran
                # hit enter a few times to accept defaults
                echo -e "${MATH_LDFLAGS} ${MATH_LIBS} \n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n" | make config > config.log
                # make -j does not work :-(
                make >& make.log
                ! [ -d "${INSTALLDIR}/include" ] && mkdir -p "${INSTALLDIR}/include"
                ! [ -d "${INSTALLDIR}/lib" ] && mkdir -p "${INSTALLDIR}/lib"
                cp build/linux_x86_64_gfortran/quip_unified_wrapper_module.mod  "${INSTALLDIR}/include/"
                cp build/linux_x86_64_gfortran/*.a                              "${INSTALLDIR}/lib/"
                cp src/FoX-4.0.3/objs.linux_${ARCH}_gfortran/lib/*.a            "${INSTALLDIR}/lib/"
                cd ..
            fi
        fi
        QUIP_CFLAGS="-I'${INSTALLDIR}/include'"
        QUIP_LDFLAGS="-L'${INSTALLDIR}/lib' -Wl,-rpath='${INSTALLDIR}/lib'"
        ;;
    __SYSTEM__)
        check_lib -lquip_core "QUIP"
        check_lib -latoms "QUIP"
        check_lib -lFoX_sax "QUIP"
        check_lib -lFoX_common "QUIP"
        check_lib -lFoX_utils "QUIP"
        check_lib -lFoX_fsys "QUIP"
        add_include_from_paths QUIP_CFLAGS "quip*" $INCLUDE_PATHS
        add_lib_from_paths QUIP_LDFLAGS "libquip_core*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        if [ -d "$with_quip" ] ; then
            cat <<EOF >> $SETUPFILE
prepend_path LD_LIBRARY_PATH "$with_quip/lib"
prepend_path LD_RUN_PATH "$with_quip/lib"
prepend_path LIBRARY_PATH "$with_quip/lib"
prepend_path CPATH "$with_quip/include"
EOF
            QUIP_CFLAGS="-I'${with_quip}/include'"
            QUIP_LDFLAGS="-L'${with_quip}/lib' -Wl,-rpath='${with_quip}/lib'"
        else
            echo "Cannot find $with_quip" >&2
            exit 1
        fi
        ;;
esac
if [ "$with_quip" != "__DONTUSE__" ] ; then
    CP_DFLAGS="${CP_DFLAGS} -D__QUIP"
    CP_CFLAGS="$(unique ${CP_CFLAGS} ${QUIP_CFLAGS})"
    CP_LDFLAGS="$(unique ${CP_LDFLAGS} ${QUIP_LDFLAGS})"
    CP_LIBS="-lquip_core -latoms -lFoX_sax -lFoX_common -lFoX_utils -lFoX_fsys ${CP_LIBS}"
fi

# ----------------------------------------------------------------------
# generate arch file for compiling cp2k
# ----------------------------------------------------------------------

echo "==================== generating arch files ===================="
echo "arch files can be found in the ${INSTALLDIR}/arch subdirectory"
mkdir -p ${INSTALLDIR}/arch
cd ${INSTALLDIR}/arch

# add standard libs
LIBS="${CP_LIBS} -lstdc++"

# we always want good line information and backtraces
BASEFLAGS="${BASEFLAGS} -march=native -fno-omit-frame-pointer -g ${TSANFLAGS}"
#For gcc 6.0 use -O1 -coverage -fkeep-static-functions -D__NO_ABORT
BASEFLAGS="${BASEFLAGS} IF_COVERAGE(-O0 -coverage -D__NO_ABORT, IF_DEBUG(-O1,-O3 -ffast-math))"
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
if [ "$enable_cuda" = __TRUE__ ] ; then
    LIBS="${LIBS} IF_CUDA(-lcudart -lcufft -lcublas -lrt IF_DEBUG(-lnvToolsExt,),)"
    DFLAGS="IF_CUDA(-D__ACC -D__DBCSR_ACC -D__PW_CUDA IF_DEBUG(-D__CUDA_PROFILING,),) ${DFLAGS}"
    NVFLAGS="-arch sm_35 \$(DFLAGS) "
fi

# helper routine for instantiating the arch.tmpl
gen_arch_file() {
 local filename=$1
 local flags=$2
 local TMPL=$(cat ${ROOTDIR}/arch.tmpl)
 eval "printf \"$TMPL\"" | cpp -traditional-cpp -P ${flags} - > $filename
 echo "Wrote install/arch/"$filename
}

rm -f ${INSTALLDIR}/arch/local*
# normal production arch files
    { gen_arch_file "local.sopt" "";              arch_vers="sopt"; }
    { gen_arch_file "local.sdbg" "-DDEBUG";       arch_vers="${arch_vers} sdbg"; }
[ "$enable_omp" = __TRUE__ ] && \
    { gen_arch_file "local.ssmp" "-DOMP";         arch_vers="${arch_vers} ssmp"; }
[ "$enable_mpi" = __TRUE__ ] && \
    { gen_arch_file "local.popt" "-DMPI";         arch_vers="${arch_vers} popt"; }
[ "$enable_mpi" = __TRUE__ ] && \
    { gen_arch_file "local.pdbg" "-DMPI -DDEBUG"; arch_vers="${arch_vers} pdbg"; }
[ "$enable_mpi" = __TRUE__ ] && \
[ "$enable_omp" = __TRUE__ ] && \
    { gen_arch_file "local.psmp" "-DMPI -DOMP";   arch_vers="${arch_vers} psmp"; }
# cuda enabled arch files
if [ "$enable_cuda" = __TRUE__ ] ; then
    [ "$enable_omp" = __TRUE__ ] && \
        { gen_arch_file "local_cuda.ssmp" "-DCUDA -DOMP";               arch_cuda="ssmp"; }
    [ "$enable_mpi" = __TRUE__ ] && \
    [ "$enable_omp" = __TRUE__ ] && \
        { gen_arch_file "local_cuda.psmp" "-DCUDA -DOMP -DMPI";         arch_cuda="${arch_cuda} psmp"; }
    [ "$enable_omp" = __TRUE__ ] && \
        { gen_arch_file "local_cuda.sdbg" "-DCUDA -DDEBUG -DOMP";       arch_cuda="${arch_cuda} sdbg"; }
    [ "$enable_mpi" = __TRUE__ ] && \
    [ "$enable_omp" = __TRUE__ ] && \
        { gen_arch_file "local_cuda.pdbg" "-DCUDA -DDEBUG -DOMP -DMPI"; arch_cuda="${arch_cuda} pdbg"; }
    [ "$enable_mpi" = __TRUE__ ] && \
    [ "$enable_omp" = __TRUE__ ] && \
        { gen_arch_file "local_cuda_warn.psmp" "-DCUDA -DMPI -DOMP -DWARNALL"; }
fi
# valgrind enabled arch files
if [ "$with_valgrind" != __DONTUSE__ ] ; then
        { gen_arch_file "local_valgrind.sdbg" "-DVALGRIND";       arch_valg="sdbg"; }
    [ "$enable_mpi" = __TRUE__ ] && \
        { gen_arch_file "local_valgrind.pdbg" "-DVALGRIND -DMPI"; arch_valg="${arch_valgrind} pdbg"; }
fi
# coverage enabled arch files
if [ "$with_lcov" != __DONTUSE__ ]; then
        { gen_arch_file "local_coverage.sdbg" "-DCOVERAGE";       arch_cov="sdbg"; }
    [ "$enable_mpi" = __TRUE__ ] && \
        { gen_arch_file "local_coverage.pdbg" "-DCOVERAGE -DMPI"; arch_cov="${arch_cov} pdbg"; }
    [ "$enable_cuda" = __TRUE__ ] && \
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
