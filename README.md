# ompi-mtt-runner

Developer/CI test harness for Open MPI, powered by the
[MTT Python client](https://github.com/open-mpi/mtt).

Updates Open MPI source, builds it, runs test suites through MTT's
6-phase pipeline, and produces structured reports — all with clean
console output and CI-friendly exit codes.

## Quick start

```bash
./run-mtt.sh                          # smoke tests with defaults
./run-mtt.sh --suite mpich --np 4     # MPICH test suite, 4 ranks
./run-mtt.sh --suite all --verbose    # everything, full output
```

## How it works

```
run-mtt.sh
    │
    ├── 1. Check system dependencies (gcc, autoconf, make, ...)
    ├── 2. Bootstrap Python venv + install MTT dependencies
    ├── 3. Clone/update open-mpi/mtt if needed
    ├── 4. Generate MTT INI config from templates
    ├── 5. Invoke pymtt.py  ──►  MTT handles the full lifecycle:
    │                             MiddlewareGet   (clone OMPI)
    │                             MiddlewareBuild (autogen + configure + make)
    │                             TestGet         (clone/copy test sources)
    │                             TestBuild       (compile against OMPI)
    │                             TestRun         (mpirun tests)
    │                             Reporter        (TextFile + JUnit XML)
    └── 6. Present clean summary + return exit code
```

## Command line options

| Flag | Description | Default |
|------|-------------|---------|
| `--suite SUITE` | `smoke`, `mpich`, `osu`, `imb`, `ompi`, `all` | `smoke` |
| `--branch BRANCH` | Open MPI branch or tag | `v5.0.x` |
| `--np N` | MPI process count | `2` |
| `--jobs N` | Parallel make jobs | `nproc` |
| `--mtt-home DIR` | Path to MTT clone | `~/src/mtt` |
| `--rebuild` | Force MTT to redo cached phases | |
| `--clean` | Clean MTT scratch before run | |
| `--verbose` | Show full MTT output on console | |
| `--junit` | Produce JUnit XML in `results/` | |

## Test suites

| Suite | What MTT runs |
|-------|---------------|
| `smoke` | hello_world, get_version, init_finalize, comm_info, bcast |
| `mpich` | MPICH test suite (pt2pt, collective, comm, datatype, init) |
| `osu` | OSU Micro-Benchmarks (latency, bandwidth, allreduce, barrier) |
| `imb` | Intel MPI Benchmarks (IMB-MPI1) |
| `ompi` | Open MPI `make check` |
| `all` | All of the above |

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | All tests passed |
| `1` | Build failed |
| `2` | Test(s) failed |
| `3` | Configuration error |
| `4` | Missing dependency |

## Console output

```
=====================================================
  Checking system dependencies     OK
  Checking Python environment      OK
  Checking MTT client              OK
  Generating MTT config            smoke.ini
  Running MTT (smoke)              PASS
  Elapsed                          00:03:42
=====================================================
```

Full MTT output goes to `results/logs/mtt.log`.

## Project layout

```
mtt-runner/
├── run-mtt.sh              # Entry point — orchestration + console output
├── lib/
│   ├── common.sh           # Constants, exit codes, defaults
│   ├── logging.sh          # Structured console output
│   ├── dependencies.sh     # System deps + MTT clone + Python venv
│   └── mtt.sh              # INI template expansion + pymtt.py invocation
├── configs/
│   ├── common.ini          # MTTDefaults + MiddlewareGet/Build + Reporter
│   ├── smoke.ini           # Smoke test TestGet/Build/Run
│   ├── mpich.ini           # MPICH test suite
│   ├── osu.ini             # OSU benchmarks
│   ├── imb.ini             # Intel MPI Benchmarks
│   └── ompi.ini            # OMPI make check
├── tests/
│   └── smoke/              # Smoke test C sources (copied by MTT Copytree)
├── results/                # (gitignored) MTT output, logs, reports
└── work/                   # (gitignored) MTT scratch directory
```

## MTT INI architecture

The INI configs use proper MTT section names and plugins:

- **`[MiddlewareGet:OMPI]`** — `Git` plugin, clones Open MPI
- **`[MiddlewareBuild:OMPI]`** — `Autotools` plugin, runs autogen/configure/make
- **`[TestGet:*]`** — `Copytree`, `Git`, or `Shell` plugins to obtain tests
- **`[TestBuild:*]`** — compiles tests against the OMPI install
- **`[TestRun:*]`** — `OpenMPI` plugin, launches via `mpirun`
- **`[Reporter:*]`** — `TextFile` and `JunitXML` output

Sections prefixed with `ASIS` are cached — MTT skips them on subsequent
runs if already completed. This provides intelligent rebuild behavior
without custom caching logic.

## Dependencies

### System packages

`git`, `gcc`, `g++`, `gfortran`, `python3`, `autoconf`, `automake`,
`libtool`, `perl`, `make`

### Python packages (auto-installed into .venv)

`requests`, `Yapsy`, `python-hostlist`, `junit-xml`

### MTT (auto-cloned)

The runner clones [open-mpi/mtt](https://github.com/open-mpi/mtt) into
`~/src/mtt` (or the path given by `--mtt-home`) on first run.

## CI integration

```yaml
- name: Run MPI smoke tests
  run: ./run-mtt.sh --suite smoke
- name: Publish test results
  uses: dorny/test-reporter@v1
  if: always()
  with:
    name: MPI Tests
    path: results/junit.xml
    reporter: java-junit
```

## Future extensions

- PRRTE launcher integration
- UCX / libfabric-enabled builds
- Compiler matrices (GCC, Clang, IBM XL)
- Configure profiles (debug, optimized, shared, static)
- Multi-node execution with hostfiles
- Scheduler integration (SLURM, PBS) via MTT launcher plugins
- Nightly test mode with retained history
