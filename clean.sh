#!/bin/sh
#
# Copyright (c) 2017, The CHICKEN Team
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following
# conditions are met:
#
#   Redistributions of source code must retain the above copyright notice, this list of conditions and the following
#     disclaimer. 
#   Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
#     disclaimer in the documentation and/or other materials provided with the distribution. 
#   Neither the name of the author nor the names of its contributors may be used to endorse or promote
#     products derived from this software without specific prior written permission. 
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.


set -e

. config.sh

usage () {
    echo "clean.sh [-help] [-distclean] [-spotless] [-testclean]" >&2
    exit $1
}

confclean=
testclean=
clean=1

case "$1" in
    --?help|--?h)
        usage 0;;
    -distclean)
        confclean=1;;
    -testclean)
        clean=
        testclean=1;;
    -spotless)
        confclean=1
        testclean=1;;
    *)
        usage 1;;
esac

if test -n "${clean}"; then
    rm -f ${PROGRAM_PREFIX}chicken${PROGRAM_SUFFIX}${EXE}
    rm -f ${PROGRAM_PREFIX}csc${PROGRAM_SUFFIX}${EXE}
    rm -f ${PROGRAM_PREFIX}csi${PROGRAM_SUFFIX}${EXE}
    rm -f ${PROGRAM_PREFIX}chicken-install${PROGRAM_SUFFIX}${EXE}
    rm -f ${PROGRAM_PREFIX}chicken-uninstall${PROGRAM_SUFFIX}${EXE}
    rm -f ${PROGRAM_PREFIX}chicken-status${PROGRAM_SUFFIX}${EXE}
    rm -f ${PROGRAM_PREFIX}chicken-propile${PROGRAM_SUFFIX}${EXE}
    rm -f ${PROGRAM_PREFIX}feathers${PROGRAM_SUFFIX}${EXE}
    rm -f lib${PROGRAM_PREFIX}chicken${PROGRAM_SUFFIX}${DYLIB}*
    rm -fr *.import.so
    rm -f srfi-4.import.scm
    for x in bitwise blob errno file.posix fixnum flonum format gc io keyword load locative memory	memory.representation platform plist posix pretty-print process process.signal process-context random syntax	sort string time time.posix continuation data-structures eval file internal irregex pathname port read-syntax repl tcp; do
        rm -f chicken.${x}.import.scm
    done
    rm -f chicken.compiler.user-pass.import.scm
fi

if test -n "${confclean}"; then
    rm -f chicken-config.h chicken-install.rc chicken-uninstall.rc
fi

if test -n "${testclean}"; then
    rm -f ${SRCDIR}/tests/*.dll
    rm -f ${SRCDIR}/tests/*.import.scm
    rm -f ${SRCDIR}/tests/*.link
    rm -f ${SRCDIR}/tests/*.out
    rm -f ${SRCDIR}/tests/*.profile
    rm -f ${SRCDIR}/tests/*.so
    rm -f ${SRCDIR}/tests/tmp*
    rm -f ${SRCDIR}/tests/empty-file
    rm -f ${SRCDIR}/tests/null
    rm -f ${SRCDIR}/tests/null.c
    rm -f ${SRCDIR}/tests/null.o
    rm -f ${SRCDIR}/tests/null.exe
    rm -fr ${SRCDIR}/tests/test-repository
fi
