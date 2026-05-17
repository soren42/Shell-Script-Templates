# Notification Plugin - Functions
# Provides multi-channel notification delivery.
#
# Usage:
#   notify_ntfy "Backup complete" "All databases backed up successfully"
#   notify_email "Build failed" "See attached log for details"
#   notify_webhook "Deployment finished" "Production v2.1.0 is live"
#   notify_all "System alert" "Disk usage at 90%"

# ==============================================================================
# NTFY NOTIFICATIONS
# ==============================================================================

# Send a notification via ntfy
# Globals: NOTIFY_NTFY_SERVER, NOTIFY_NTFY_TOPIC, NOTIFY_NTFY_TOKEN,
#          NOTIFY_NTFY_PRIORITY, NOTIFY_TIMEOUT
# Arguments:
#   $1 - Title (short message)
#   $2 - Body text (optional)
#   --topic TOPIC      - Override default topic
#   --priority P       - Priority: min, low, default, high, urgent
#   --tags TAG,TAG     - Comma-separated emoji tags
#   --click URL        - URL to open when notification is clicked
#   --attach URL       - Attachment URL
#   --actions JSON     - Action buttons (ntfy JSON format)
# Returns: 0 on success, 1 on failure
notify_ntfy() {
    local title=""
    local body=""
    local topic="$NOTIFY_NTFY_TOPIC"
    local priority="$NOTIFY_NTFY_PRIORITY"
    local tags=""
    local clickUrl=""
    local attachUrl=""
    local actions=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --topic)    topic=$2; shift 2 ;;
            --priority) priority=$2; shift 2 ;;
            --tags)     tags=$2; shift 2 ;;
            --click)    clickUrl=$2; shift 2 ;;
            --attach)   attachUrl=$2; shift 2 ;;
            --actions)  actions=$2; shift 2 ;;
            -*)
                if declare -f warn >/dev/null 2>&1; then
                    warn "notify_ntfy: Unknown option: $1"
                fi
                shift
                ;;
            *)
                if [[ -z "$title" ]]; then
                    title=$1
                else
                    body=$1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$topic" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "notify_ntfy: No topic configured (set NOTIFY_NTFY_TOPIC)"
        fi
        return 1
    fi

    # Build headers
    local -a headers=(
        -H "Title: ${title}"
        -H "Priority: ${priority}"
    )

    [[ -n "$tags" ]]     && headers+=(-H "Tags: ${tags}")
    [[ -n "$clickUrl" ]] && headers+=(-H "Click: ${clickUrl}")
    [[ -n "$attachUrl" ]] && headers+=(-H "Attach: ${attachUrl}")
    [[ -n "$actions" ]]  && headers+=(-H "Actions: ${actions}")

    # Authentication
    if [[ -n "$NOTIFY_NTFY_TOKEN" ]]; then
        headers+=(-H "Authorization: Bearer ${NOTIFY_NTFY_TOKEN}")
    fi

    # Send
    local response
    response=$(curl -s --max-time "$NOTIFY_TIMEOUT" \
        "${headers[@]}" \
        -d "${body:-$title}" \
        "${NOTIFY_NTFY_SERVER}/${topic}" 2>&1)

    local exitCode=$?

    if [[ $exitCode -ne 0 ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "notify_ntfy: Failed to send (curl exit: ${exitCode})"
        fi
        return 1
    fi

    if declare -f debug >/dev/null 2>&1; then
        debug "notify_ntfy: Sent to ${topic}: ${title}"
    fi

    return 0
}

# ==============================================================================
# EMAIL NOTIFICATIONS
# ==============================================================================

# Send a notification via email
# Globals: NOTIFY_EMAIL_TO, NOTIFY_EMAIL_FROM, NOTIFY_EMAIL_SUBJECT_PREFIX,
#          NOTIFY_EMAIL_METHOD
# Arguments:
#   $1 - Subject line
#   $2 - Body text
#   --to ADDRESS     - Override recipient
#   --from ADDRESS   - Override sender
#   --cc ADDRESS     - Carbon copy recipient
# Returns: 0 on success, 1 on failure
notify_email() {
    local subject=""
    local body=""
    local to="$NOTIFY_EMAIL_TO"
    local from="$NOTIFY_EMAIL_FROM"
    local cc=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --to)   to=$2; shift 2 ;;
            --from) from=$2; shift 2 ;;
            --cc)   cc=$2; shift 2 ;;
            -*)     shift ;;
            *)
                if [[ -z "$subject" ]]; then
                    subject=$1
                else
                    body=$1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$to" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "notify_email: No recipient configured (set NOTIFY_EMAIL_TO)"
        fi
        return 1
    fi

    local fullSubject="${NOTIFY_EMAIL_SUBJECT_PREFIX} ${subject}"

    # Build the email message
    local message
    message="From: ${from}
