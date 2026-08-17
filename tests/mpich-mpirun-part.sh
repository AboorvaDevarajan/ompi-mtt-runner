#!/bin/sh
# MPICH partitioned-comm tests require -spart/-rpart/-tot_count.
# MTT appends the test path last; pass a host-memory default through.
exec mpirun --allow-run-as-root --oversubscribe "$@" \
    -spart=8 -rpart=8 -tot_count=64 -range=2 -iteration=5
