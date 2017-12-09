#!/bin/sh
#
# CHICKEN Build script - partially generated, do not edit.

if test -z "${CC}"; then
    CC=gcc
fi

if test -z "${CHICKEN}"; then
    CHICKEN=chicken
fi

if test -z "${SRCDIR}"; then
    SRCDIR=.
fi

if test -z "${ARCH}"; then
    ARCH=`sh ${SRCDIR}/config-arch.sh`
fi

if test ! -a chicken-do; then
    ${CC} ${SRCDIR}/chicken-do.c -o chicken-do -I.
fi
