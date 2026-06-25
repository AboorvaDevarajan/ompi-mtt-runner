#!/bin/sh
# Build MPICH test suite from the full MPICH repo checkout.
# MTT runs this from the TestGet directory; the clone is in mpich/.

JOBS="${1:-4}"

# Find the mpich source tree
if [ -d mpich/test/mpi ]; then
    cd mpich/test/mpi
elif [ -d test/mpi ]; then
    cd test/mpi
else
    echo "Cannot find MPICH test/mpi directory" >&2
    echo "PWD=$(pwd)" >&2
    ls -la >&2
    exit 1
fi

if [ ! -f configure ]; then
    # autogen.sh requires confdb in CWD before it will proceed;
    # symlink to the repo-level confdb so autoreconf can find macros
    [ -d confdb ] || ln -sf ../../confdb confdb
    [ -d dtpools/confdb ] || ln -sf ../../confdb dtpools/confdb 2>/dev/null
    [ -f version.m4 ] || ln -sf ../../maint/version.m4 version.m4 2>/dev/null

    sh autogen.sh || exit 1
fi

if [ ! -f Makefile ]; then
    ./configure CC=mpicc CXX=mpicxx F77=mpif77 FC=mpifort || exit 1
fi

make -j "$JOBS" || exit 1
