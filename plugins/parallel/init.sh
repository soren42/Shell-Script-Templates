# Parallel Plugin - Initialization
# Detects available parallelism backends and CPU core count

PARALLEL_READY=false
PARALLEL_ACTIVE_BACKEND="jobs"  # Built-in fallback always available
PARALLEL_GNU_BIN=""
PARALLEL_XARGS_BIN=""
PARALLEL_CPU_COUNT=1

# Detect CPU count
if [[ -f /proc/cpuinfo ]]; then
    PARALLEL_CPU_COUNT=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
elif command -v nproc >/dev/null 2>&1; then
    PARALLEL_CPU_COUNT=$(nproc 2>/dev/null || echo 1)
elif command -v sysctl >/dev/null 2>&1; then
    PARALLEL_CPU_COUNT=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
fi

# Set default jobs to CPU count if 0
if [[ "$PARALLEL_JOBS" -eq 0 ]]; then
    PARALLEL_JOBS=$PARALLEL_CPU_COUNT
fi

# Detect backends
if command -v parallel >/dev/null 2>&1; then
    PARALLEL_GNU_BIN=$(command -v parallel)
fi

if command -v xargs >/dev/null 2>&1; then
    PARALLEL_XARGS_BIN=$(command -v xargs)
fi

# Select backend
case "$PARALLEL_BACKEND" in
    parallel)
        if [[ -n "$PARALLEL_GNU_BIN" ]]; then
            PARALLEL_ACTIVE_BACKEND="parallel"
        fi
        ;;
    xargs)
        if [[ -n "$PARALLEL_XARGS_BIN" ]]; then
            PARALLEL_ACTIVE_BACKEND="xargs"
        fi
        ;;
    auto)
        if [[ -n "$PARALLEL_GNU_BIN" ]]; then
            PARALLEL_ACTIVE_BACKEND="parallel"
        elif [[ -n "$PARALLEL_XARGS_BIN" ]]; then
            PARALLEL_ACTIVE_BACKEND="xargs"
        else
            PARALLEL_ACTIVE_BACKEND="jobs"
        fi
        ;;
esac

PARALLEL_READY=true

if declare -f debug >/dev/null 2>&1; then
    debug "parallel loaded: backend=${PARALLEL_ACTIVE_BACKEND} jobs=${PARALLEL_JOBS} cpus=${PARALLEL_CPU_COUNT}"
fi
