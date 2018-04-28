#!/bin/sh
# runtests.sh - run CHICKEN testsuite
#
# - Note: this needs a proper shell, so it will not work with plain mingw
#   (just the compiler and the Windows shell, without MSYS)
#
# - should be called as runtests.sh SRCDIR BINDIR

set -e

SRC_DIR="$1"
BIN_DIR="$2"
PATH_SEP=':'

if test -z "${SRC_DIR}"; then
    SRC_DIR=`pwd`

    if test -z "$MSYSTEM"; then
        # Use Windows-native format with drive letters instead of awkward
        # MSYS /c/blabla "pseudo-paths" which break when used in syscalls.
        SRC_DIR=`pwd -W`
        PATH_SEP=';'
    fi
fi

TEST_DIR="${SRC_DIR}/tests"

DYLD_LIBRARY_PATH=${BIN_DIR}
LD_LIBRARY_PATH=${BIN_DIR}
LIBRARY_PATH=${BIN_DIR}:${LIBRARY_PATH}
# Cygwin uses LD_LIBRARY_PATH for dlopen(), but the dlls linked into
# the binary are read by the OS itself, which uses $PATH (mingw too)
PATH=${BIN_DIR}:${PATH}

export DYLD_LIBRARY_PATH LD_LIBRARY_PATH LIBRARY_PATH PATH

case `uname` in
	AIX)
		DIFF_OPTS=-b ;;
	*)
		DIFF_OPTS=-bu ;;
esac

CHICKEN=${BIN_DIR}/chicken
CHICKEN_PROFILE=${BIN_DIR}/chicken-profile
CHICKEN_INSTALL=${BIN_DIR}/chicken-install
CHICKEN_UNINSTALL=${BIN_DIR}/chicken-uninstall
CHICKEN_INSTALL_REPOSITORY=test-repository
CHICKEN_REPOSITORY_PATH="${BIN_DIR}${PATH_SEP}${CHICKEN_INSTALL_REPOSITORY}"

export CHICKEN_INSTALL_REPOSITORY CHICKEN_REPOSITORY_PATH

TYPESDB=${SRC_DIR}/types.db
COMPILE_OPTIONS="-v -compiler ${CHICKEN} -I${SRC_DIR} -L${BIN_DIR} -include-path ${SRC_DIR} -include-path ${TEST_DIR} -libdir ${BIN_DIR} -rpath ${BIN_DIR} -C -I${BIN_DIR} -C -I${SRC_DIR}"

compile="${BIN_DIR}/csc ${COMPILE_OPTIONS} -o a.out -types ${TYPESDB} -ignore-repository"
compile_r="${BIN_DIR}/csc ${COMPILE_OPTIONS} -o a.out"
compile_s="${BIN_DIR}/csc ${COMPILE_OPTIONS} -s -types ${TYPESDB} -ignore-repository"
interpret="${BIN_DIR}/csi -n -include-path ${SRC_DIR} -include-path ${TEST_DIR}"
time=time

# Check for a "time" command, since some systems don't ship with a
# time(1) or shell builtin and we also can't portably rely on `which',
# `command', etc. NOTE "time" must be called from a variable here.
set +e
$time true >/dev/null 2>/dev/null
test $? -eq 127 && time=
set -e

rm -fr *.exe *.so *.o *.import.* a.out foo.import.* test-repository
mkdir -p test-repository
cp $TYPESDB test-repository/types.db

echo "======================================== version tests ..."
$compile "${TEST_DIR}/version-tests.scm"
./a.out

echo "======================================== compiler tests ..."
$compile "${TEST_DIR}/compiler-tests.scm"
./a.out

echo "======================================== csc tests ..."
$interpret -s "${TEST_DIR}/csc-tests.scm" "${SRC_DIR}" "${BIN_DIR}" "${TEST_DIR}"

echo "======================================== compiler inlining tests  ..."
$compile "${TEST_DIR}/inlining-tests.scm" -optimize-level 3
./a.out

echo "======================================== optimizer tests  ..."
$compile "${TEST_DIR}/clustering-tests.scm" -clustering
./a.out

echo "======================================== profiler tests ..."
$compile "${TEST_DIR}/null.scm" -profile -profile-name TEST.profile
./a.out
$CHICKEN_PROFILE TEST.profile

