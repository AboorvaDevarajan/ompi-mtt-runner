#!/usr/bin/env bash
# run-mtt.sh — Open MPI test runner powered by the MTT Python client
#
# Usage:
#   ./run-mtt.sh [OPTIONS]
#
# Options:
#   --suite SUITE      Test suite: smoke, mpich, osu, imb, ompi, all (default: smoke)
#   --branch BRANCH    Open MPI branch to test (default: v5.0.x)
#   --np N             Number of MPI processes (default: 2)
#   --jobs N           Parallel make jobs (default: nproc)
#   --hostfile FILE    MPI hostfile for multi-node runs
#   --mtt-home DIR     Path to MTT clone (default: ~/src/mtt)
#   --rebuild          Force MTT to redo all ASIS phases
#   --clean            Clean MTT scratch directory before run
#   --verbose          Show MTT output on console
#   --junit            Produce JUnit XML in results/
#   --submit           Submit results to mtt.open-mpi.org
#   --mtt-user USER    MTT database username (required with --submit)
#   --mtt-pass PASS    MTT database password (required with --submit)
#   --platform NAME    Platform identifier (default: uname -m, e.g. ppc64le)
#   --help             Show this help message
#
# Exit codes:
#   0  All tests passed
#   1  Build failed
#   2  Test failed
#   3  Configuration error
#   4  Missing dependency

set -euo pipefail

RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RUNNER_DIR

# --- Load libraries ---
source "${RUNNER_DIR}/lib/common.sh"
source "${RUNNER_DIR}/lib/logging.sh"
source "${RUNNER_DIR}/lib/dependencies.sh"
source "${RUNNER_DIR}/lib/mtt.sh"

# --- Argument parsing ---
usage() {
    sed -n '3,/^$/s/^# \?//p' "${BASH_SOURCE[0]}"
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --suite)     SUITE="${2:?--suite requires a value}"; shift 2 ;;
            --branch)    BRANCH="${2:?--branch requires a value}"; shift 2 ;;
            --np)        NP="${2:?--np requires a value}"; shift 2 ;;
            --jobs)      JOBS="${2:?--jobs requires a value}"; shift 2 ;;
            --hostfile)  HOSTFILE="${2:?--hostfile requires a value}"; shift 2 ;;
            --mtt-home)  MTT_HOME="${2:?--mtt-home requires a value}"; shift 2 ;;
            --rebuild)   DO_REBUILD=true; shift ;;
            --clean)     DO_CLEAN=true; shift ;;
            --verbose)   VERBOSE=true; shift ;;
            --junit)     DO_JUNIT=true; shift ;;
            --submit)    DO_SUBMIT=true; shift ;;
            --mtt-user)  MTT_USER="${2:?--mtt-user requires a value}"; shift 2 ;;
            --mtt-pass)  MTT_PASS="${2:?--mtt-pass requires a value}"; shift 2 ;;
            --platform)  PLATFORM="${2:?--platform requires a value}"; shift 2 ;;
            --help|-h)   usage ;;
            *)           die ${EXIT_CONFIG_ERROR} "Unknown option: $1" ;;
        esac
    done
}

# --- Main ---
main() {
    local run_start
    run_start=$(date +%s)

    parse_args "$@"

    if [[ "${DO_SUBMIT}" == "true" ]]; then
        if [[ -z "${MTT_USER}" || -z "${MTT_PASS}" ]]; then
            echo "ERROR: --submit requires --mtt-user and --mtt-pass" >&2
            exit ${EXIT_CONFIG_ERROR}
        fi
    fi

    ensure_dirs
    log_init

    log_raw "Suite=${SUITE} Branch=${BRANCH} NP=${NP} Jobs=${JOBS}"
    log_raw "MTT_HOME=${MTT_HOME}"

    # 1. System dependencies
    step_start "Checking system dependencies"
    if check_system_deps; then
        step_ok
    else
        step_fail
        die ${EXIT_DEPENDENCY_ERROR} "Missing system dependencies. See log: ${_LOG_FILE}"
    fi

    # 2. Python venv + packages
    step_start "Checking Python environment"
    if check_python_deps; then
        step_ok
    else
        step_fail
        die ${EXIT_DEPENDENCY_ERROR} "Python dependency failure. See log: ${_LOG_FILE}"
    fi

    # 3. Ensure MTT is available
    step_start "Checking MTT client"
    if ensure_mtt; then
        step_ok
    else
        step_fail
        die ${EXIT_DEPENDENCY_ERROR} "Failed to obtain MTT. See log: ${_LOG_FILE}"
    fi

    # 4. Generate MTT INI config
    step_start "Generating MTT config"
    generate_mtt_ini
    step_ok "$(basename "${SUITE}").ini"

    # 5. Run MTT
    step_start "Running MTT (${SUITE})"
    local mtt_rc=0
    run_mtt || mtt_rc=$?

    if [[ ${mtt_rc} -eq 0 ]]; then
        step_pass
    else
        step_fail "FAIL (rc=${mtt_rc})"
    fi

    # 6. Summary
    local run_end elapsed
    run_end=$(date +%s)
    elapsed=$(format_elapsed $((run_end - run_start)))
    banner_end "${elapsed}"

    log_raw "Results in ${RESULTS_DIR}/"
    log_raw "Full MTT log: ${LOGS_DIR}/mtt.log"

    if [[ ${mtt_rc} -ne 0 ]]; then
        exit ${EXIT_TEST_FAILED}
    fi
    exit ${EXIT_PASS}
}

main "$@"
