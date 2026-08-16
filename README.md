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
| `intel` | Intel MPI tests from private `open-mpi/ompi-tests` |
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
| `--suite SUITE` | `smoke`, `ompi`, `mpich`, `intel`, `all` | `smoke` |
| `--branch BRANCH` | Open MPI branch or tag | `v5.0.x` |
| `--np N` | MPI process count | `2` |
| `--jobs N` | Parallel make jobs | `nproc` |
| `--hostfile FILE` | MPI hostfile | local only |
| `--mtt-home DIR` | Path to MTT clone | `~/src/mtt` |
| `--clean` | Wipe scratch and rebuild | |
| `--verbose` | Show full MTT output | |
| `--submit` | Submit to [mtt.open-mpi.org](https://mtt.open-mpi.org/) | off |
| `--mtt-user USER` | MTT DB username (or `$MTT_USER`) | |
| `--mtt-pass PASS` | MTT DB password (or `$MTT_PASS`) | |
| `--platform NAME` | Platform name in the DB | `uname -m` |
| `--hostname NAME` | Hostname sent to the DB | `hostname` |

## Reports

Every run writes a local text report. Upstream submit is opt-in.

| File | Content |
|------|---------|
| `results/summary.txt` | Human-readable MTT TextFile report |
| `results/logs/mtt.log` | Full `pymtt.py` output |
| `results/logs/mtt-runner-*.log` | Wrapper log |

```bash
# Local only (default)
./run-mtt.sh --suite smoke

# Also submit to the MTT database
export MTT_USER=ibm
export MTT_PASS=...
./run-mtt.sh --suite smoke --submit --platform ppc64le --hostname ltczz10
```

`--submit` adds MTT's `IUDatabase` reporter (same shape as
[mtt#956](https://github.com/open-mpi/mtt/issues/956)) and sets `trial = false`
so results are not hidden as trial runs. `hostname` is sent as a plain string.

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
