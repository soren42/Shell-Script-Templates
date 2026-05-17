# Logging Extended Plugin - Initialization
# Detects available logging backends and configures defaults

LOG_EXT_READY=false
LOG_LOGGER_BIN=""
LOG_SYSTEMD_CAT_BIN=""

# Detect syslog client
if command -v logger >/dev/null 2>&1; then
    LOG_LOGGER_BIN=$(command -v logger)
fi

# Detect systemd-cat for journald
if command -v systemd-cat >/dev/null 2>&1; then
    LOG_SYSTEMD_CAT_BIN=$(command -v systemd-cat)
fi

# Set default syslog tag from script name if available
if [[ -z "$LOG_SYSLOG_TAG" ]]; then
    LOG_SYSLOG_TAG="${SCRIPT_NAME:-shell-script}"
fi

# Set default log file path
if [[ -z "$LOG_FILE_PATH" ]] && [[ "$LOG_FILE_ENABLED" == "true" ]]; then
    if [[ -w /var/log/ ]]; then
        LOG_FILE_PATH="/var/log/${LOG_SYSLOG_TAG}.log"
    else
        local logDir="${HOME}/.local/log"
        mkdir -p "$logDir" 2>/dev/null || true
        LOG_FILE_PATH="${logDir}/${LOG_SYSLOG_TAG}.log"
    fi
fi

LOG_EXT_READY=true

if declare -f debug >/dev/null 2>&1; then
    debug "logging-extended loaded: logger=${LOG_LOGGER_BIN:-none} systemd-cat=${LOG_SYSTEMD_CAT_BIN:-none}"
fi
