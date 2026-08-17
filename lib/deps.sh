#!/usr/bin/env bash
# System deps, MTT clone, Python venv.

readonly MTT_GIT_URL="https://github.com/open-mpi/mtt.git"

readonly REQUIRED_SYSTEM_CMDS=(
    git gcc g++ gfortran python3
    autoconf automake libtool perl make
)

readonly REQUIRED_PYTHON_PKGS=(
    requests
    yapsy
    hostlist
    junit_xml
)

declare -A PIP_NAMES=(
    [requests]="requests"
    [yapsy]="Yapsy"
    [hostlist]="python-hostlist"
    [junit_xml]="junit-xml"
)

check_system_deps() {
    local missing=()
    for cmd in "${REQUIRED_SYSTEM_CMDS[@]}"; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing+=("${cmd}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_raw "Missing system commands: ${missing[*]}"
        return 1
    fi

    log_raw "System dependencies: all present"
    return 0
}

ensure_mtt() {
    if [[ -d "${MTT_HOME}" && -f "${MTT_HOME}/pyclient/pymtt.py" ]]; then
        log_raw "MTT found at ${MTT_HOME}"
    else
        log_verbose "Cloning MTT into ${MTT_HOME}..."
        local clone_log="${LOGS_DIR}/mtt-clone.log"
        mkdir -p "$(dirname "${MTT_HOME}")"
        if ! git clone "${MTT_GIT_URL}" "${MTT_HOME}" >> "${clone_log}" 2>&1; then
            log_raw "MTT clone failed. See ${clone_log}"
            return 1
        fi
        log_raw "MTT cloned to ${MTT_HOME}"
    fi

    local patcher="${RUNNER_DIR}/scripts/patch-mtt.py"
    if [[ -f "${patcher}" ]]; then
        if ! python3 "${patcher}" "${MTT_HOME}" >> "${LOGS_DIR}/mtt-patch.log" 2>&1; then
            log_raw "MTT patch failed. See ${LOGS_DIR}/mtt-patch.log"
            return 1
        fi
        log_raw "MTT MPIVersion patches applied"
    fi
    return 0
}

# Yapsy 1.12 (what pip installs) still imports the removed `imp`
# module, so MTT needs Python < 3.12.
select_python() {
    local candidate
    for candidate in python3.11 python3.10 python3; do
        if command -v "${candidate}" &>/dev/null; then
            if "${candidate}" -c 'import sys; raise SystemExit(0 if sys.version_info < (3, 12) else 1)' 2>/dev/null; then
                echo "${candidate}"
                return 0
            fi
        fi
    done
    return 1
}

ensure_venv() {
    local py
    py=$(select_python) || {
        log_raw "MTT requires Python 3.10 or 3.11 (Yapsy is broken on 3.12+)"
        log_raw "Ubuntu 24.04: sudo add-apt-repository ppa:deadsnakes/ppa && sudo apt install python3.11 python3.11-venv python3.11-dev"
        return 1
    }

    if [[ -x "${VENV_DIR}/bin/python" ]]; then
        if ! "${VENV_DIR}/bin/python" -c 'import sys; raise SystemExit(0 if sys.version_info < (3, 12) else 1)' 2>/dev/null; then
            log_verbose "Recreating venv with ${py} (existing venv is Python 3.12+)"
            rm -rf "${VENV_DIR}"
        fi
    fi

    if [[ ! -d "${VENV_DIR}" ]]; then
        log_verbose "Creating Python virtual environment with ${py} at ${VENV_DIR}"
        "${py}" -m venv "${VENV_DIR}"
    fi
    # shellcheck disable=SC1091
    source "${VENV_DIR}/bin/activate"
    log_raw "Activated venv: ${VENV_DIR} ($("${VENV_DIR}/bin/python" --version))"
}

check_python_deps() {
    if ! ensure_venv; then
        return 1
    fi

    local missing=()
    for pkg in "${REQUIRED_PYTHON_PKGS[@]}"; do
        if ! python3 -c "import ${pkg}" &>/dev/null; then
            missing+=("${pkg}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_verbose "Installing missing Python packages..."
        local pip_pkgs=()
        for m in "${missing[@]}"; do
            pip_pkgs+=("${PIP_NAMES[$m]}")
        done
        local pip_log="${LOGS_DIR}/pip-install.log"
        if ! pip install --quiet "${pip_pkgs[@]}" >> "${pip_log}" 2>&1; then
            log_raw "pip install failed. See ${pip_log}"
            return 1
        fi
        log_raw "Installed Python packages: ${pip_pkgs[*]}"
    fi

    log_raw "Python dependencies: all present"
    return 0
}
