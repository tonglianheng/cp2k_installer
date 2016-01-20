#!/bin/bash -e

FAIL='[0;31mFAIL[0m'
PASS='[0;32mPASS[0m'

SYS_INCLUDE_PATH=${SYS_INCLUDE_PATH:-'/usr/local/include:/usr/include'}
SYS_LIB_PATH=${SYS_LIB_PATH:-'/user/local/lib64:/usr/local/lib:/usr/lib64:/usr/lib:/lib64:/lib'}
INCLUDE_PATHS=${INCLUDE_PATHS:-"CPATH SYS_INCLUDE_PATH"}
LIB_PATHS=${LIB_PATHS:-"LIBRARY_PATH LD_LIBRARY_PATH LD_RUN_PATH SYS_LIB_PATH"}
source ./tool_kit.sh

echo "SYS_INCLUDE_PATH = $SYS_INCLUDE_PATH"
echo "SYS_LIB_PATH = $SYS_LIB_PATH"
echo "INCLUDE_PATHS = $INCLUDE_PATHS"
echo "LIB_PATHS = $LIB_PATHS"

echo 'module load lib/libxc/2.2.2'
module load lib/libxc/2.2.2

echo realpath '"$LIBXC_INCLUDE/test tong.h"'
realpath "$LIBXC_INCLUDE/test tong.h" && echo $PASS || echo $FAIL
echo realpath '$LIBXC_INCLUDE/test*'
realpath $LIBXC_INCLUDE/test* && echo $PASS || echo $FAIL
echo realpath '$LIBXC_INCLUDE/test*.h'
realpath $LIBXC_INCLUDE/test*.h && echo $PASS || echo $FAIL

echo 'unique a a b b "a b" "a  b" "a b" a b'
unique a a b b "a b" "a  b" "a b" a b
[ "$(unique a a b b "a b" "a  b" "a b" a b)" = "a b a b a  b" ] && echo $PASS || echo $FAIL

echo 'get_nprocs'
get_nprocs

test_path1="blah/1/2:blah/1/3"
test_path2=""
test_path3=":blah/1/2::blah/2/2"
test_path4=":blah/1/2:blah/2/3:"
test_path5="blah/1/2:blah/2/3:blah special/df dd"
correct='-L"blah/1/2" -L"blah/1/3" -L"blah/2/2" -L"blah/2/3" -L"blah special/df dd"'
echo test_path1='"blah/1/2:blah/1/3"'
echo test_path2='""'
echo test_path3='":blah/1/2::blah/2/2"'
echo test_path4='":blah/1/2:blah/2/3:"'
echo test_path5='"blah/1/2:blah/2/3:blah special/df dd"'
echo  paths_to_ld test_path1 test_path2 test_path3 test_path4 test_path5
paths_to_ld test_path1 test_path2 test_path3 test_path4 test_path5
[ "$(paths_to_ld test_path1 test_path2 test_path3 test_path4 test_path5)" = "${correct}" ] \
    && echo $PASS || echo $FAIL

echo 'find_in_paths "libxc.a" $LIB_PATHS'
find_in_paths "libxc.a" $LIB_PATHS
[ "$(find_in_paths "libxc.a" $LIB_PATHS)" = "$LIBXC_LIB/libxc.a" ] && echo $PASS || echo $FAIL
echo 'find_in_paths "lib*.a" $LIB_PATHS'
find_in_paths "lib*.a" $LIB_PATHS
[ "$(find_in_paths "lib*.a" $LIB_PATHS)" = "$LIBXC_LIB/libxc.a" ] && echo $PASS || echo $FAIL
echo 'find_in_paths "*xc.*" $LIB_PATHS'
find_in_paths "*xc.*" $LIB_PATHS
[ "$(find_in_paths "*xc.*" $LIB_PATHS)" = "$LIBXC_LIB/libxc.a" ] && echo $PASS || echo $FAIL
echo 'find_in_paths "libint*" $LIB_PATHS '
find_in_paths "libint*" $LIB_PATHS
[ "$(find_in_paths "libint*" $LIB_PATHS)" = "__FALSE__" ] && echo $PASS || echo $FAIL
echo 'find_in_paths "test*" $INCLUDE_PATHS'
find_in_paths "test*" $INCLUDE_PATHS
[ "$(find_in_paths "test*" $INCLUDE_PATHS)" = "$LIBXC_INCLUDE/test tong.h" ] && echo $PASS || echo $FAIL

