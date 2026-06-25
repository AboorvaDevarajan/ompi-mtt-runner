#!/usr/bin/env bash
# dependencies.sh — system deps, MTT clone, Python venv bootstrap

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
    log_raw "  gcc=$(gcc --version | head -1)"
    log_raw "  python3=$(python3 --version 2>&1)"
    return 0
}

ensure_mtt() {
    if [[ -d "${MTT_HOME}" && -f "${MTT_HOME}/pyclient/pymtt.py" ]]; then
        log_raw "MTT found at ${MTT_HOME}"
        # Pull latest
        pushd "${MTT_HOME}" > /dev/null
        git pull --ff-only >> "${LOGS_DIR}/mtt-update.log" 2>&1 || true
        popd > /dev/null
        return 0
    fi

    log_verbose "Cloning MTT into ${MTT_HOME}..."
    local clone_log="${LOGS_DIR}/mtt-clone.log"
    if ! git clone "${MTT_GIT_URL}" "${MTT_HOME}" >> "${clone_log}" 2>&1; then
        log_raw "MTT clone failed. See ${clone_log}"
        return 1
    fi
    log_raw "MTT cloned to ${MTT_HOME}"
    return 0
}

ensure_venv() {
    if [[ ! -d "${VENV_DIR}" ]]; then
        log_verbose "Creating Python virtual environment at ${VENV_DIR}"
        python3 -m venv "${VENV_DIR}"
    fi
    # shellcheck disable=SC1091
    source "${VENV_DIR}/bin/activate"
    log_raw "Activated venv: ${VENV_DIR}"
}

check_python_deps() {
    ensure_venv

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
