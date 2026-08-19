#!/usr/bin/env bash
# Shared constants and runtime state.

set -euo pipefail

readonly MTT_RUNNER_VERSION="2.0.0"

readonly EXIT_PASS=0
readonly EXIT_BUILD_FAILED=1
readonly EXIT_TEST_FAILED=2
readonly EXIT_CONFIG_ERROR=3
readonly EXIT_DEPENDENCY_ERROR=4

RUNNER_DIR="${RUNNER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly LIB_DIR="${RUNNER_DIR}/lib"
readonly CONFIGS_DIR="${RUNNER_DIR}/configs"
readonly TESTS_DIR="${RUNNER_DIR}/tests"
readonly RESULTS_DIR="${RUNNER_DIR}/results"
readonly LOGS_DIR="${RESULTS_DIR}/logs"
readonly WORK_DIR="${RUNNER_DIR}/work"
readonly SCRATCH_DIR="${WORK_DIR}/scratch"

DEFAULT_MTT_HOME="${HOME}/src/mtt"
DEFAULT_VENV_DIR="${RUNNER_DIR}/.venv"
DEFAULT_SUITE="smoke"
DEFAULT_BRANCH="v5.0.x"
DEFAULT_NP=2
DEFAULT_JOBS=$(nproc 2>/dev/null || echo 4)

SUITE="${DEFAULT_SUITE}"
BRANCH="${DEFAULT_BRANCH}"
NP="${DEFAULT_NP}"
JOBS="${DEFAULT_JOBS}"
MTT_HOME="${DEFAULT_MTT_HOME}"
VENV_DIR="${DEFAULT_VENV_DIR}"
HOSTFILE=""
DO_CLEAN=false
VERBOSE=false
DO_SUBMIT=false
NP_EXPLICIT=false
MTT_USER="${MTT_USER:-}"
MTT_PASS="${MTT_PASS:-}"
PLATFORM="$(uname -m)"
SUBMIT_HOSTNAME="$(hostname)"
# Local IBM test tree. Perl MTT used getenv("ibm_test_src").
IBM_TEST_SRC="${IBM_TEST_SRC:-${ibm_test_src:-}}"

ensure_dirs() {
    mkdir -p "${RESULTS_DIR}" "${LOGS_DIR}" "${WORK_DIR}" "${SCRATCH_DIR}"
}
