# Logging Extended Plugin - Functions
# Extends the built-in logging system with syslog, journald, and
# file-based logging with automatic rotation.
#
# Usage:
#   log_to_syslog "info" "Service started successfully"
#   log_to_journal "warning" "Disk usage approaching threshold"
#   log_to_file "error" "Connection refused"
#   log_rotate             # Manually trigger rotation
#   log_extended "info" "Logged to all configured backends"

# ==============================================================================
# SYSLOG
# ==============================================================================

# Send a message to syslog via the logger command
# Globals: LOG_LOGGER_BIN, LOG_SYSLOG_FACILITY, LOG_SYSLOG_TAG
# Arguments:
#   $1 - Severity: emerg, alert, crit, err, warning, notice, info, debug
#   $2 - Message text
# Returns: 0 on success, 1 on failure
log_to_syslog() {
    local severity=$1
    local message=$2

    if [[ "$LOG_SYSLOG_ENABLED" != "true" ]]; then
        return 0
    fi

    if [[ -z "$LOG_LOGGER_BIN" ]]; then
        return 1
    fi

    "$LOG_LOGGER_BIN" \
        -p "${LOG_SYSLOG_FACILITY}.${severity}" \
        -t "$LOG_SYSLOG_TAG" \
        -- "$message" 2>/dev/null
}

# ==============================================================================
# JOURNALD
# ==============================================================================

# Send a message to systemd journal
# Globals: LOG_SYSTEMD_CAT_BIN, LOG_SYSLOG_TAG
# Arguments:
#   $1 - Priority: emerg, alert, crit, err, warning, notice, info, debug
#   $2 - Message text
# Returns: 0 on success, 1 on failure
log_to_journal() {
    local priority=$1
    local message=$2

    if [[ "$LOG_JOURNALD_ENABLED" != "true" ]]; then
        return 0
    fi

    if [[ -n "$LOG_SYSTEMD_CAT_BIN" ]]; then
        echo "$message" | "$LOG_SYSTEMD_CAT_BIN" \
            -t "$LOG_SYSLOG_TAG" \
            -p "$priority" 2>/dev/null
    elif command -v logger >/dev/null 2>&1; then
        # Fallback: logger on systemd systems writes to journal
        logger -t "$LOG_SYSLOG_TAG" -p "user.${priority}" -- "$message" 2>/dev/null
    else
        return 1
    fi
}

# ==============================================================================
# FILE LOGGING
# ==============================================================================

# Append a message to the log file with timestamp
# Globals: LOG_FILE_PATH, LOG_FILE_MAX_SIZE_KB
# Arguments:
#   $1 - Log level (INFO, WARN, ERROR, DEBUG, etc.)
#   $2 - Message text
# Returns: 0 on success, 1 on failure
log_to_file() {
    local level=$1
    local message=$2

    if [[ "$LOG_FILE_ENABLED" != "true" ]]; then
        return 0
    fi

    if [[ -z "$LOG_FILE_PATH" ]]; then
        return 1
    fi

    # Ensure log directory exists
    local logDir
    logDir=$(dirname "$LOG_FILE_PATH")
    if [[ ! -d "$logDir" ]]; then
        mkdir -p "$logDir" 2>/dev/null || return 1
    fi

    # Format and append
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$LOG_SYSLOG_TAG" "$level" "$message" \
        >> "$LOG_FILE_PATH" 2>/dev/null || return 1

    # Check if rotation is needed
    if [[ -f "$LOG_FILE_PATH" ]]; then
        local fileSizeKb
        fileSizeKb=$(du -k "$LOG_FILE_PATH" 2>/dev/null | cut -f1)
        if [[ -n "$fileSizeKb" ]] && (( fileSizeKb >= LOG_FILE_MAX_SIZE_KB )); then
            log_rotate
        fi
    fi

    return 0
}