unset LIBXC_CFLAGS
echo 'add_include_from_paths LIBXC_CFLAGS "xc.h" $INCLUDE_PATHS'
add_include_from_paths LIBXC_CFLAGS "xc.h" $INCLUDE_PATHS
echo "LIBXC_CFLAGS = $LIBXC_CFLAGS"
[ "$LIBXC_CFLAGS" = "-I\"$LIBXC_INCLUDE\"" ] && echo $PASS || echo $FAIL
echo 'add_include_from_paths LIBXC_CFLAGS "*.h" $INCLUDE_PATHS'
add_include_from_paths LIBXC_CFLAGS "*.h" $INCLUDE_PATHS
echo "LIBXC_CFLAGS = $LIBXC_CFLAGS"
[ "$LIBXC_CFLAGS" = "-I\"$LIBXC_INCLUDE\"" ] && echo $PASS || echo $FAIL
echo 'add_include_from_paths LIBXC_CFLAGS "libint" $INCLUDE_PATHS'
add_include_from_paths LIBXC_CFLAGS "libint" $INCLUDE_PATHS
echo "LIBXC_CFLAGS = $LIBXC_CFLAGS"
[ "$LIBXC_CFLAGS" = "-I\"$LIBXC_INCLUDE\"" ] && echo $PASS || echo $FAIL
echo 'module load lib/libint/1.1.4'
module load lib/libint/1.1.4
echo 'add_include_from_paths LIBXC_CFLAGS "libint" $INCLUDE_PATHS'
add_include_from_paths LIBXC_CFLAGS "libint" $INCLUDE_PATHS
echo "LIBXC_CFLAGS = $LIBXC_CFLAGS"
[ "$LIBXC_CFLAGS" = "-I\"$LIBXC_INCLUDE\" -I\"$LIBINT_INCLUDE/libint\"" ] && echo $PASS || echo $FAIL
echo 'add_include_from_paths -p LIBXC_CFLAGS "libint" $INCLUDE_PATHS'
add_include_from_paths -p LIBXC_CFLAGS "libint" $INCLUDE_PATHS
echo "LIBXC_CFLAGS = $LIBXC_CFLAGS"
[ "$LIBXC_CFLAGS" = "-I\"$LIBXC_INCLUDE\" -I\"$LIBINT_INCLUDE/libint\" -I\"$LIBINT_INCLUDE\"" ] && echo $PASS || echo $FAIL
echo 'add_include_from_paths LIBXC_CFLAGS "test*" $INCLUDE_PATHS'
add_include_from_paths LIBXC_CFLAGS "test*" $INCLUDE_PATHS
echo "LIBXC_CFLAGS = $LIBXC_CFLAGS"
[ "$LIBXC_CFLAGS" = "-I\"$LIBXC_INCLUDE\" -I\"$LIBINT_INCLUDE/libint\" -I\"$LIBINT_INCLUDE\"" ] && echo $PASS || echo $FAIL

echo 'module unload lib/libint/1.1.4'
module unload lib/libint/1.1.4
unset LIBXC_LDFLAGS
echo 'add_lib_from_paths LIBXC_LDFLAGS "libxc.a" $LIB_PATHS'
add_lib_from_paths LIBXC_LDFLAGS "libxc.a" $LIB_PATHS
echo "LIBXC_LDFLAGS = $LIBXC_LDFLAGS"
[ "$LIBXC_LDFLAGS" = "-L\"$LIBXC_LIB\" -Wl,-rpath=\"$LIBXC_LIB\"" ] && echo $PASS || echo $FAIL
echo 'add_lib_from_paths LIBXC_LDFLAGS "lib*.a" $LIB_PATHS'
add_lib_from_paths LIBXC_LDFLAGS "lib*.a" $LIB_PATHS
echo "LIBXC_LDFLAGS = $LIBXC_LDFLAGS"
[ "$LIBXC_LDFLAGS" = "-L\"$LIBXC_LIB\" -Wl,-rpath=\"$LIBXC_LIB\"" ] && echo $PASS || echo $FAIL
echo 'add_lib_from_paths LIBXC_LDFLAGS "libint.a" $LIB_PATHS'
add_lib_from_paths LIBXC_LDFLAGS "libint.a" $LIB_PATHS
echo "LIBXC_LDFLAGS = $LIBXC_LDFLAGS"
[ "$LIBXC_LDFLAGS" = "-L\"$LIBXC_LIB\" -Wl,-rpath=\"$LIBXC_LIB\"" ] && echo $PASS || echo $FAIL
echo 'module load lib/libint/1.1.4'
module load lib/libint/1.1.4
echo 'add_lib_from_paths LIBXC_LDFLAGS "libint.a" $LIB_PATHS'
add_lib_from_paths LIBXC_LDFLAGS "libint.a" $LIB_PATHS
echo "LIBXC_LDFLAGS = $LIBXC_LDFLAGS"
[ "$LIBXC_LDFLAGS" = "-L\"$LIBXC_LIB\" -Wl,-rpath=\"$LIBXC_LIB\" -L\"$LIBINT_LIB\" -Wl,-rpath=\"$LIBINT_LIB\"" ] && echo $PASS || echo $FAIL
echo 'add_lib_from_paths -p LIBXC_LDFLAGS "libint.a" $LIB_PATHS'
add_lib_from_paths -p LIBXC_LDFLAGS "libint.a" $LIB_PATHS
echo "LIBXC_LDFLAGS = $LIBXC_LDFLAGS"
[ "$LIBXC_LDFLAGS" = "-L\"$LIBXC_LIB\" -Wl,-rpath=\"$LIBXC_LIB\" -L\"$LIBINT_LIB\" -Wl,-rpath=\"$LIBINT_LIB\"" ] && echo $PASS || echo $FAIL
echo 'add_lib_from_paths LIBXC_LDFLAGS "lib*" $LIB_PATHS'
add_lib_from_paths LIBXC_LDFLAGS "lib*" $LIB_PATHS
echo "LIBXC_LDFLAGS = $LIBXC_LDFLAGS"
[ "$LIBXC_LDFLAGS" = "-L\"$LIBXC_LIB\" -Wl,-rpath=\"$LIBXC_LIB\" -L\"$LIBINT_LIB\" -Wl,-rpath=\"$LIBINT_LIB\"" ] && echo $PASS || echo $FAIL

