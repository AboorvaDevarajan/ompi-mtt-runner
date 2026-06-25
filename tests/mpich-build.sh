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
    # Point autogen.sh at the repo-level confdb so it skips the
    # "Missing confdb!" gate and handles all copies internally
    export MPICH_CONFDB="$(cd ../../confdb && pwd)"

    sh autogen.sh || exit 1
fi

if [ ! -f Makefile ]; then
    ./configure CC=mpicc CXX=mpicxx F77=mpif77 FC=mpifort || exit 1
fi

# -k: keep going past individual compile failures (e.g. MPI 4.0
# large-count tests that OMPI v5.0.x doesn't fully support)
make -k -j "$JOBS" || true
