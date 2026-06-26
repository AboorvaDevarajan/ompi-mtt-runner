#!/usr/bin/env bash
# common.sh — shared constants and runtime state

set -euo pipefail

readonly MTT_RUNNER_VERSION="1.0.0"

# Exit codes (CI-friendly)
readonly EXIT_PASS=0
readonly EXIT_BUILD_FAILED=1
readonly EXIT_TEST_FAILED=2
readonly EXIT_CONFIG_ERROR=3
readonly EXIT_DEPENDENCY_ERROR=4

# Directories
RUNNER_DIR="${RUNNER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly LIB_DIR="${RUNNER_DIR}/lib"
readonly CONFIGS_DIR="${RUNNER_DIR}/configs"
readonly TESTS_DIR="${RUNNER_DIR}/tests"
readonly RESULTS_DIR="${RUNNER_DIR}/results"
readonly LOGS_DIR="${RESULTS_DIR}/logs"
readonly WORK_DIR="${RUNNER_DIR}/work"
readonly SCRATCH_DIR="${WORK_DIR}/scratch"

# External paths
DEFAULT_MTT_HOME="${HOME}/src/mtt"
DEFAULT_OMPI_SRC="${HOME}/src/ompi"
DEFAULT_VENV_DIR="${RUNNER_DIR}/.venv"

# Defaults
DEFAULT_SUITE="smoke"
DEFAULT_BRANCH="v5.0.x"
DEFAULT_NP=2
DEFAULT_JOBS=$(nproc 2>/dev/null || echo 4)
DEFAULT_PREFIX="${HOME}/opt/ompi"

# Runtime state — populated by argument parsing
SUITE="${DEFAULT_SUITE}"
BRANCH="${DEFAULT_BRANCH}"
NP="${DEFAULT_NP}"
JOBS="${DEFAULT_JOBS}"
PREFIX="${DEFAULT_PREFIX}"
MTT_HOME="${DEFAULT_MTT_HOME}"
OMPI_SRC="${DEFAULT_OMPI_SRC}"
VENV_DIR="${DEFAULT_VENV_DIR}"
HOSTFILE=""
DO_REBUILD=false
DO_CLEAN=false
VERBOSE=false
DO_JUNIT=false
DO_SUBMIT=false
MTT_USER=""
MTT_PASS=""
PLATFORM="$(uname -m)"

ensure_dirs() {
    mkdir -p "${RESULTS_DIR}" "${LOGS_DIR}" "${WORK_DIR}" "${SCRATCH_DIR}"
}
