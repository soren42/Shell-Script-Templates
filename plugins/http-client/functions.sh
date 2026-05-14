# HTTP Client Plugin - Functions
# Provides a robust wrapper around curl with retry logic, authentication,
# error handling, and response parsing.
#
# Usage:
#   response=$(http_get "https://api.example.com/data")
#   http_post "https://api.example.com/data" '{"key":"value"}'
#   http_download "https://example.com/file.zip" /tmp/file.zip

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

# Track the last HTTP status code and response headers
HTTP_LAST_STATUS=0
HTTP_LAST_HEADERS=""

# Build common curl arguments
# Arguments: Additional curl args
# Returns: Full curl command via stdout (as array-safe string)
_http_build_curl_args() {
    local -a args=(
        -s                                          # Silent mode
        --max-time "$HTTP_TIMEOUT"                 # Total timeout
        --connect-timeout "$HTTP_CONNECT_TIMEOUT"  # Connection timeout
        -A "$HTTP_USER_AGENT"                      # User agent
        -w '\n%{http_code}'                        # Append HTTP status code
    )

    # Follow redirects if configured
    if [[ "$HTTP_FOLLOW_REDIRECTS" == "true" ]]; then
        args+=(-L --max-redirs "$HTTP_MAX_REDIRECTS")
    fi

    printf '%s\n' "${args[@]}"
}

# Execute a curl request with retry logic
# Globals: HTTP_MAX_RETRIES, HTTP_RETRY_DELAY, HTTP_LAST_STATUS
# Arguments:
#   $@ - Full curl arguments
# Returns: Response body via stdout, sets HTTP_LAST_STATUS
_http_execute() {
    local -i attempt=0
    local response
    local httpCode
    local curlExit

    while (( attempt <= HTTP_MAX_RETRIES )); do
        if (( attempt > 0 )); then
            if declare -f debug >/dev/null 2>&1; then
                debug "http-client: Retry ${attempt}/${HTTP_MAX_RETRIES} after ${HTTP_RETRY_DELAY}s"
            fi
            sleep "$HTTP_RETRY_DELAY"
        fi

        response=$(curl "$@" 2>/dev/null) || curlExit=$?
        curlExit=${curlExit:-0}

        if [[ $curlExit -ne 0 ]]; then
            ((attempt++)) || true
            continue
        fi

        # Extract HTTP status code from the last line
        httpCode="${response##*$'\n'}"
        response="${response%$'\n'*}"

        HTTP_LAST_STATUS=$httpCode

        # Retry on server errors (5xx) or timeout
        if (( httpCode >= 500 )); then
            if declare -f debug >/dev/null 2>&1; then
                debug "http-client: Server error ${httpCode}, will retry"
            fi
            ((attempt++)) || true
            continue
        fi

        # Success (or client error that shouldn't be retried)
        echo "$response"
        return 0
    done

    # All retries exhausted
    if declare -f error >/dev/null 2>&1; then
        error "http-client: Request failed after ${HTTP_MAX_RETRIES} retries (last status: ${HTTP_LAST_STATUS})"
    fi
    echo "$response"
    return 1
}

# ==============================================================================
# HTTP METHODS
# ==============================================================================

# Perform an HTTP GET request
# Globals: HTTP_* configuration
# Arguments:
#   $1 - URL
#   --header "Name: Value"  - Additional headers (repeatable)
#   --auth "user:pass"      - Basic authentication
#   --bearer TOKEN          - Bearer token authentication
# Returns: Response body via stdout
http_get() {
    local url=""
    local -a extraArgs=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --header)  extraArgs+=(-H "$2"); shift 2 ;;
            --auth)    extraArgs+=(-u "$2"); shift 2 ;;
            --bearer)  extraArgs+=(-H "Authorization: Bearer $2"); shift 2 ;;
            -*)
                if declare -f error >/dev/null 2>&1; then
                    error "http_get: Unknown option: $1"
                fi
                return 1
                ;;
            *)  url=$1; shift ;;
        esac
    done

    local -a curlArgs=()
    mapfile -t curlArgs < <(_http_build_curl_args)

    _http_execute "${curlArgs[@]}" "${extraArgs[@]}" "$url"
}

# Perform an HTTP POST request
# Globals: HTTP_* configuration
# Arguments:
#   $1 - URL
#   $2 - Request body (optional)
#   --header "Name: Value"  - Additional headers (repeatable)
#   --json                  - Set Content-Type to application/json
#   --form "key=value"      - Send as form data (repeatable)
#   --auth "user:pass"      - Basic authentication
#   --bearer TOKEN          - Bearer token authentication
# Returns: Response body via stdout
http_post() {
    local url=""
    local body=""
    local contentType=""
    local -a extraArgs=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --header)  extraArgs+=(-H "$2"); shift 2 ;;
            --json)    contentType="application/json"; shift ;;
            --form)    extraArgs+=(-F "$2"); shift 2 ;;
            --auth)    extraArgs+=(-u "$2"); shift 2 ;;
            --bearer)  extraArgs+=(-H "Authorization: Bearer $2"); shift 2 ;;
            -*)
                if declare -f error >/dev/null 2>&1; then
                    error "http_post: Unknown option: $1"
                fi
                return 1
                ;;
            *)
                if [[ -z "$url" ]]; then
                    url=$1
                else
                    body=$1
                fi
                shift
                ;;
        esac
    done

    local -a curlArgs=()
    mapfile -t curlArgs < <(_http_build_curl_args)

    if [[ -n "$contentType" ]]; then
        extraArgs+=(-H "Content-Type: ${contentType}")
    fi

    if [[ -n "$body" ]]; then
        extraArgs+=(-d "$body")
    fi

    _http_execute "${curlArgs[@]}" -X POST "${extraArgs[@]}" "$url"
}

