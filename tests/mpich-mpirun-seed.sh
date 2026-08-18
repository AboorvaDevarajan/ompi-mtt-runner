#!/bin/sh
# MPICH DTP pt2pt tests require -seed= -testsize= -type= -sendcnt= -recvcnt=.
exec mpirun --allow-run-as-root --oversubscribe "$@" \
    -seed=0 -testsize=5 -type=MPI_INT -sendcnt=64 -recvcnt=64
