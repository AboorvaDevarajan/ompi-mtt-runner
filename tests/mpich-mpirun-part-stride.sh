#!/bin/sh
exec mpirun --allow-run-as-root --oversubscribe "$@" \
    -spart=8 -rpart=8 -tot_count=64 -range=2 -iteration=5 -stride=2
