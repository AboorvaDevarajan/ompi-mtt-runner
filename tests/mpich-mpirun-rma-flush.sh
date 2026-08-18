#!/bin/sh
exec mpirun --allow-run-as-root --oversubscribe "$@" -count=4096 -op=put
