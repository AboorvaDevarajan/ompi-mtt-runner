#!/usr/bin/env bash
# run-mtt.sh — thin wrapper around the MTT Python client
#
# Usage:
#   ./run-mtt.sh [OPTIONS]
#
# Options:
#   --suite SUITE      Test suite: smoke, ompi, mpich, intel, all (default: smoke)
#   --branch BRANCH    Open MPI branch to test (default: v5.0.x)
#   --np N             Number of MPI processes (default: 2)
#   --jobs N           Parallel make jobs (default: nproc)
#   --hostfile FILE    MPI hostfile for multi-node runs
#   --mtt-home DIR     Path to MTT clone (default: ~/src/mtt)
#   --clean            Wipe MTT scratch and rebuild everything
#   --verbose          Show MTT output on console
#   --submit           Submit results to mtt.open-mpi.org (IUDatabase)
#   --mtt-user USER    MTT database username (or $MTT_USER)
#   --mtt-pass PASS    MTT database password (or $MTT_PASS)
#   --platform NAME    Platform name in the DB (default: uname -m)
#   --hostname NAME    Hostname sent to the DB (default: hostname)
#   --help             Show this help message
#
# Exit codes:
#   0  All tests passed
#   1  Build failed
#   2  Test failed
#   3  Configuration error
#   4  Missing dependency
#
# Reports stay local in results/summary.txt unless --submit is used.

set -euo pipefail

RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RUNNER_DIR

source "${RUNNER_DIR}/lib/common.sh"
source "${RUNNER_DIR}/lib/logging.sh"
source "${RUNNER_DIR}/lib/deps.sh"
source "${RUNNER_DIR}/lib/mtt.sh"

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
            --clean)     DO_CLEAN=true; shift ;;
            --verbose)   VERBOSE=true; shift ;;
            --submit)    DO_SUBMIT=true; shift ;;
            --mtt-user)  MTT_USER="${2:?--mtt-user requires a value}"; shift 2 ;;
            --mtt-pass)  MTT_PASS="${2:?--mtt-pass requires a value}"; shift 2 ;;
            --platform)  PLATFORM="${2:?--platform requires a value}"; shift 2 ;;
            --hostname)  SUBMIT_HOSTNAME="${2:?--hostname requires a value}"; shift 2 ;;
            --help|-h)   usage ;;
            *)           die ${EXIT_CONFIG_ERROR} "Unknown option: $1" ;;
        esac
    done
}

main() {
    local run_start
    run_start=$(date +%s)

    parse_args "$@"

    if [[ "${DO_SUBMIT}" == "true" ]]; then
        if [[ -z "${MTT_USER}" || -z "${MTT_PASS}" ]]; then
            echo "ERROR: --submit requires --mtt-user and --mtt-pass (or MTT_USER / MTT_PASS)" >&2
            exit ${EXIT_CONFIG_ERROR}
        fi
    fi

    ensure_dirs
    log_init

    log_raw "Suite=${SUITE} Branch=${BRANCH} NP=${NP} Jobs=${JOBS}"
    log_raw "MTT_HOME=${MTT_HOME}"

    step_start "Checking system dependencies"
    if check_system_deps; then
        step_ok
    else
        step_fail
        die ${EXIT_DEPENDENCY_ERROR} "Missing system dependencies. See log: ${_LOG_FILE}"
    fi

    step_start "Checking Python environment"
    if check_python_deps; then
        step_ok
    else
        step_fail
        die ${EXIT_DEPENDENCY_ERROR} "Python dependency failure. See log: ${_LOG_FILE}"
    fi

    step_start "Checking MTT client"
    if ensure_mtt; then
        step_ok
    else
        step_fail
        die ${EXIT_DEPENDENCY_ERROR} "Failed to obtain MTT. See log: ${_LOG_FILE}"
    fi

    step_start "Generating MTT config"
    generate_mtt_ini
    step_ok "${SUITE}.ini"

    step_start "Running MTT (${SUITE})"
    local mtt_rc=0
    run_mtt || mtt_rc=$?

    if [[ ${mtt_rc} -eq 0 ]]; then
        step_pass
    else
        step_fail "FAIL (rc=${mtt_rc})"
    fi

    local run_end elapsed
    run_end=$(date +%s)
    elapsed=$(format_elapsed $((run_end - run_start)))
    banner_end "${elapsed}"

    if [[ -f "${RESULTS_DIR}/summary.txt" ]]; then
        echo "Report: ${RESULTS_DIR}/summary.txt"
    fi
    echo "MTT log: ${LOGS_DIR}/mtt.log"

    if [[ ${mtt_rc} -ne 0 ]]; then
        exit ${EXIT_TEST_FAILED}
    fi
    exit ${EXIT_PASS}
}

main "$@"
