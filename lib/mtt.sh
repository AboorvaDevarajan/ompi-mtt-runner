#!/usr/bin/env bash
# Expand INI templates and invoke pymtt.py.

generate_mtt_ini() {
    local output="${WORK_DIR}/current.ini"
    : > "${output}"

    expand_template "${CONFIGS_DIR}/common.ini" >> "${output}"

    case "${SUITE}" in
        smoke) append_suite smoke "${output}" ;;
        ompi)  append_suite ompi  "${output}" ;;
        mpich) append_suite mpich "${output}" ;;
        all)
            for s in smoke ompi mpich; do
                append_suite "${s}" "${output}"
            done
            ;;
        *)
            die ${EXIT_CONFIG_ERROR} "Unknown suite: ${SUITE}"
            ;;
    esac

    log_raw "Generated MTT config: ${output}"
    log_raw "--- begin INI ---"
    cat "${output}" >> "${_LOG_FILE}" 2>/dev/null || true
    log_raw "--- end INI ---"
}

expand_template() {
    local template="$1"
    sed \
        -e "s|@SCRATCH@|${SCRATCH_DIR}|g" \
        -e "s|@NP@|${NP}|g" \
        -e "s|@JOBS@|${JOBS}|g" \
        -e "s|@BRANCH@|${BRANCH}|g" \
        -e "s|@HOSTNAME@|$(hostname)|g" \
        -e "s|@RESULTS_DIR@|${RESULTS_DIR}|g" \
        -e "s|@TESTS_DIR@|${TESTS_DIR}|g" \
        -e "s|@HOSTFILE@|${HOSTFILE}|g" \
        "${template}" \
    | if [[ -z "${HOSTFILE}" ]]; then
        grep -v '^hostfile[[:space:]]*=[[:space:]]*$'
      else
        cat
      fi
}

append_suite() {
    local suite="$1" output="$2"
    local ini="${CONFIGS_DIR}/${suite}.ini"
    if [[ -f "${ini}" ]]; then
        echo "" >> "${output}"
        expand_template "${ini}" >> "${output}"
    else
        die ${EXIT_CONFIG_ERROR} "Suite config not found: ${ini}"
    fi
}

run_mtt() {
    local ini="${WORK_DIR}/current.ini"
    local mtt_log="${LOGS_DIR}/mtt.log"
    local pymtt="${MTT_HOME}/pyclient/pymtt.py"

    if [[ ! -f "${pymtt}" ]]; then
        die ${EXIT_CONFIG_ERROR} "pymtt.py not found at ${pymtt}"
    fi

    export MTT_HOME

    local mtt_args=(
        "${pymtt}"
        "--scratch-dir" "${SCRATCH_DIR}"
        "--verbose"
    )

    if [[ "${DO_CLEAN}" == "true" ]]; then
        mtt_args+=("--clean-start")
    fi

    mtt_args+=("${ini}")

    log_raw "Invoking: python3 ${mtt_args[*]}"
    log_verbose "Running pymtt.py ..."

    local rc=0
    if [[ "${VERBOSE}" == "true" ]]; then
        python3 "${mtt_args[@]}" 2>&1 | tee "${mtt_log}" || rc=$?
    else
        python3 "${mtt_args[@]}" > "${mtt_log}" 2>&1 || rc=$?
    fi

    log_raw "pymtt.py exited with rc=${rc}"
    return ${rc}
}
