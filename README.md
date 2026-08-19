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
| `mpich` | MPICH C tests: pt2pt, coll, comm, datatype, init, attr, group, info, errhan, topo, rma, session, mpi_t, part |
| `intel` | Intel MPI tests from private `open-mpi/ompi-tests` |
| `ibm` | IBM MPI tests from a local tree (`--ibm-src` / `$IBM_TEST_SRC`) |
| `all` | smoke, ompi, mpich, intel (not `ibm`; that needs a local path) |

```bash
./run-mtt.sh --suite smoke
./run-mtt.sh --suite ompi --verbose
./run-mtt.sh --suite mpich --jobs 64
./run-mtt.sh --suite smoke --np 8 --hostfile /path/to/hosts
./run-mtt.sh --suite smoke --branch main --clean
./run-mtt.sh --suite ibm --ibm-src /path/to/ibm --verbose
```

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--suite SUITE` | `smoke`, `ompi`, `mpich`, `intel`, `ibm`, `all` | `smoke` |
| `--branch BRANCH` | Open MPI branch or tag | `v5.0.x` |
| `--np N` | MPI process count | `2` (`nproc` for `ibm`) |
| `--jobs N` | Parallel make jobs | `nproc` |
| `--hostfile FILE` | MPI hostfile | local only |
| `--ibm-src DIR` | Local IBM test tree (or `$IBM_TEST_SRC` / `$ibm_test_src`) | |
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

## IBM suite (single node)

Same layout as the old Perl MTT `Copytree` + `Simple` IBM sections. Tests
come from a local directory, not GitHub.

```bash
export IBM_TEST_SRC=/path/to/ibm   # Perl used ibm_test_src
./run-mtt.sh --suite ibm --verbose --platform ppc64le --hostname ltc-wspoon16
# or
./run-mtt.sh --suite ibm --ibm-src /path/to/ibm --np 16
```

No hostfile. `mpirun` already uses `--allow-run-as-root --oversubscribe`.
If you omit `--np`, this suite uses `nproc` (Perl `&env_max_procs()`).

| Perl group | Python MTT section | Timeout |
|---|---|---|
| `simple_first` | `TestRun:IBM` | 50s |
| `simple_medium` (`ssend`, `sendrecv_big`) | `TestRun:IBM-medium` | 200s |
| `simple_slow` (`comm_split_f`) | `TestRun:IBM-slow` | 600s |
| `simple_very_slow` | `TestRun:IBM-very-slow` | 600s |
| `simple_too_slow` (`mt_1sided`) | `TestRun:IBM-too-slow` | 3000s |
| `simple_fail` (`abort`, `final`) | `TestRun:IBM-fail` | 200s, expected non-zero |
| `simple_skip` (`int_overflow`) | `skip_tests` | not run (LIBCOLL hang) |

Build is `./autogen.sh && ./configure --enable-static --disable-shared && make`.
`--clean` recopies the local tree; without it, MTT `ASIS` reuses the last copy.

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
