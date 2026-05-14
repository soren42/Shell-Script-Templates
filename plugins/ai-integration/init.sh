# AI Integration Plugin - Initialization
# Validates that curl and jq are available and API key is configured

# Track initialization state
AI_INITIALIZED=false

# Validate dependencies
if ! command -v curl >/dev/null 2>&1; then
    if declare -f warn >/dev/null 2>&1; then
        warn "ai-integration: curl not found, plugin disabled"
    fi
    return 0
fi

if ! command -v jq >/dev/null 2>&1; then
    if declare -f warn >/dev/null 2>&1; then
        warn "ai-integration: jq not found, plugin disabled"
    fi
    return 0
fi

# Resolve active model based on provider
case "$AI_PROVIDER" in
    anthropic)
        AI_ACTIVE_MODEL="${AI_MODEL_ANTHROPIC}"
        AI_ACTIVE_ENDPOINT="${AI_ENDPOINT_ANTHROPIC}"
        AI_ACTIVE_KEY="${ANTHROPIC_API_KEY:-}"
        ;;
    openai)
        AI_ACTIVE_MODEL="${AI_MODEL_OPENAI}"
        AI_ACTIVE_ENDPOINT="${AI_ENDPOINT_OPENAI}"
        AI_ACTIVE_KEY="${OPENAI_API_KEY:-}"
        ;;
    google)
        AI_ACTIVE_MODEL="${AI_MODEL_GOOGLE}"
        AI_ACTIVE_ENDPOINT="${AI_ENDPOINT_GOOGLE}/${AI_MODEL_GOOGLE}"
        AI_ACTIVE_KEY="${GOOGLE_API_KEY:-}"
        ;;
    *)
        if declare -f warn >/dev/null 2>&1; then
            warn "ai-integration: Unknown provider '${AI_PROVIDER}', defaulting to anthropic"
        fi
        AI_PROVIDER="anthropic"
        AI_ACTIVE_MODEL="${AI_MODEL_ANTHROPIC}"
        AI_ACTIVE_ENDPOINT="${AI_ENDPOINT_ANTHROPIC}"
        AI_ACTIVE_KEY="${ANTHROPIC_API_KEY:-}"
        ;;
esac

# Warn if API key is missing (don't fail - user may set it later)
if [[ -z "$AI_ACTIVE_KEY" ]]; then
    if declare -f warn >/dev/null 2>&1; then
        warn "ai-integration: No API key set for provider '${AI_PROVIDER}'"
        warn "ai-integration: Set ${AI_PROVIDER^^}_API_KEY environment variable"
    fi
else
    AI_INITIALIZED=true
fi

if declare -f debug >/dev/null 2>&1; then
    debug "ai-integration loaded: provider=${AI_PROVIDER} model=${AI_ACTIVE_MODEL}"
fi
