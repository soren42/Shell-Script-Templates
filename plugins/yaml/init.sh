# YAML Plugin - Initialization
# Detects yq and determines which implementation is available
# Supports Mike Farah's Go-based yq (preferred) and identifies the variant

YAML_READY=false
YAML_YQ_BIN=""
YAML_YQ_VARIANT=""  # "go" (Mike Farah) or "unknown"

if command -v yq >/dev/null 2>&1; then
    YAML_YQ_BIN=$(command -v yq)

    # Detect variant from version output
    local versionOutput
    versionOutput=$(yq --version 2>&1 || true)

    if echo "$versionOutput" | grep -qi 'mikefarah\|version v4\|version 4'; then
        YAML_YQ_VARIANT="go"
        YAML_READY=true
    else
        # Assume Go variant for anything else that responds to --version
        YAML_YQ_VARIANT="go"
        YAML_READY=true
    fi
else
    if declare -f warn >/dev/null 2>&1; then
        warn "yaml: yq not found (install: https://github.com/mikefarah/yq)"
    fi
fi

if declare -f debug >/dev/null 2>&1; then
    debug "yaml loaded: yq=${YAML_YQ_BIN:-none} variant=${YAML_YQ_VARIANT:-none}"
fi