echo "======================================== scrutiny tests ..."
$compile "${TEST_DIR}/scrutinizer-tests.scm" -analyze-only
$compile "${TEST_DIR}/typematch-tests.scm" -specialize -no-warnings
./a.out

$compile "${TEST_DIR}/scrutiny-tests-3.scm" -specialize -block
./a.out

$compile "${TEST_DIR}/scrutiny-tests-strict.scm" -strict-types -specialize
./a.out

echo "======================================== specialization tests ..."
rm -f foo.types foo.import.*
$compile "${TEST_DIR}/specialization-test-1.scm" -emit-type-file foo.types -specialize \
  -debug ox -emit-import-library foo
./a.out
$compile "${TEST_DIR}/specialization-test-2.scm" -types foo.types -types "${TEST_DIR}/specialization-test-2.types" -specialize -debug ox
./a.out
rm -f foo.types foo.import.*

echo "======================================== specialization benchmark ..."
$compile "${TEST_DIR}/fft.scm" -O2 -local -d0 -disable-interrupts -b -o fft1.out
$compile "${TEST_DIR}/fft.scm" -O2 -local -specialize -debug x -d0 -disable-interrupts -b -o fft2.out -specialize
echo "normal:"
$time ./fft1.out 1000 7
echo "specialized:"
$time ./fft2.out 1000 7

echo "======================================== callback tests ..."
$compile -extend "${TEST_DIR}/c-id-valid.scm" "${TEST_DIR}/callback-tests.scm"
./a.out

if ./a.out twice; then
    echo "double-return from callback didn't fail"
    exit 1
else
    echo "double-return from callback failed as it should."
fi

echo "======================================== runtime tests ..."
$interpret -s "${TEST_DIR}/apply-test.scm"
$compile "${TEST_DIR}/apply-test.scm"
./a.out
if ./a.out -:A10k; then
    echo "apply test with limited temp stack didn't fail"
    exit 1
else
    echo "apply test with limited temp stack failed as it should."
fi

$compile "${TEST_DIR}/test-gc-hooks.scm"
./a.out

echo "======================================== library tests ..."
$interpret -s "${TEST_DIR}/library-tests.scm"
$compile -specialize "${TEST_DIR}/library-tests.scm"
./a.out
$interpret -s "${TEST_DIR}/records-and-setters-test.scm"
$compile "${TEST_DIR}/records-and-setters-test.scm"
./a.out

echo "======================================== reader tests ..."
$interpret -s "${TEST_DIR}/reader-tests.scm"

echo "======================================== dynamic-wind tests ..."
$interpret -s "${TEST_DIR}/dwindtst.scm" >dwindtst.out
diff $DIFF_OPTS "${TEST_DIR}/dwindtst.expected" dwindtst.out
$compile "${TEST_DIR}/dwindtst.scm"
./a.out >dwindtst.out
diff $DIFF_OPTS "${TEST_DIR}/dwindtst.expected" dwindtst.out

echo "======================================== lolevel tests ..."
$interpret -s "${TEST_DIR}/lolevel-tests.scm"
$compile -specialize "${TEST_DIR}/lolevel-tests.scm"
./a.out

echo "======================================== arithmetic tests ..."
$interpret -D check -s "${TEST_DIR}/arithmetic-test.scm" "${TEST_DIR}"

echo "======================================== pretty-printer tests ..."
$interpret -s "${TEST_DIR}/pp-test.scm"

echo "======================================== evaluation environment tests ..."
$interpret -s "${TEST_DIR}/environment-tests.scm"

echo "======================================== syntax tests ..."
$interpret -s "${TEST_DIR}/syntax-tests.scm"

echo "======================================== syntax tests (compiled) ..."
$compile "${TEST_DIR}/syntax-tests.scm"
./a.out

echo "======================================== syntax tests (v2, compiled) ..."
$compile "${TEST_DIR}/syntax-tests-2.scm"
./a.out

echo "======================================== meta-syntax tests ..."
$interpret -bnq "${TEST_DIR}/meta-syntax-test.scm" -e '(import foo)' -e "(assert (equal? '((1)) (bar 1 2)))" -e "(assert (equal? '(list 1 2 3) (listify)))" -e "(import test-import-syntax-for-syntax)" -e "(assert (equal? '(1) (test)))" -e "(import test-begin-for-syntax)" -e "(assert (equal? '(1) (test)))"
$compile_s "${TEST_DIR}/meta-syntax-test.scm" -j foo
$compile_s foo.import.scm
$interpret -bnq "${TEST_DIR}/meta-syntax-test.scm" -e '(import foo)' -e "(assert (equal? '((1)) (bar 1 2)))" -e "(assert (equal? '(list 1 2 3) (listify)))" -e "(import test-import-syntax-for-syntax)" -e "(assert (equal? '(1) (test)))" -e "(import test-begin-for-syntax)" -e "(assert (equal? '(1) (test)))"

