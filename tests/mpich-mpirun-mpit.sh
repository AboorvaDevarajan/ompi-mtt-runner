#!/bin/sh
exec mpirun --allow-run-as-root --oversubscribe "$@" 0 0
