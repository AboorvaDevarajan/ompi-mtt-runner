#!/bin/sh
# Build MPICH test suite from the full MPICH repo checkout.
# MTT runs this from the TestGet directory; the clone is in mpich/.

JOBS="${1:-4}"

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
    export MPICH_CONFDB="$(cd ../../confdb && pwd)"
    sh autogen.sh || exit 1
fi

if [ ! -f Makefile ]; then
    ./configure CC=mpicc CXX=mpicxx F77=mpif77 FC=mpifort || exit 1
fi

# Open MPI 5.0.x is only partial MPI-4: mpi.h may declare MPI_Send_c /
# MPI_Buffer_iflush but libmpi does not export them. Drop those programs
# so make does not print link errors and then continue anyway.
mpi_has_sym() {
    fn="$1"
    tmpdir=$(mktemp -d) || return 1
    cat > "$tmpdir/t.c" <<EOF
#include <mpi.h>
int main(void) { return (void *)($fn) == 0; }
EOF
    mpicc "$tmpdir/t.c" -o "$tmpdir/t" >/dev/null 2>&1
    rc=$?
    rm -rf "$tmpdir"
    return "$rc"
}

omit_make_prog() {
    makefile="$1"
    prog="$2"
    [ -f "$makefile" ] || return 0
    sed -E -i "s/[[:space:]]+${prog}(\\$\\(EXEEXT\\))?//g" "$makefile"
}

omit_if_missing() {
    sym="$1"
    makefile="$2"
    prog="$3"
    if mpi_has_sym "$sym"; then
        return 0
    fi
    echo "Omitting ${prog}: this MPI has no ${sym}" >&2
    omit_make_prog "$makefile" "$prog"
}

omit_if_missing MPI_Send_c pt2pt/Makefile pt2pt_large
omit_if_missing MPI_Recv_c pt2pt/Makefile pt2pt_large
omit_if_missing MPI_Buffer_iflush pt2pt/Makefile bsend_iflush
omit_if_missing MPI_Send_c coll/Makefile coll_large
omit_if_missing MPI_Send_c coll/Makefile uoplong_large

# -k still builds later directories if something unexpected fails.
if ! make -k -j "$JOBS"; then
    echo "WARNING: some MPICH tests failed to build; running what linked" >&2
fi
