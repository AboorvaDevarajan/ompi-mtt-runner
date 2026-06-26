# ompi-mtt-runner

Developer/CI test harness for Open MPI, powered by the
[MTT Python client](https://github.com/open-mpi/mtt).

Updates Open MPI source, builds it, runs test suites through MTT's
6-phase pipeline, and produces structured reports — all with clean
console output and CI-friendly exit codes.

## Quick start

```bash
# First run — clones MTT, clones OMPI, builds everything (~15 min)
./run-mtt.sh --suite smoke --verbose

# Subsequent runs — OMPI build is cached via ASIS (~3 sec)
./run-mtt.sh --suite smoke
```

## Running tests

```bash
# Smoke tests — 5 basic MPI programs (fastest)
./run-mtt.sh --suite smoke

# MPICH conformance suite — pt2pt, collective, comm, datatype, init
./run-mtt.sh --suite mpich --verbose

# OSU Micro-Benchmarks — latency, bandwidth, allreduce, barrier
./run-mtt.sh --suite osu --verbose

# Intel MPI Benchmarks — IMB-MPI1
./run-mtt.sh --suite imb --verbose

# Open MPI's own make check
./run-mtt.sh --suite ompi --verbose

# Run everything
./run-mtt.sh --suite all --verbose
```

### Controlling execution

```bash
# More MPI processes
./run-mtt.sh --suite smoke --np 8

# Different Open MPI branch
./run-mtt.sh --suite smoke --branch main

# Multi-node with a hostfile
./run-mtt.sh --suite smoke --np 32 --hostfile /path/to/hosts

# Control parallel make jobs
./run-mtt.sh --suite mpich --jobs 64

# Force full rebuild (wipes MTT scratch)
./run-mtt.sh --suite smoke --clean

# Show full MTT output on console
./run-mtt.sh --suite smoke --verbose

# Submit results to mtt.open-mpi.org
./run-mtt.sh --suite smoke --submit --mtt-user YOUR_USER --mtt-pass YOUR_PASS

# Custom platform identifier (default: uname -m)
./run-mtt.sh --suite smoke --submit --mtt-user YOU --mtt-pass PASS --platform power9
```

### Hostfile format

Standard Open MPI format, one host per line:

```
node1 slots=16
node2 slots=16
```

When no `--hostfile` is given, all processes run locally (single machine).

### First run vs subsequent runs

| Phase | First run | Subsequent runs |
|-------|-----------|-----------------|
| Clone OMPI | ~1 min | Skipped (ASIS) |
| Build OMPI | ~10 min | Skipped (ASIS) |
| Clone test suite | ~10 sec | Skipped (ASIS) |
| Build tests | ~1 min | Rebuilt each run |
| Run tests | varies | runs every time |

The `ASIS` prefix on MTT sections means "skip if already done." Use
`--clean` to force everything from scratch (e.g., after changing
`--branch`).

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
    │                             Reporter        (TextFile + JUnit XML [+ IUDatabase])
    └── 6. Present clean summary + return exit code
```

## Command line options

| Flag | Description | Default |
|------|-------------|---------|
| `--suite SUITE` | `smoke`, `mpich`, `osu`, `imb`, `ompi`, `all` | `smoke` |
| `--branch BRANCH` | Open MPI branch or tag | `v5.0.x` |
| `--np N` | MPI process count | `2` |
| `--jobs N` | Parallel make jobs | `nproc` |
| `--hostfile FILE` | MPI hostfile for multi-node runs | (local) |
| `--mtt-home DIR` | Path to MTT clone | `~/src/mtt` |
| `--clean` | Wipe MTT scratch, rebuild everything | |
| `--verbose` | Show full MTT output on console | |
| `--junit` | Produce JUnit XML in `results/` | |
| `--submit` | Submit results to [mtt.open-mpi.org](https://mtt.open-mpi.org/) | |
| `--mtt-user USER` | MTT database username (required with `--submit`) | |
| `--mtt-pass PASS` | MTT database password (required with `--submit`) | |
| `--platform NAME` | Platform identifier for upstream reports | `uname -m` |

## Test suites

| Suite | Tests | Timeout | Description |
|-------|-------|---------|-------------|
| `smoke` | 5 | 30s each | hello_world, get_version, init_finalize, comm_info, bcast |
| `mpich` | 200+ | 600s each | MPICH conformance: pt2pt, collective, comm, datatype, init |
| `osu` | 4 | 120s each | OSU Micro-Benchmarks: latency, bw, allreduce, barrier |
| `imb` | 1 | 120s | Intel MPI Benchmarks: IMB-MPI1 |
| `ompi` | many | 1800s | Open MPI `make check` |
| `all` | all | varies | Every suite above |

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
  Elapsed                          00:00:03
=====================================================
```

Full MTT output goes to `results/logs/mtt.log`.

## Results

After each run, results are written to `results/`:

| File | Content |
|------|---------|
| `results/summary.txt` | Human-readable test summary |
| `results/junit.xml` | JUnit XML for CI integration |
| `results/logs/mtt.log` | Full MTT verbose output |
| `results/logs/mtt-runner-*.log` | Runner orchestration log |

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
│   ├── smoke/              # Smoke test C sources + Makefile
│   └── mpich-build.sh      # MPICH test suite build helper
├── results/                # (gitignored) MTT output, logs, reports
└── work/                   # (gitignored) MTT scratch directory
```

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

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Missing dependency` | Install system packages listed above |
| `pymtt.py not found` | Check `--mtt-home` path; delete and re-clone |
| Build fails after branch change | Use `--clean` to force rebuild |
| ASIS uses stale cache | Delete specific `work/scratch/TestGet_*` dir |
| Test needs more ranks | Increase `--np` (e.g., `--np 4`) |
| Test hangs | Per-test timeout in INI handles this automatically |

## Upstream reporting

Results can be submitted to the [Open MPI Test Reporter](https://mtt.open-mpi.org/)
database using the `--submit` flag. This uses MTT's `IUDatabase` reporter plugin.

```bash
./run-mtt.sh --suite smoke --submit --mtt-user YOUR_USER --mtt-pass YOUR_PASS
```

To get credentials, subscribe to the
[MTT developer mailing list](https://lists.open-mpi.org/mailman/listinfo/mtt-devel)
(mtt-devel@open-mpi.org) and request access. See the
[MTT community page](https://open-mpi.github.io/mtt/pages/community.html) for details.

Without `--submit`, all reports stay local (`results/summary.txt`, `results/junit.xml`).
No data is sent anywhere by default.

## Future extensions

- PRRTE launcher integration
- UCX / libfabric-enabled builds
- Compiler matrices (GCC, Clang, IBM XL)
- Configure profiles (debug, optimized, shared, static)
- Multi-node execution with hostfiles
- Scheduler integration (SLURM, PBS) via MTT launcher plugins
- Nightly test mode with retained history