echo "======================================== reexport tests ..."
$interpret -bnq "${TEST_DIR}/reexport-tests.scm"
$compile "${TEST_DIR}/reexport-tests.scm"
./a.out
rm -f reexport-m*.import*
$compile_s "${TEST_DIR}/reexport-m1.scm" -J -o reexport-m1.so
$compile_s reexport-m1.import.scm
$interpret -s "${TEST_DIR}/reexport-m2.scm"
$compile "${TEST_DIR}/reexport-m2.scm"
./a.out
$compile_s "${TEST_DIR}/reexport-m3.scm" -J -o reexport-m3.so
$compile_s "${TEST_DIR}/reexport-m4.scm" -J -o reexport-m4.so
$compile_s "${TEST_DIR}/reexport-m5.scm" -J -o reexport-m5.so
$compile_s "${TEST_DIR}/reexport-m6.scm" -J -o reexport-m6.so
$compile "${TEST_DIR}/reexport-tests-2.scm"
./a.out

echo "======================================== functor tests ..."
$interpret -bnq "${TEST_DIR}/simple-functors-test.scm"
$compile "${TEST_DIR}/simple-functors-test.scm"
./a.out
$interpret -bnq "${TEST_DIR}/functor-tests.scm"
$compile "${TEST_DIR}/functor-tests.scm"
./a.out
$compile -s "${TEST_DIR}/square-functor.scm" -J -o square-functor.so
$compile -s square-functor.import.scm
$interpret -bnq "${TEST_DIR}/use-square-functor.scm"
$compile "${TEST_DIR}/use-square-functor.scm"
./a.out
$compile -s "${TEST_DIR}/use-square-functor.scm" -J -o use-square-functor.so
$interpret -nqe '(require-library use-square-functor)' -e '(import sf1)' -e '(import sf2)'
rm -f sf1.import.* sf2.import.* lst.import.* mod.import.*

echo "======================================== compiler syntax tests ..."
$compile "${TEST_DIR}/compiler-syntax-tests.scm"
./a.out

echo "======================================== import tests ..."
$interpret -bnq "${TEST_DIR}/import-tests.scm"

echo "======================================== import library tests ..."
rm -f foo.import.*
$compile_s "${TEST_DIR}/import-library-test1.scm" -emit-import-library foo -o import-library-test1.so
$interpret -s "${TEST_DIR}/import-library-test2.scm"
$compile_s foo.import.scm -o foo.import.so
$interpret -s "${TEST_DIR}/import-library-test2.scm"
$compile "${TEST_DIR}/import-library-test2.scm"
./a.out
rm -f foo.import.*

echo "======================================== optionals test ..."
$interpret -s "${TEST_DIR}/test-optional.scm"
$compile "${TEST_DIR}/test-optional.scm"
./a.out

echo "======================================== syntax tests (matchable) ..."
$interpret "${TEST_DIR}/matchable.scm" -s "${TEST_DIR}/match-test.scm"

echo "======================================== syntax tests (loopy-loop) ..."
$interpret -s "${TEST_DIR}/loopy-test.scm"

echo "======================================== r4rstest ..."
echo "(expect mult-float-print-test to fail)"
$interpret -e '(begin (set! ##sys#procedure->string (constantly "#<procedure>")) (set! r4rstest.scm "'${TEST_DIR}'/r4rstest.scm"))' \
  -i -s "${TEST_DIR}/r4rstest.scm" >r4rstest.out

diff $DIFF_OPTS "${TEST_DIR}/r4rstest.expected" r4rstest.out

echo "======================================== syntax tests (r5rs_pitfalls) ..."
echo "(expect two failures)"
$interpret -i -s "${TEST_DIR}/r5rs_pitfalls.scm"

echo "======================================== r7rs tests ..."
$interpret -i -s "${TEST_DIR}/r7rs-tests.scm"

