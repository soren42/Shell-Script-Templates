# Notification Plugin - Initialization
# Validates available delivery methods

NOTIFY_READY=false
NOTIFY_CURL_BIN=""
NOTIFY_SENDMAIL_BIN=""
NOTIFY_MSMTP_BIN=""

# curl is required for ntfy and webhooks
if command -v curl >/dev/null 2>&1; then
    NOTIFY_CURL_BIN=$(command -v curl)
    NOTIFY_READY=true
fi

# Detect email delivery method
if command -v sendmail >/dev/null 2>&1; then
    NOTIFY_SENDMAIL_BIN=$(command -v sendmail)
fi

if command -v msmtp >/dev/null 2>&1; then
    NOTIFY_MSMTP_BIN=$(command -v msmtp)
fi

if [[ -z "$NOTIFY_CURL_BIN" ]]; then
    if declare -f warn >/dev/null 2>&1; then
        warn "notification: curl not found, ntfy and webhook delivery disabled"
    fi
fi

if declare -f debug >/dev/null 2>&1; then
    debug "notification loaded: curl=${NOTIFY_CURL_BIN:-none} sendmail=${NOTIFY_SENDMAIL_BIN:-none}"
fi