To: ${to}
${cc:+Cc: ${cc}\n}Subject: ${fullSubject}
Date: $(date -R)
Content-Type: text/plain; charset=UTF-8

${body}"

    # Send via configured method
    case "$NOTIFY_EMAIL_METHOD" in
        sendmail)
            if [[ -z "$NOTIFY_SENDMAIL_BIN" ]]; then
                if declare -f error >/dev/null 2>&1; then
                    error "notify_email: sendmail not found"
                fi
                return 1
            fi
            echo -e "$message" | "$NOTIFY_SENDMAIL_BIN" -t -f "$from"
            ;;
        msmtp)
            if [[ -z "$NOTIFY_MSMTP_BIN" ]]; then
                if declare -f error >/dev/null 2>&1; then
                    error "notify_email: msmtp not found"
                fi
                return 1
            fi
            echo -e "$message" | "$NOTIFY_MSMTP_BIN" -t
            ;;
        *)
            if declare -f error >/dev/null 2>&1; then
                error "notify_email: Unknown method: ${NOTIFY_EMAIL_METHOD}"
            fi
            return 1
            ;;
    esac

    if declare -f debug >/dev/null 2>&1; then
        debug "notify_email: Sent to ${to}: ${subject}"
    fi

    return 0
}

# ==============================================================================
# WEBHOOK NOTIFICATIONS
# ==============================================================================