echo "======================================== module tests ..."
$interpret -include-path "${SRC_DIR}" -s "${TEST_DIR}/module-tests.scm"
$interpret -include-path "${SRC_DIR}" -s "${TEST_DIR}/module-tests-2.scm"

echo "======================================== module tests (command line options) ..."
module="test-$(date +%s)"
$compile "${TEST_DIR}/test.scm" -A -w -j "$module" -module "$module"
$interpret -e "(import-syntax $module)"
rm -f "$module.import.scm"

echo "======================================== module tests (compiled) ..."
$compile "${TEST_DIR}/module-tests-compiled.scm"
./a.out
$compile "${TEST_DIR}/module-static-eval-compiled.scm"
./a.out
$compile -static "${TEST_DIR}/module-static-eval-compiled.scm"
./a.out

echo "======================================== module tests (chained) ..."
rm -f m*.import.* test-chained-modules.so
$interpret -bnq "${TEST_DIR}/test-chained-modules.scm"
$compile_s "${TEST_DIR}/test-chained-modules.scm" -j m3 -o test-chained-modules.so
$compile_s m3.import.scm
$interpret -bn test-chained-modules.so
$interpret -bn test-chained-modules.so -e '(import m3) (s3)'

echo "======================================== module tests (ec) ..."
rm -f ec.so ec.import.*
$interpret -bqn "${TEST_DIR}/ec.scm" "${TEST_DIR}/ec-tests.scm"
$compile_s "${TEST_DIR}/ec.scm" -emit-import-library ec -o ec.so
$compile_s ec.import.scm -o ec.import.so 
$interpret -bnq ec.so "${TEST_DIR}/ec-tests.scm"
# $compile "${TEST_DIR}/ec-tests.scm"
# ./a.out        # takes ages to compile

echo "======================================== port tests ..."
$interpret -e '(set! compiler.scm "'${TEST_DIR}'/compiler.scm")' -s "${TEST_DIR}/port-tests.scm"

echo "======================================== fixnum tests ..."
$compile "${TEST_DIR}/fixnum-tests.scm"
./a.out

echo "======================================== random number tests ..."
$interpret -s "${TEST_DIR}/random-tests.scm"

echo "======================================== string->number tests ..."
$interpret -s "${TEST_DIR}/numbers-string-conversion-tests.scm"
$compile -specialize "${TEST_DIR}/numbers-string-conversion-tests.scm"
./a.out

echo "======================================== basic numeric ops tests ..."
$interpret -s "${TEST_DIR}/numbers-test.scm"
$compile -specialize "${TEST_DIR}/numbers-test.scm"
./a.out

echo "======================================== Alex Shinn's numeric ops tests ..."
$interpret -s "${TEST_DIR}/numbers-test-ashinn.scm"
$compile -specialize "${TEST_DIR}/numbers-test-ashinn.scm"
./a.out

echo "======================================== Gauche's numeric ops tests ..."
$interpret -s "${TEST_DIR}/numbers-test-gauche.scm"
$compile -specialize "${TEST_DIR}/numbers-test-gauche.scm"
./a.out

echo "======================================== srfi-4 tests ..."
$interpret -s "${TEST_DIR}/srfi-4-tests.scm"

echo "======================================== condition tests ..."
$interpret -s "${TEST_DIR}/condition-tests.scm"

echo "======================================== data-structures tests ..."
$interpret -s "${TEST_DIR}/data-structures-tests.scm"

echo "======================================== path tests ..."
$interpret -bnq "${TEST_DIR}/path-tests.scm"

echo "======================================== srfi-45 tests ..."
$interpret -s "${TEST_DIR}/srfi-45-tests.scm"

echo "======================================== posix tests ..."
$compile "${TEST_DIR}/posix-tests.scm"
./a.out

echo "======================================== file access tests ..."
if test -n "$MSYSTEM"; then
  $interpret -s "${TEST_DIR}/file-access-tests.scm" //
  $interpret -s "${TEST_DIR}/file-access-tests.scm" \\
else
  $interpret -s "${TEST_DIR}/file-access-tests.scm" /
fi

echo "======================================== find-files tests ..."
$interpret -bnq "${TEST_DIR}/test-find-files.scm"

echo "======================================== record-renaming tests ..."
$interpret -bnq "${TEST_DIR}/record-rename-test.scm"

