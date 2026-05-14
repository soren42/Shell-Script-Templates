# HTTP Client Plugin - Initialization
# Validates that curl is available

HTTP_CLIENT_READY=false

if command -v curl >/dev/null 2>&1; then
    HTTP_CLIENT_READY=true
    HTTP_CURL_PATH=$(command -v curl)
else
    if declare -f warn >/dev/null 2>&1; then
        warn "http-client: curl not found, plugin disabled"
    fi
fi

if declare -f debug >/dev/null 2>&1; then
    debug "http-client loaded: curl=${HTTP_CURL_PATH:-not found}"
fi
