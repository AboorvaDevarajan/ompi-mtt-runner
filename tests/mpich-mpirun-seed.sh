#!/bin/sh
# MPICH mtest binaries (pingping, sendrecv1, sendself) require -seed=.
# MTT appends the test path as the last argument; pass -seed=0 through.
exec mpirun --allow-run-as-root --oversubscribe "$@" -seed=0