# Send a notification via webhook (Slack, Discord, or generic)
# Globals: NOTIFY_WEBHOOK_URL, NOTIFY_WEBHOOK_FORMAT, NOTIFY_TIMEOUT
# Arguments:
#   $1 - Title or summary text
#   $2 - Body or detail text (optional)
#   --url URL        - Override webhook URL
#   --format FMT     - Override format (slack, discord, generic)
#   --color HEX      - Sidebar color for Slack/Discord (e.g., "#FF0000")
# Returns: 0 on success, 1 on failure
notify_webhook() {
    local title=""
    local body=""
    local url="$NOTIFY_WEBHOOK_URL"
    local format="$NOTIFY_WEBHOOK_FORMAT"
    local color=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --url)    url=$2; shift 2 ;;
            --format) format=$2; shift 2 ;;
            --color)  color=$2; shift 2 ;;
            -*)       shift ;;
            *)
                if [[ -z "$title" ]]; then
                    title=$1
                else
                    body=$1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$url" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "notify_webhook: No URL configured (set NOTIFY_WEBHOOK_URL)"
        fi
        return 1
    fi

    # Build the payload based on format
    local payload
    case "$format" in
        slack)
            if [[ -n "$color" ]]; then
                payload=$(printf '{"attachments":[{"color":"%s","title":"%s","text":"%s"}]}' \
                    "$color" "$title" "${body:-$title}")
            else
                payload=$(printf '{"text":"*%s*\n%s"}' "$title" "${body:-}")
            fi
            ;;
        discord)
            if [[ -n "$color" ]]; then
                # Discord expects decimal color
                local decColor
                decColor=$((16#${color#\#}))
                payload=$(printf '{"embeds":[{"title":"%s","description":"%s","color":%d}]}' \
                    "$title" "${body:-$title}" "$decColor")
            else
                payload=$(printf '{"content":"**%s**\n%s"}' "$title" "${body:-}")
            fi
            ;;
        generic|*)
            payload=$(printf '{"title":"%s","message":"%s","timestamp":"%s"}' \
                "$title" "${body:-$title}" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')")
            ;;
    esac

    # Send
    local response
    response=$(curl -s --max-time "$NOTIFY_TIMEOUT" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$url" 2>&1)

    local exitCode=$?

    if [[ $exitCode -ne 0 ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "notify_webhook: Failed to send (curl exit: ${exitCode})"
        fi
        return 1
    fi

    if declare -f debug >/dev/null 2>&1; then
        debug "notify_webhook: Sent to ${format} webhook: ${title}"
    fi

    return 0
}

# ==============================================================================
# CONVENIENCE FUNCTIONS
# ==============================================================================

# Send a notification to all configured channels
# Arguments:
#   $1 - Title
#   $2 - Body (optional)
# Returns: 0 if at least one channel succeeded, 1 if all failed
notify_all() {
    local title=$1
    local body=${2:-""}
    local -i succeeded=0

    # Try ntfy
    if [[ -n "$NOTIFY_NTFY_TOPIC" ]]; then
        notify_ntfy "$title" "$body" && ((succeeded++)) || true
    fi

    # Try email
    if [[ -n "$NOTIFY_EMAIL_TO" ]]; then
        notify_email "$title" "$body" && ((succeeded++)) || true
    fi

    # Try webhook
    if [[ -n "$NOTIFY_WEBHOOK_URL" ]]; then
        notify_webhook "$title" "$body" && ((succeeded++)) || true
    fi

    if ((succeeded == 0)); then
        if declare -f error >/dev/null 2>&1; then
            error "notify_all: All notification channels failed"
        fi
        return 1
    fi

    return 0
}

# Send a success notification (green/check styling where supported)
# Arguments:
#   $1 - Title
#   $2 - Body (optional)
notify_success() {
    local title=$1
    local body=${2:-""}

    if [[ -n "$NOTIFY_NTFY_TOPIC" ]]; then
        notify_ntfy "$title" "$body" --tags "white_check_mark" --priority "default"
    fi

    if [[ -n "$NOTIFY_WEBHOOK_URL" ]]; then
        notify_webhook "$title" "$body" --color "#00CC00"
    fi
}

# Send a failure notification (red/alert styling where supported)
# Arguments:
#   $1 - Title
#   $2 - Body (optional)
notify_failure() {
    local title=$1
    local body=${2:-""}

    if [[ -n "$NOTIFY_NTFY_TOPIC" ]]; then
        notify_ntfy "$title" "$body" --tags "x" --priority "high"
    fi

    if [[ -n "$NOTIFY_WEBHOOK_URL" ]]; then
        notify_webhook "$title" "$body" --color "#FF0000"
    fi
}

# Send a warning notification
# Arguments:
#   $1 - Title
#   $2 - Body (optional)
notify_warning() {
    local title=$1
    local body=${2:-""}

    if [[ -n "$NOTIFY_NTFY_TOPIC" ]]; then
        notify_ntfy "$title" "$body" --tags "warning" --priority "high"
    fi

    if [[ -n "$NOTIFY_WEBHOOK_URL" ]]; then
        notify_webhook "$title" "$body" --color "#FFAA00"
    fi
}

# ==============================================================================
# DIAGNOSTICS
# ==============================================================================

# Print notification configuration status
notify_status() {
    printf 'Notification Plugin Status:\n'
    printf '  Ready:      %s\n' "$NOTIFY_READY"
    printf '  ntfy:\n'
    printf '    Server:   %s\n' "$NOTIFY_NTFY_SERVER"
    printf '    Topic:    %s\n' "${NOTIFY_NTFY_TOPIC:-not set}"
    printf '    Token:    %s\n' "${NOTIFY_NTFY_TOKEN:+set (${#NOTIFY_NTFY_TOKEN} chars)}"
    printf '  Email:\n'
    printf '    To:       %s\n' "${NOTIFY_EMAIL_TO:-not set}"
    printf '    Method:   %s\n' "$NOTIFY_EMAIL_METHOD"
    printf '    sendmail: %s\n' "${NOTIFY_SENDMAIL_BIN:-not found}"
    printf '  Webhook:\n'
    printf '    URL:      %s\n' "${NOTIFY_WEBHOOK_URL:-not set}"
    printf '    Format:   %s\n' "$NOTIFY_WEBHOOK_FORMAT"
}