# Perform an HTTP PUT request
# Globals: HTTP_* configuration
# Arguments: Same as http_post
# Returns: Response body via stdout
http_put() {
    local url=""
    local body=""
    local -a extraArgs=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --header)  extraArgs+=(-H "$2"); shift 2 ;;
            --json)    extraArgs+=(-H "Content-Type: application/json"); shift ;;
            --auth)    extraArgs+=(-u "$2"); shift 2 ;;
            --bearer)  extraArgs+=(-H "Authorization: Bearer $2"); shift 2 ;;
            -*)  shift ;;
            *)
                if [[ -z "$url" ]]; then url=$1; else body=$1; fi
                shift
                ;;
        esac
    done

    local -a curlArgs=()
    mapfile -t curlArgs < <(_http_build_curl_args)

    [[ -n "$body" ]] && extraArgs+=(-d "$body")

    _http_execute "${curlArgs[@]}" -X PUT "${extraArgs[@]}" "$url"
}

# Perform an HTTP DELETE request
# Globals: HTTP_* configuration
# Arguments:
#   $1 - URL
#   --header, --auth, --bearer as above
# Returns: Response body via stdout
http_delete() {
    local url=""
    local -a extraArgs=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --header)  extraArgs+=(-H "$2"); shift 2 ;;
            --auth)    extraArgs+=(-u "$2"); shift 2 ;;
            --bearer)  extraArgs+=(-H "Authorization: Bearer $2"); shift 2 ;;
            -*)  shift ;;
            *)   url=$1; shift ;;
        esac
    done

    local -a curlArgs=()
    mapfile -t curlArgs < <(_http_build_curl_args)

    _http_execute "${curlArgs[@]}" -X DELETE "${extraArgs[@]}" "$url"
}

# ==============================================================================
# FILE OPERATIONS
# ==============================================================================

# Download a file with progress indication
# Globals: HTTP_* configuration
# Arguments:
#   $1 - URL
#   $2 - Output file path
#   --auth, --bearer as above
# Returns: 0 on success, 1 on failure
http_download() {
    local url=""
    local outputPath=""
    local -a extraArgs=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --auth)    extraArgs+=(-u "$2"); shift 2 ;;
            --bearer)  extraArgs+=(-H "Authorization: Bearer $2"); shift 2 ;;
            -*)  shift ;;
            *)
                if [[ -z "$url" ]]; then url=$1; else outputPath=$1; fi
                shift
                ;;
        esac
    done

    if [[ -z "$outputPath" ]]; then
        outputPath=$(basename "$url")
    fi

    if declare -f info >/dev/null 2>&1; then
        info "Downloading: ${url}"
    fi

    local -i attempt=0
    while (( attempt <= HTTP_MAX_RETRIES )); do
        if (( attempt > 0 )); then
            sleep "$HTTP_RETRY_DELAY"
        fi

        if curl -L \
            --max-time "$HTTP_TIMEOUT" \
            --connect-timeout "$HTTP_CONNECT_TIMEOUT" \
            -A "$HTTP_USER_AGENT" \
            -o "$outputPath" \
            --progress-bar \
            "${extraArgs[@]}" \
            "$url"; then
            if declare -f info >/dev/null 2>&1; then
                info "Downloaded: ${outputPath}"
            fi
            return 0
        fi

        ((attempt++)) || true
    done

    if declare -f error >/dev/null 2>&1; then
        error "http_download: Failed after ${HTTP_MAX_RETRIES} retries"
    fi
    return 1
}

# Upload a file via HTTP POST (multipart form)
# Globals: HTTP_* configuration
# Arguments:
#   $1 - URL
#   $2 - File path to upload
#   $3 - Form field name (optional, default: "file")
#   --auth, --bearer as above
# Returns: Response body via stdout
http_upload() {
    local url=$1
    local filePath=$2
    local fieldName=${3:-"file"}
    shift 3 || true
    local -a extraArgs=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --auth)    extraArgs+=(-u "$2"); shift 2 ;;
            --bearer)  extraArgs+=(-H "Authorization: Bearer $2"); shift 2 ;;
            -*)  shift ;;
        esac
    done

    if [[ ! -r "$filePath" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "http_upload: Cannot read file: ${filePath}"
        fi
        return 1
    fi

    local -a curlArgs=()
    mapfile -t curlArgs < <(_http_build_curl_args)

    _http_execute "${curlArgs[@]}" -X POST \
        -F "${fieldName}=@${filePath}" \
        "${extraArgs[@]}" \
        "$url"
}

# ==============================================================================
# RESPONSE HELPERS
# ==============================================================================

# Get the HTTP status code from the last request
# Globals: HTTP_LAST_STATUS
# Arguments: None
# Returns: Status code via stdout
http_status() {
    echo "$HTTP_LAST_STATUS"
}

# Check if the last request was successful (2xx status)
# Globals: HTTP_LAST_STATUS
# Arguments: None
# Returns: 0 if success (2xx), 1 otherwise
http_ok() {
    (( HTTP_LAST_STATUS >= 200 && HTTP_LAST_STATUS < 300 ))
}

# Check if a URL is reachable (HEAD request)
# Arguments:
#   $1 - URL to check
#   $2 - Timeout in seconds (optional, default: 5)
# Returns: 0 if reachable, 1 if not
http_reachable() {
    local url=$1
    local timeout=${2:-5}

    curl -s -o /dev/null \
        --max-time "$timeout" \
        --connect-timeout "$timeout" \
        -I -w '%{http_code}' \
        "$url" 2>/dev/null | grep -q '^[23]'
}
