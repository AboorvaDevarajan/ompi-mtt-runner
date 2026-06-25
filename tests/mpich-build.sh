#!/bin/sh
# Build MPICH test suite from the full MPICH repo checkout.
# Called by MTT Shell plugin from the MPICH repo root.

JOBS="${1:-4}"

cd test/mpi || exit 1

if [ ! -f configure ]; then
    sh autogen.sh || exit 1
fi

if [ ! -f Makefile ]; then
    ./configure CC=mpicc CXX=mpicxx F77=mpif77 FC=mpifort || exit 1
fi

make -j "$JOBS" || exit 1
