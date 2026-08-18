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

# Drop programs that need APIs Open MPI 5.0.x does not provide, so make
# does not print compile/link errors and then continue anyway.
mpi_compiles() {
    body="$1"
    tmpdir=$(mktemp -d) || return 1
    printf '%s\n' "#include <mpi.h>" "int main(void) { ${body} return 0; }" > "$tmpdir/t.c"
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
    why="$1"
    makefile="$2"
    prog="$3"
    snippet="$4"
    if mpi_compiles "$snippet"; then
        return 0
    fi
    echo "Omitting ${prog}: this MPI has no ${why}" >&2
    omit_make_prog "$makefile" "$prog"
}

omit_if_missing MPI_Send_c pt2pt/Makefile pt2pt_large 'return (void *)MPI_Send_c == 0;'
omit_if_missing MPI_Recv_c pt2pt/Makefile pt2pt_large 'return (void *)MPI_Recv_c == 0;'
omit_if_missing MPI_Buffer_iflush pt2pt/Makefile bsend_iflush 'return (void *)MPI_Buffer_iflush == 0;'
omit_if_missing MPI_Send_c coll/Makefile coll_large 'return (void *)MPI_Send_c == 0;'
omit_if_missing MPI_Send_c coll/Makefile uoplong_large 'return (void *)MPI_Send_c == 0;'
omit_if_missing QMPI_Context mpi_t/Makefile qmpi_test 'QMPI_Context c; (void)c;'
omit_if_missing MPI_T_BIND_MPI_SESSION mpi_t/Makefile mpit_vars 'int x = MPI_T_BIND_MPI_SESSION; return x == 0;'
omit_if_missing MPI_T_BIND_MPI_SESSION threads/mpi_t/Makefile mpit_threading 'int x = MPI_T_BIND_MPI_SESSION; return x == 0;'

# -k still builds later directories if something unexpected fails.
if ! make -k -j "$JOBS"; then
    echo "WARNING: some MPICH tests failed to build; running what linked" >&2
fi