# Rotate log files
# Globals: LOG_FILE_PATH, LOG_FILE_MAX_ROTATIONS, LOG_FILE_COMPRESS
# Arguments: None
# Returns: 0 on success
log_rotate() {
    if [[ -z "$LOG_FILE_PATH" ]] || [[ ! -f "$LOG_FILE_PATH" ]]; then
        return 0
    fi

    local -i i

    # Remove the oldest rotation if it exists
    local oldestGz="${LOG_FILE_PATH}.${LOG_FILE_MAX_ROTATIONS}.gz"
    local oldestPlain="${LOG_FILE_PATH}.${LOG_FILE_MAX_ROTATIONS}"
    [[ -f "$oldestGz" ]] && rm -f "$oldestGz"
    [[ -f "$oldestPlain" ]] && rm -f "$oldestPlain"

    # Shift existing rotated files up by one
    for (( i = LOG_FILE_MAX_ROTATIONS - 1; i >= 1; i-- )); do
        local next=$((i + 1))

        if [[ -f "${LOG_FILE_PATH}.${i}.gz" ]]; then
            mv "${LOG_FILE_PATH}.${i}.gz" "${LOG_FILE_PATH}.${next}.gz"
        elif [[ -f "${LOG_FILE_PATH}.${i}" ]]; then
            mv "${LOG_FILE_PATH}.${i}" "${LOG_FILE_PATH}.${next}"
        fi
    done

    # Rotate current log to .1
    mv "$LOG_FILE_PATH" "${LOG_FILE_PATH}.1"

    # Compress the rotated file if configured
    if [[ "$LOG_FILE_COMPRESS" == "true" ]] && command -v gzip >/dev/null 2>&1; then
        gzip "${LOG_FILE_PATH}.1" 2>/dev/null &
    fi

    # Create fresh log file
    touch "$LOG_FILE_PATH"

    if declare -f debug >/dev/null 2>&1; then
        debug "logging-extended: Rotated ${LOG_FILE_PATH}"
    fi

    return 0
}

# ==============================================================================
# UNIFIED LOGGING
# ==============================================================================

# Map template verbosity levels to syslog priorities
# Arguments:
#   $1 - Template level (info, warn, error, debug, trace)
# Returns: Syslog priority via stdout
_log_map_priority() {
    local level=$1
    case "${level,,}" in
        trace|debug) echo "debug" ;;
        info)        echo "info" ;;
        warn*)       echo "warning" ;;
        error)       echo "err" ;;
        fatal)       echo "crit" ;;
        *)           echo "info" ;;
    esac
}

# Log a message to all enabled backends simultaneously
# Arguments:
#   $1 - Log level (info, warn, error, debug, trace, fatal)
#   $2 - Message text
# Returns: None
log_extended() {
    local level=$1
    local message=$2
    local syslogPriority
    syslogPriority=$(_log_map_priority "$level")

    # Send to syslog
    log_to_syslog "$syslogPriority" "$message"

    # Send to journald
    log_to_journal "$syslogPriority" "$message"

    # Send to file
    log_to_file "${level^^}" "$message"

    # Also call the template's built-in logger if available
    case "${level,,}" in
        info)   declare -f info  >/dev/null 2>&1 && info "$message" ;;
        warn*)  declare -f warn  >/dev/null 2>&1 && warn "$message" ;;
        error)  declare -f error >/dev/null 2>&1 && error "$message" ;;
        debug)  declare -f debug >/dev/null 2>&1 && debug "$message" ;;
        trace)  declare -f trace >/dev/null 2>&1 && trace "$message" ;;
        fatal)  declare -f fatal >/dev/null 2>&1 && fatal "$message" ;;
    esac
}

# ==============================================================================
# LOG QUERYING
# ==============================================================================

# Tail the current log file
# Arguments:
#   $1 - Number of lines (optional, default: 20)
# Returns: Last N lines via stdout
log_tail() {
    local lines=${1:-20}

    if [[ -f "$LOG_FILE_PATH" ]]; then
        tail -n "$lines" "$LOG_FILE_PATH"
    fi
}

# Search log file for a pattern
# Arguments:
#   $1 - Search pattern (grep-compatible)
#   $2 - Number of results to return (optional)
# Returns: Matching lines via stdout
log_search() {
    local pattern=$1
    local maxResults=${2:-""}

    if [[ ! -f "$LOG_FILE_PATH" ]]; then
        return 1
    fi

    if [[ -n "$maxResults" ]]; then
        grep -i "$pattern" "$LOG_FILE_PATH" | tail -n "$maxResults"
    else
        grep -i "$pattern" "$LOG_FILE_PATH"
    fi
}

# Get log file size information
# Arguments: None
# Returns: Status info via stdout
log_file_status() {
    printf 'Log File Status:\n'
    printf '  Path:         %s\n' "${LOG_FILE_PATH:-not configured}"

    if [[ -f "$LOG_FILE_PATH" ]]; then
        printf '  Size:         %s\n' "$(du -h "$LOG_FILE_PATH" | cut -f1)"
        printf '  Lines:        %s\n' "$(wc -l < "$LOG_FILE_PATH")"
        printf '  Max size:     %sKB\n' "$LOG_FILE_MAX_SIZE_KB"
        printf '  Max rotations: %s\n' "$LOG_FILE_MAX_ROTATIONS"
        printf '  Compress:     %s\n' "$LOG_FILE_COMPRESS"

        # Count existing rotations
        local rotated
        rotated=$(ls -1 "${LOG_FILE_PATH}".* 2>/dev/null | wc -l)
        printf '  Rotated files: %s\n' "$rotated"
    else
        printf '  Status:       file does not exist yet\n'
    fi
}
