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
set -x

mkdir -p "${DESTDIR}${LIBDIR}"
mkdir -p "${DESTDIR}${BINDIR}"
mkdir -p "${DESTDIR}${CHICKENINCDIR}"
mkdir -p "${DESTDIR}${DOCDIR}"
mkdir -p "${DESTDIR}${SHAREDIR}"
mkdir -p "${DESTDIR}${CHICKENLIBDIR}/${BINARYVERSION}"
mkdir -p "${DESTDIR}${MAN1DIR}"

if test -n "${LIBCHICKEN_IMPORT_LIB}"; then
    ${INSTALL_PROGRAM} -m 644 ${LIBCHICKEN_IMPORT_LIB} "${DESTDIR}${LIBDIR}"
fi

if test -n "${NEEDS_RELINKING}"; then
    rm -f "${PROGRAM_PREFIX}chicken${PROGRAM_SUFFIX}${EXE}"
    rm -f "${PROGRAM_PREFIX}csc${PROGRAM_SUFFIX}${EXE}"
    rm -f "${PROGRAM_PREFIX}csi${PROGRAM_SUFFIX}${EXE}"
    rm -f "${PROGRAM_PREFIX}chicken-install${PROGRAM_SUFFIX}${EXE}"
    rm -f "${PROGRAM_PREFIX}chicken-uninstall${PROGRAM_SUFFIX}${EXE}"
    rm -f "${PROGRAM_PREFIX}chicken-status${PROGRAM_SUFFIX}${EXE}"
    rm -f "${PROGRAM_PREFIX}chicken-profile${PROGRAM_SUFFIX}${EXE}"
    rm -f *.import.so
    rm -f ${LIBCHICKEN}
    RUNTIME_LINKER_PATH="${LIBDIR}" sh ${SRCDIR}/build.sh
    LIBCHICKEN=lib${PROGRAM_PREFIX}chicken${PROGRAM_SUFFIX}${DYLIB}.${BINARYVERSION}
fi

if test -z "${STATICBUILD}"; then
    libdest="${LIBDIR}"

    if test -n "${DLLSINPATH}"; then
        libdest="${BINDIR}"
    fi

    ${INSTALL_PROGRAM} -m 755 "${LIBCHICKEN}" "${DESTDIR}${libdest}"

    if test "${USES_SONAME}" = 1; then
        oldpwd=${PWD}
        cd "${DESTDIR}${libdest}" && ln -sf "${LIBCHICKEN}" "lib${PROGRAM_PREFIX}chicken${PROGRAM_SUFFIX}${DYLIB}"
        cd ${oldpwd}
    fi
fi

${INSTALL_PROGRAM} -m 644 lib${PROGRAM_PREFIX}chicken${PROGRAM_SUFFIX}${A} "${DESTDIR}${LIBDIR}"
test -n "${NEEDS_RANLIB}" && ranlib "${DESTDIR}${LIBDIR}/lib${PROGRAM_PREFIX}chicken${PROGRAM_SUFFIX}${A}"

${INSTALL_PROGRAM} -m 644 "${SRCDIR}/chicken.h" chicken-config.h "${DESTDIR}${CHICKENINCDIR}"

${INSTALL_PROGRAM} -m 644 "${SRCDIR}/types.db" "${DESTDIR}${EGGDIR}"

${INSTALL_PROGRAM} -m 755 "${PROGRAM_PREFIX}chicken${PROGRAM_SUFFIX}${EXE}" "${DESTDIR}${BINDIR}"
${INSTALL_PROGRAM} -m 755 "${PROGRAM_PREFIX}csc${PROGRAM_SUFFIX}${EXE}" "${DESTDIR}${BINDIR}"
${INSTALL_PROGRAM} -m 755 "${PROGRAM_PREFIX}csi${PROGRAM_SUFFIX}${EXE}" "${DESTDIR}${BINDIR}"
${INSTALL_PROGRAM} -m 755 "${PROGRAM_PREFIX}chicken-status${PROGRAM_SUFFIX}${EXE}" "${DESTDIR}${BINDIR}"
${INSTALL_PROGRAM} -m 755 "${PROGRAM_PREFIX}chicken-install${PROGRAM_SUFFIX}${EXE}" "${DESTDIR}${BINDIR}"
${INSTALL_PROGRAM} -m 755 "${PROGRAM_PREFIX}chicken-uninstall${PROGRAM_SUFFIX}${EXE}" "${DESTDIR}${BINDIR}"
${INSTALL_PROGRAM} -m 755 "${PROGRAM_PREFIX}chicken-profile${PROGRAM_SUFFIX}${EXE}" "${DESTDIR}${BINDIR}"
${INSTALL_PROGRAM} -m 755 chicken-do${EXE} "${DESTDIR}${BINDIR}/${PROGRAM_PREFIX}chicken-do${PROGRAM_SUFFIX}${EXE}"
${INSTALL_PROGRAM} -m 755 "${PROGRAM_PREFIX}feathers${PROGRAM_SUFFIX}${EXE}" "${DESTDIR}${BINDIR}"

