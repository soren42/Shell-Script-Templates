# JSON Parser Plugin - Initialization
# Validates that jq is available

JSON_PARSER_READY=false

if command -v jq >/dev/null 2>&1; then
    JSON_PARSER_READY=true
    JSON_JQ_PATH=$(command -v jq)
    JSON_JQ_VERSION=$(jq --version 2>/dev/null || echo "unknown")
else
    if declare -f warn >/dev/null 2>&1; then
        warn "json-parser: jq not found, plugin disabled"
    fi
fi

if declare -f debug >/dev/null 2>&1; then
    debug "json-parser loaded: jq=${JSON_JQ_PATH:-not found} (${JSON_JQ_VERSION:-})"
fi
