#!/bin/sh
exec mpirun --allow-run-as-root --oversubscribe "$@" \
    -seed=0 -testsize=5 -type=MPI_INT -count=64