if test -z "${STATICBUILD}"; then
    for x in `ls *.import.so`; do
        ${INSTALL_PROGRAM} -m 755 ${x} "${DESTDIR}${EGGDIR}"
        test -n "${NEEDS_INSTALL_NAME}" && install_name_tool -change ${LIBCHICKEN} "${LIBDIR}/${LIBCHICKEN}" "${DESTDIR}${EGGDIR}/$x"
    done
else
    for x in `ls *.import.scm`; do
        ${INSTALL_PROGRAM} -m 644 ${x} "${DESTDIR}${EGGDIR}"
    done
fi

if test -n "${NEEDS_INSTALL_NAME}"; then
    install_name_tool -change ${LIBCHICKEN} "${LIBDIR}/${LIBCHICKEN}" ${PROGRAM_PREFIX}chicken${PROGRAM_SUFFIX}${EXE}
    install_name_tool -change ${LIBCHICKEN} "${LIBDIR}/${LIBCHICKEN}" ${PROGRAM_PREFIX}csc${PROGRAM_SUFFIX}${EXE}
    install_name_tool -change ${LIBCHICKEN} "${LIBDIR}/${LIBCHICKEN}" ${PROGRAM_PREFIX}csi${PROGRAM_SUFFIX}${EXE}
    install_name_tool -change ${LIBCHICKEN} "${LIBDIR}/${LIBCHICKEN}" ${PROGRAM_PREFIX}chicken-status${PROGRAM_SUFFIX}${EXE}
    install_name_tool -change ${LIBCHICKEN} "${LIBDIR}/${LIBCHICKEN}" ${PROGRAM_PREFIX}chicken-${INSTALL_PROGRAM}${PROGRAM_SUFFIX}${EXE}
    install_name_tool -change ${LIBCHICKEN} "${LIBDIR}/${LIBCHICKEN}" ${PROGRAM_PREFIX}chicken-un${INSTALL_PROGRAM}${PROGRAM_SUFFIX}${EXE}
    install_name_tool -change ${LIBCHICKEN} "${LIBDIR}/${LIBCHICKEN}" ${PROGRAM_PREFIX}chicken-profile${PROGRAM_SUFFIX}${EXE}
fi

${INSTALL_PROGRAM} -m 644 ${SRCDIR}/setup.defaults ${DESTDIR}${DATADIR}

test "${CROSS_CHICKEN}${DESTDIR}" = 0 && "${BINDIR}/${PROGRAM_PREFIX}chicken-${INSTALL_PROGRAM}${PROGRAM_SUFFIX}" -update-db

${INSTALL_PROGRAM} -m 644 "${SRCDIR}/chicken.mdoc" "${DESTDIR}${MAN1DIR}/${PROGRAM_PREFIX}chicken${PROGRAM_SUFFIX}.1"
${INSTALL_PROGRAM} -m 644 "${SRCDIR}/csc.mdoc" "${DESTDIR}${MAN1DIR}/${PROGRAM_PREFIX}csc${PROGRAM_SUFFIX}.1"
${INSTALL_PROGRAM} -m 644 "${SRCDIR}/csi.mdoc" "${DESTDIR}${MAN1DIR}/${PROGRAM_PREFIX}csi${PROGRAM_SUFFIX}.1"
${INSTALL_PROGRAM} -m 644 "${SRCDIR}/chicken-${INSTALL_PROGRAM}.mdoc" "${DESTDIR}${MAN1DIR}/${PROGRAM_PREFIX}chicken-${INSTALL_PROGRAM}${PROGRAM_SUFFIX}.1"
${INSTALL_PROGRAM} -m 644 "${SRCDIR}/chicken-un${INSTALL_PROGRAM}.mdoc" "${DESTDIR}${MAN1DIR}/${PROGRAM_PREFIX}chicken-un${INSTALL_PROGRAM}${PROGRAM_SUFFIX}.1"
${INSTALL_PROGRAM} -m 644 "${SRCDIR}/chicken-status.mdoc" "${DESTDIR}${MAN1DIR}/${PROGRAM_PREFIX}chicken-status${PROGRAM_SUFFIX}.1"
${INSTALL_PROGRAM} -m 644 "${SRCDIR}/chicken-profile.mdoc" "${DESTDIR}${MAN1DIR}/${PROGRAM_PREFIX}chicken-profile${PROGRAM_SUFFIX}.1"
${INSTALL_PROGRAM} -m 644 "${SRCDIR}/chicken-do.mdoc" "${DESTDIR}${MAN1DIR}/${PROGRAM_PREFIX}chicken-do${PROGRAM_SUFFIX}.1"
${INSTALL_PROGRAM} -m 644 "${SRCDIR}/feathers.mdoc" "${DESTDIR}${MAN1DIR}/${PROGRAM_PREFIX}feathers${PROGRAM_SUFFIX}.1"

mkdir -p "${DESTDIR}${DOCDIR}/manual"
${INSTALL_PROGRAM} -m 644 ${SRCDIR}/manual-html/* "${DESTDIR}${DOCDIR}/manual" || true
${INSTALL_PROGRAM} -m 644 ${SRCDIR}/README "${DESTDIR}${DOCDIR}"
${INSTALL_PROGRAM} -m 644 ${SRCDIR}/LICENSE "${DESTDIR}${DOCDIR}"

${INSTALL_PROGRAM} -m 644 ${SRCDIR}/feathers.tcl "${DESTDIR}${DATADIR}"
