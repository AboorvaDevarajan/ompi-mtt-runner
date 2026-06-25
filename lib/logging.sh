#!/usr/bin/env bash
# logging.sh — structured console output and log file management

_LOG_FILE=""
_BANNER_PRINTED=false

readonly COL_OK="\033[1;32m"
readonly COL_FAIL="\033[1;31m"
readonly COL_WARN="\033[1;33m"
readonly COL_SKIP="\033[1;36m"
readonly COL_BOLD="\033[1m"
readonly COL_RESET="\033[0m"

log_init() {
    _LOG_FILE="${LOGS_DIR}/mtt-runner-$(date +%Y%m%d-%H%M%S).log"
    mkdir -p "$(dirname "${_LOG_FILE}")"
    : > "${_LOG_FILE}"
    log_raw "MTT Runner ${MTT_RUNNER_VERSION} started at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    log_raw "Host: $(hostname) | Arch: $(uname -m) | Kernel: $(uname -r)"
    log_raw "MTT_HOME: ${MTT_HOME}"
    log_raw "---"
}

log_raw() {
    echo "$*" >> "${_LOG_FILE}" 2>/dev/null || true
}

log_verbose() {
    log_raw "$*"
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "$*"
    fi
}

banner_start() {
    if [[ "${_BANNER_PRINTED}" == "false" ]]; then
        printf "\n${COL_BOLD}=====================================================${COL_RESET}\n"
        _BANNER_PRINTED=true
    fi
}

banner_end() {
    local elapsed="$1"
    printf "  %-33s %s\n" "Elapsed" "${elapsed}"
    printf "${COL_BOLD}=====================================================${COL_RESET}\n\n"
}

step_start() {
    local label="$1"
    banner_start
    printf "  %-33s " "${label}"
    log_raw "[STEP] ${label}"
}

step_ok()   { local m="${1:-OK}";      printf "${COL_OK}%s${COL_RESET}\n" "${m}";   log_raw "[OK] ${m}"; }
step_fail() { local m="${1:-FAILED}";  printf "${COL_FAIL}%s${COL_RESET}\n" "${m}"; log_raw "[FAIL] ${m}"; }
step_skip() { local m="${1:-SKIPPED}"; printf "${COL_SKIP}%s${COL_RESET}\n" "${m}"; log_raw "[SKIP] ${m}"; }
step_warn() { local m="${1:-WARNING}"; printf "${COL_WARN}%s${COL_RESET}\n" "${m}"; log_raw "[WARN] ${m}"; }
step_pass() { local m="${1:-PASS}";    printf "${COL_OK}%s${COL_RESET}\n" "${m}";   log_raw "[PASS] ${m}"; }

format_elapsed() {
    local seconds="$1"
    printf "%02d:%02d:%02d" $((seconds/3600)) $(((seconds%3600)/60)) $((seconds%60))
}

die() {
    local code="$1"; shift
    printf "\n${COL_FAIL}FATAL: %s${COL_RESET}\n" "$*" >&2
    log_raw "[FATAL] $*"
    exit "${code}"
}