echo 'check_command gcc "GCC"'
check_command gcc "GCC" && echo $PASS || echo $FAIL
echo 'check_command ltong "FAKE"'
check_command ltong "FAKE" && echo $FAIL || echo $PASS
echo 'check_command ltong'
check_command ltong && echo $FAIL || echo $PASS

echo 'check_lib -lxc "libxc" && echo $PASS || echo $FAIL'
check_lib -lxc "libxc" && echo $PASS || echo $FAIL
echo 'check_lib -ltong "FAKE" && echo $FAIL || echo $PASS'
check_lib -ltong "FAKE" && echo $FAIL || echo $PASS
echo 'check_lib -ltong && echo $FAIL || echo $PASS'
check_lib -ltong && echo $FAIL || echo $PASS
test_path="::./test_dir/blah blah:"
LIB_PATHS="test_path $LIB_PATHS"
echo 'check_lib -ltong  && echo $PASS || echo $FAIL'
check_lib -ltong && echo $PASS || echo $FAIL

test_path=''
echo 'prepend_path test_path "dir1"'
prepend_path test_path "dir1"
echo "test_path = $test_path"
[ "$test_path" = "dir1" ] && echo $PASS || echo $FAIL
echo 'prepend_path test_path "dir2"'
prepend_path test_path "dir2"
echo "test_path = $test_path"
[ "$test_path" = "dir2:dir1" ] && echo $PASS || echo $FAIL
echo 'prepend_path test_path "dir1 dir2"'
prepend_path test_path "dir1 dir2"
echo "test_path = $test_path"
[ "$test_path" = "dir1 dir2:dir2:dir1" ] && echo $PASS || echo $FAIL
echo 'prepend_path test_path "dir1"'
prepend_path test_path "dir1"
echo "test_path = $test_path"
[ "$test_path" = "dir1 dir2:dir2:dir1" ] && echo $PASS || echo $FAIL

test_path=''
echo 'append_path test_path "dir1"'
append_path test_path "dir1"
echo "test_path = $test_path"
[ "$test_path" = "dir1" ] && echo $PASS || echo $FAIL
echo 'append_path test_path "dir2"'
append_path test_path "dir2"
echo "test_path = $test_path"
[ "$test_path" = "dir1:dir2" ] && echo $PASS || echo $FAIL
echo 'append_path test_path "dir1 dir2"'
append_path test_path "dir1 dir2"
echo "test_path = $test_path"
[ "$test_path" = "dir1:dir2:dir1 dir2" ] && echo $PASS || echo $FAIL
echo 'append_path test_path "dir1"'
append_path test_path "dir1"
echo "test_path = $test_path"
[ "$test_path" = "dir1:dir2:dir1 dir2" ] && echo $PASS || echo $FAIL

echo 'read_enable blah=yes'
read_enable blah=yes
[ "$(read_enable blah=yes)" = "__TRUE__" ] && echo $PASS || echo $FAIL
echo 'read_enable blah=no'
read_enable blah=no
[ "$(read_enable blah=no)" = "__FALSE__" ] && echo $PASS || echo $FAIL
echo 'read_enable blah=fdf'
read_enable blah=fdf
[ "$(read_enable blah=fdf)" = "__INVALID__" ] && echo $PASS || echo $FAIL
echo 'read_enable blah'
read_enable blah
[ "$(read_enable blah)" = "__TRUE__" ] && echo $PASS || echo $FAIL

echo 'read_with --with-blah=install'
read_with --with-blah=install
[ "$(read_with --with-blah=install)" = "__INSTALL__" ] && echo $PASS || echo $FAIL
echo 'read_with --with-blah=system'
read_with --with-blah=system
[ "$(read_with --with-blah=system)" = "__SYSTEM__" ] && echo $PASS || echo $FAIL
echo 'read_with --with-blah=no'
read_with --with-blah=no
[ "$(read_with --with-blah=no)" = "__DONTUSE__" ] && echo $PASS || echo $FAIL
echo 'read_with --with-blah=dir1'
read_with --with-blah=dir1
[ "$(read_with --with-blah=dir1)" = "dir1" ] && echo $PASS || echo $FAIL
echo 'read_with --with-blah=~/dir1'
read_with --with-blah=~/dir1
[ "$(read_with --with-blah=~/dir1)" = "$HOME/dir1" ] && echo $PASS || echo $FAIL
