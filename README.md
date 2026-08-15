# ompi-mtt-runner

Thin wrapper around the [MTT Python client](https://github.com/open-mpi/mtt)
for running Open MPI tests.

The runner clones MTT if needed, generates an INI, invokes `pymtt.py`, and
writes a local text report. Nothing is submitted to
[mtt.open-mpi.org](https://mtt.open-mpi.org/).

## Quick start

```bash
./run-mtt.sh --suite smoke --verbose
```

First run clones MTT and Open MPI, then builds OMPI (~15 min). Later runs
reuse the cached build via MTT's `ASIS` sections.

## Suites

| Suite | What it runs |
|-------|----------------|
| `smoke` | Five small MPI programs (hello, version, init, comm, bcast) |
| `ompi` | Open MPI `make check` |
| `mpich` | MPICH conformance tests against this OMPI build |
| `all` | All of the above |

```bash
./run-mtt.sh --suite smoke
./run-mtt.sh --suite ompi --verbose
./run-mtt.sh --suite mpich --jobs 64
./run-mtt.sh --suite smoke --np 8 --hostfile /path/to/hosts
./run-mtt.sh --suite smoke --branch main --clean
```

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--suite SUITE` | `smoke`, `ompi`, `mpich`, `all` | `smoke` |
| `--branch BRANCH` | Open MPI branch or tag | `v5.0.x` |
| `--np N` | MPI process count | `2` |
| `--jobs N` | Parallel make jobs | `nproc` |
| `--hostfile FILE` | MPI hostfile | local only |
| `--mtt-home DIR` | Path to MTT clone | `~/src/mtt` |
| `--clean` | Wipe scratch and rebuild | |
| `--verbose` | Show full MTT output | |

## Reports

All output stays on disk:

| File | Content |
|------|---------|
| `results/summary.txt` | Human-readable MTT TextFile report |
| `results/logs/mtt.log` | Full `pymtt.py` output |
| `results/logs/mtt-runner-*.log` | Wrapper log |

There is no IUDatabase reporter and no `--submit` flag.

## How it works

```
run-mtt.sh
    ├── check system + Python deps
    ├── clone open-mpi/mtt if missing
    ├── expand configs/*.ini
    └── pymtt.py
          MiddlewareGet    clone Open MPI
          MiddlewareBuild  autogen + configure + make
          TestGet          copy or clone test sources
          TestBuild        compile against OMPI
          TestRun          mpirun
          Reporter         results/summary.txt
```

## Dependencies

System: `git`, `gcc`, `g++`, `gfortran`, `python3`, `autoconf`, `automake`,
`libtool`, `perl`, `make`.

Python (installed into `.venv`): `requests`, `Yapsy`, `python-hostlist`,
`junit-xml`.

MTT is cloned from [open-mpi/mtt](https://github.com/open-mpi/mtt) on first
run.