echo "======================================== regular expression tests ..."
$interpret -e '(set! re-tests.txt "'${TEST_DIR}'/re-tests.txt")' -bnq "${TEST_DIR}/test-irregex.scm"
$interpret -bnq "${TEST_DIR}/test-glob.scm"

echo "======================================== compiler/nursery stress test ..."
for s in 100000 120000 200000 250000 300000 350000 400000 450000 500000; do
    echo "  $s"
    "${BIN_DIR}/chicken" -ignore-repository "${SRC_DIR}/port.scm" -:s$s -output-file tmp.c -include-path "${SRC_DIR}"
done

echo "======================================== heap literal stress test ..."
$compile "${TEST_DIR}/heap-literal-stress-test.scm"
for s in 100000 120000 200000 250000 300000 350000 400000 450000 500000; do
  echo "  $s"
  ./a.out -:d -:g -:hi$s
done

echo "======================================== symbol-GC tests ..."
$compile "${TEST_DIR}/symbolgc-tests.scm"
./a.out

echo "======================================== finalizer tests ..."
$interpret -s "${TEST_DIR}/test-finalizers.scm"
$compile "${TEST_DIR}/test-finalizers.scm"
./a.out
$compile "${TEST_DIR}/finalizer-error-test.scm"
echo "expect an error message here:"
./a.out -:hg101
$compile "${TEST_DIR}/test-finalizers-2.scm"
./a.out

echo "======================================== locative stress test ..."
$compile "${TEST_DIR}/locative-stress-test.scm"
./a.out

echo "======================================== syntax-rules stress test ..."
$time $interpret -bnq "${TEST_DIR}/syntax-rule-stress-test.scm"

echo "======================================== include test ..."
mkdir -p a/b
echo > a/b/ok.scm
echo '(include "a/b/ok.scm")' > a/b/include.scm
$compile -analyze-only a/b/include.scm
echo '(include "b/ok.scm")' > a/b/include.scm
$compile -analyze-only a/b/include.scm -include-path a
echo '(include-relative "ok.scm")' > a/b/include.scm
$compile -analyze-only a/b/include.scm
echo '(include-relative "b/ok.scm")' > a/include.scm
$compile -analyze-only a/include.scm
echo '(include-relative "b/ok.scm")' > a/b/include.scm
$compile -analyze-only a/b/include.scm -include-path a
rm -r a

echo "======================================== executable tests ..."
$compile "${TEST_DIR}/executable-tests.scm"
./a.out `pwd`/a.out

echo "======================================== user pass tests ..."
$compile -extend "${TEST_DIR}/user-pass-tests.scm" "${TEST_DIR}/null.scm"

echo "======================================== embedding (1) ..."
$compile "${TEST_DIR}/embedded1.c"
./a.out

echo "======================================== embedding (2) ..."
$compile -e "${TEST_DIR}/embedded2.scm"
./a.out

echo "======================================== embedding (3) ..."
$compile -e "${TEST_DIR}/embedded3.c" "${TEST_DIR}/embedded4.scm"
./a.out

echo "======================================== linking tests ..."
$compile_r -unit reverser "${TEST_DIR}/reverser/tags/1.0/reverser.scm" -J -c -o reverser.o
$compile_r -link reverser "${TEST_DIR}/linking-tests.scm"
./a.out
$compile_r -link reverser "${TEST_DIR}/linking-tests.scm" -static
./a.out
mv reverser.o reverser.import.scm "$CHICKEN_INSTALL_REPOSITORY"
$compile_r -link reverser "${TEST_DIR}/linking-tests.scm"
./a.out
$compile_r -link reverser "${TEST_DIR}/linking-tests.scm" -static
./a.out

echo "======================================== private repository test ..."
mkdir -p tmp
$compile ${TEST_DIR}/private-repository-test.scm -private-repository -o tmp/xxx
tmp/xxx `pwd`/tmp
# This MUST be `pwd`: ${PWD} is not portable, and ${TEST_DIR} breaks mingw-msys
PATH=`pwd`/tmp:$PATH xxx `pwd`/tmp
# this may crash, if the PATH contains a non-matching libchicken.dll on Windows:
#PATH=$PATH:${TEST_DIR}/tmp xxx ${TEST_DIR}/tmp

echo "======================================== multiple return values tests ..."
$interpret -s "${TEST_DIR}/multiple-values.scm"
$compile "${TEST_DIR}/multiple-values.scm"
./a.out

echo "======================================== done."
