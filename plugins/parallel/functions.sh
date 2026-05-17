# Parallel Plugin - Functions
# Provides concurrent execution helpers with automatic backend selection.
#
# Usage:
#   parallel_run "process_file" file1.txt file2.txt file3.txt
#   echo -e "url1\nurl2\nurl3" | parallel_map "curl -s"
#   parallel_for_each /data/*.csv -- gzip -9
#   parallel_wait  # Wait for all background jobs

# ==============================================================================
# CORE PARALLEL EXECUTION
# ==============================================================================

# Run a command concurrently across a list of arguments
# Each argument becomes the last argument to the command.
# Arguments:
#   $1 - Command or function name
#   $2...$N - Arguments to distribute
# Returns: 0 if all jobs succeeded, 1 if any failed
parallel_run() {
    local cmd=$1
    shift
    local -a items=("$@")

    case "$PARALLEL_ACTIVE_BACKEND" in
        parallel) _parallel_gnu_run "$cmd" "${items[@]}" ;;
        xargs)    _parallel_xargs_run "$cmd" "${items[@]}" ;;
        jobs)     _parallel_jobs_run "$cmd" "${items[@]}" ;;
    esac
}

# Map a command over lines from stdin
# Each line of input becomes the argument to the command.
# Arguments:
#   $1 - Command or function name
# Returns: Combined stdout from all invocations
parallel_map() {
    local cmd=$1

    case "$PARALLEL_ACTIVE_BACKEND" in
        parallel)
            parallel --jobs "$PARALLEL_JOBS" --will-cite "$cmd" {}
            ;;
        xargs)
            xargs -P "$PARALLEL_JOBS" -I {} sh -c "${cmd} {}"
            ;;
        jobs)
            local -a lines=()
            while IFS= read -r line; do
                lines+=("$line")
            done
            _parallel_jobs_run "$cmd" "${lines[@]}"
            ;;
    esac
}

# Run a command for each file matching a glob pattern
# Arguments:
#   $1...$N - File paths or glob patterns
#   --      - Separator
#   CMD     - Command and any prefix arguments
# Returns: 0 if all succeeded, 1 if any failed
parallel_for_each() {
    local -a files=()
    local -a cmd=()
    local pastSeparator=false

    for arg in "$@"; do
        if [[ "$arg" == "--" ]]; then
            pastSeparator=true
            continue
        fi

        if [[ "$pastSeparator" == "true" ]]; then
            cmd+=("$arg")
        else
            files+=("$arg")
        fi
    done

    if [[ ${#cmd[@]} -eq 0 ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "parallel_for_each: No command specified after --"
        fi
        return 1
    fi

    parallel_run "${cmd[*]}" "${files[@]}"
}

# ==============================================================================
# JOB MANAGEMENT
# ==============================================================================

# Track background job PIDs
declare -a _PARALLEL_PIDS=()

# Wait for all tracked background jobs to complete
# Arguments: None
# Returns: 0 if all succeeded, 1 if any failed
parallel_wait() {
    local -i failed=0

    for pid in "${_PARALLEL_PIDS[@]}"; do
        if ! wait "$pid" 2>/dev/null; then
            ((failed++))
        fi
    done

    _PARALLEL_PIDS=()

    if ((failed > 0)); then
        if declare -f warn >/dev/null 2>&1; then
            warn "parallel_wait: ${failed} job(s) failed"
        fi
        return 1
    fi

    return 0
}

# Run a command in the background and track its PID
# Arguments:
#   $@ - Command and arguments
# Returns: PID of background process via stdout
parallel_background() {
    "$@" &
    local pid=$!
    _PARALLEL_PIDS+=("$pid")

    if declare -f debug >/dev/null 2>&1; then
        debug "parallel: Backgrounded PID ${pid}: $*"
    fi

    echo "$pid"
}

# Get the number of currently running tracked jobs
# Arguments: None
# Returns: Count via stdout
parallel_active_count() {
    local -i active=0
    for pid in "${_PARALLEL_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            ((active++))
        fi
    done
    echo "$active"
}

# ==============================================================================
# BACKEND IMPLEMENTATIONS (internal)
# ==============================================================================

# GNU Parallel implementation
_parallel_gnu_run() {
    local cmd=$1
    shift
    local -a extraOpts=()

    if [[ "$PARALLEL_PROGRESS" == "true" ]]; then
        extraOpts+=(--bar)
    fi

    if [[ "$PARALLEL_ON_ERROR" == "fail_fast" ]]; then
        extraOpts+=(--halt now,fail=1)
    fi

    printf '%s\n' "$@" | \
        "$PARALLEL_GNU_BIN" \
            --jobs "$PARALLEL_JOBS" \
            --will-cite \
            "${extraOpts[@]}" \
            "$cmd" {}
}

# xargs implementation
_parallel_xargs_run() {
    local cmd=$1
    shift

    printf '%s\n' "$@" | \
        "$PARALLEL_XARGS_BIN" \
            -P "$PARALLEL_JOBS" \
            -I {} \
            sh -c "${cmd} \"\$@\"" _ {}
}

# Built-in job control implementation
_parallel_jobs_run() {
    local cmd=$1
    shift
    local -a items=("$@")
    local -a pids=()
    local -i running=0
    local -i failed=0
    local -i completed=0
    local -i total=${#items[@]}

    for item in "${items[@]}"; do
        # Wait if we've hit the concurrency limit
        while (( running >= PARALLEL_JOBS )); do
            # Wait for any child to finish
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    if ! wait "${pids[$i]}" 2>/dev/null; then
                        ((failed++))
                        if [[ "$PARALLEL_ON_ERROR" == "fail_fast" ]]; then
                            # Kill remaining jobs
                            for p in "${pids[@]}"; do
                                kill "$p" 2>/dev/null || true
                            done
                            return 1
                        fi
                    fi
                    unset 'pids[i]'
                    ((running--))
                    ((completed++))

                    if [[ "$PARALLEL_PROGRESS" == "true" ]] && declare -f info >/dev/null 2>&1; then
                        info "parallel: ${completed}/${total} complete"
                    fi
                fi
            done
            sleep 0.1
        done

        # Launch the job
        $cmd "$item" &
        pids+=($!)
        ((running++))
    done

    # Wait for remaining jobs
    for pid in "${pids[@]}"; do
        if ! wait "$pid" 2>/dev/null; then
            ((failed++))
        fi
        ((completed++))
    done

    if [[ "$PARALLEL_PROGRESS" == "true" ]] && declare -f info >/dev/null 2>&1; then
        info "parallel: ${completed}/${total} complete (${failed} failed)"
    fi

    (( failed > 0 )) && return 1
    return 0
}

# ==============================================================================
# DIAGNOSTICS
# ==============================================================================

# Print parallel execution status
parallel_status() {
    printf 'Parallel Plugin Status:\n'
    printf '  Backend:     %s\n' "$PARALLEL_ACTIVE_BACKEND"
    printf '  Max jobs:    %d\n' "$PARALLEL_JOBS"
    printf '  CPU cores:   %d\n' "$PARALLEL_CPU_COUNT"
    printf '  On error:    %s\n' "$PARALLEL_ON_ERROR"
    printf '  Progress:    %s\n' "$PARALLEL_PROGRESS"
    printf '  GNU parallel: %s\n' "${PARALLEL_GNU_BIN:-not found}"
    printf '  xargs:       %s\n' "${PARALLEL_XARGS_BIN:-not found}"
    printf '  Active jobs: %s\n' "$(parallel_active_count)"
}
