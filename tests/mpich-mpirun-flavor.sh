#!/bin/sh
exec mpirun --allow-run-as-root --oversubscribe "$@" -flavor=create
