# AI Integration Plugin - Functions
# Provides a unified interface for calling LLM APIs from shell scripts.
#
# Supported providers:
#   anthropic  - Claude models via Anthropic API
#   openai     - GPT models via OpenAI API
#   google     - Gemini models via Google AI API
#
# Usage:
#   response=$(ai_query "What is the capital of France?")
#   response=$(ai_query "Summarize this:" --input "$(cat document.txt)")
#   response=$(echo "log data" | ai_query "Analyze this log file")
#   ai_set_provider openai
#   ai_set_model gpt-4o

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Switch the active AI provider
# Globals: AI_PROVIDER, AI_ACTIVE_MODEL, AI_ACTIVE_ENDPOINT, AI_ACTIVE_KEY
# Arguments:
#   $1 - Provider name (anthropic, openai, google)
# Returns: 0 on success, 1 on invalid provider
ai_set_provider() {
    local provider=$1

    case "$provider" in
        anthropic)
            AI_PROVIDER="anthropic"
            AI_ACTIVE_MODEL="${AI_MODEL_ANTHROPIC}"
            AI_ACTIVE_ENDPOINT="${AI_ENDPOINT_ANTHROPIC}"
            AI_ACTIVE_KEY="${ANTHROPIC_API_KEY:-}"
            ;;
        openai)
            AI_PROVIDER="openai"
            AI_ACTIVE_MODEL="${AI_MODEL_OPENAI}"
            AI_ACTIVE_ENDPOINT="${AI_ENDPOINT_OPENAI}"
            AI_ACTIVE_KEY="${OPENAI_API_KEY:-}"
            ;;
        google)
            AI_PROVIDER="google"
            AI_ACTIVE_MODEL="${AI_MODEL_GOOGLE}"
            AI_ACTIVE_ENDPOINT="${AI_ENDPOINT_GOOGLE}/${AI_MODEL_GOOGLE}"
            AI_ACTIVE_KEY="${GOOGLE_API_KEY:-}"
            ;;
        *)
            if declare -f error >/dev/null 2>&1; then
                error "ai-integration: Unknown provider: ${provider}"
            fi
            return 1
            ;;
    esac

    AI_INITIALIZED=true
    [[ -z "$AI_ACTIVE_KEY" ]] && AI_INITIALIZED=false

    return 0
}

# Override the active model
# Globals: AI_ACTIVE_MODEL
# Arguments:
#   $1 - Model identifier string
# Returns: None
ai_set_model() {
    AI_ACTIVE_MODEL=$1
}

# Set the API key for the current provider
# Globals: AI_ACTIVE_KEY, AI_INITIALIZED
# Arguments:
#   $1 - API key string
# Returns: None
ai_set_key() {
    AI_ACTIVE_KEY=$1
    AI_INITIALIZED=true
}

# ==============================================================================
# CORE API CALLS
# ==============================================================================

# Send a query to the active LLM provider and return the text response
# Globals: AI_PROVIDER, AI_ACTIVE_MODEL, AI_ACTIVE_ENDPOINT, AI_ACTIVE_KEY,
#          AI_MAX_TOKENS, AI_TEMPERATURE, AI_TIMEOUT
# Arguments:
#   $1 - User prompt
#   --system TEXT    - Optional system prompt
#   --input TEXT     - Additional input text (appended to prompt)
#   --max-tokens N   - Override max tokens
#   --temperature F  - Override temperature
#   --raw            - Return raw JSON instead of extracted text
# Returns: Model response text via stdout, exit code 0 on success
ai_query() {
    local userPrompt=""
    local systemPrompt=""
    local inputText=""
    local maxTokens="$AI_MAX_TOKENS"
    local temperature="$AI_TEMPERATURE"
    local rawOutput=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --system)     systemPrompt=$2; shift 2 ;;
            --input)      inputText=$2; shift 2 ;;
            --max-tokens) maxTokens=$2; shift 2 ;;
            --temperature) temperature=$2; shift 2 ;;
            --raw)        rawOutput=true; shift ;;
            -*)
                if declare -f error >/dev/null 2>&1; then
                    error "ai_query: Unknown option: $1"
                fi
                return 1
                ;;
            *)
                userPrompt=$1
                shift
                ;;
        esac
    done

    # Check for piped input
    if [[ ! -t 0 ]]; then
        local pipedInput
        pipedInput=$(cat)
        if [[ -n "$pipedInput" ]]; then
            inputText="${inputText}${inputText:+\n\n}${pipedInput}"
        fi
    fi

    # Combine prompt and input
    if [[ -n "$inputText" ]]; then
        userPrompt="${userPrompt}\n\n${inputText}"
    fi

    # Validate we're ready
    if [[ "$AI_INITIALIZED" != "true" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "ai-integration: Not initialized. Set API key with ai_set_key or ${AI_PROVIDER^^}_API_KEY"
        fi
        return 1
    fi

    if [[ -z "$userPrompt" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "ai_query: No prompt provided"
        fi
        return 1
    fi

    # Dispatch to provider-specific function
    local response
    case "$AI_PROVIDER" in
        anthropic)
            response=$(_ai_call_anthropic "$userPrompt" "$systemPrompt" "$maxTokens" "$temperature")
            ;;
        openai)
            response=$(_ai_call_openai "$userPrompt" "$systemPrompt" "$maxTokens" "$temperature")
            ;;
        google)
            response=$(_ai_call_google "$userPrompt" "$systemPrompt" "$maxTokens" "$temperature")
            ;;
    esac

    local curlExit=$?
    if [[ $curlExit -ne 0 ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "ai_query: API call failed (curl exit code: ${curlExit})"
        fi
        return 1
    fi

    # Check for API errors in response
    local apiError
    apiError=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null || true)
    if [[ -n "$apiError" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "ai_query: API error: ${apiError}"
        fi
        return 1
    fi

    # Return raw or extracted text
    if [[ "$rawOutput" == "true" ]]; then
        echo "$response"
    else
        _ai_extract_text "$response"
    fi
}

# ==============================================================================
# PROVIDER-SPECIFIC API CALLS (internal)
# ==============================================================================

# Call the Anthropic Messages API
# Arguments: $1-prompt $2-system $3-maxTokens $4-temperature
# Returns: Raw JSON response via stdout
_ai_call_anthropic() {
    local prompt=$1
    local systemPrompt=$2
    local maxTokens=$3
    local temperature=$4

    # Build the request body
    local requestBody
    if [[ -n "$systemPrompt" ]]; then
        requestBody=$(jq -n \
            --arg model "$AI_ACTIVE_MODEL" \
            --argjson maxTokens "$maxTokens" \
            --argjson temperature "$temperature" \
            --arg system "$systemPrompt" \
            --arg prompt "$prompt" \
            '{
                model: $model,
                max_tokens: $maxTokens,
                temperature: $temperature,
                system: $system,
                messages: [
                    { role: "user", content: $prompt }
                ]
            }')
    else
        requestBody=$(jq -n \
            --arg model "$AI_ACTIVE_MODEL" \
            --argjson maxTokens "$maxTokens" \
            --argjson temperature "$temperature" \
            --arg prompt "$prompt" \
            '{
                model: $model,
                max_tokens: $maxTokens,
                temperature: $temperature,
                messages: [
                    { role: "user", content: $prompt }
                ]
            }')
    fi

    curl -s \
        --max-time "$AI_TIMEOUT" \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${AI_ACTIVE_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -d "$requestBody" \
        "$AI_ACTIVE_ENDPOINT"
}

# Call the OpenAI Chat Completions API
# Arguments: $1-prompt $2-system $3-maxTokens $4-temperature
# Returns: Raw JSON response via stdout
_ai_call_openai() {
    local prompt=$1
    local systemPrompt=$2
    local maxTokens=$3
    local temperature=$4

    local -a messages=()
    local requestBody

    if [[ -n "$systemPrompt" ]]; then
        requestBody=$(jq -n \
            --arg model "$AI_ACTIVE_MODEL" \
            --argjson maxTokens "$maxTokens" \
            --argjson temperature "$temperature" \
            --arg system "$systemPrompt" \
            --arg prompt "$prompt" \
            '{
                model: $model,
                max_tokens: $maxTokens,
                temperature: $temperature,
                messages: [
                    { role: "system", content: $system },
                    { role: "user", content: $prompt }
                ]
            }')
    else
        requestBody=$(jq -n \
            --arg model "$AI_ACTIVE_MODEL" \
            --argjson maxTokens "$maxTokens" \
            --argjson temperature "$temperature" \
            --arg prompt "$prompt" \
            '{
                model: $model,
                max_tokens: $maxTokens,
                temperature: $temperature,
                messages: [
                    { role: "user", content: $prompt }
                ]
            }')
    fi

    curl -s \
        --max-time "$AI_TIMEOUT" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${AI_ACTIVE_KEY}" \
        -d "$requestBody" \
        "$AI_ACTIVE_ENDPOINT"
}

# Call the Google Gemini API
# Arguments: $1-prompt $2-system $3-maxTokens $4-temperature
# Returns: Raw JSON response via stdout
_ai_call_google() {
    local prompt=$1
    local systemPrompt=$2
    local maxTokens=$3
    local temperature=$4

    local requestBody
    if [[ -n "$systemPrompt" ]]; then
        requestBody=$(jq -n \
            --argjson maxTokens "$maxTokens" \
            --argjson temperature "$temperature" \
            --arg system "$systemPrompt" \
            --arg prompt "$prompt" \
            '{
                system_instruction: { parts: [{ text: $system }] },
                contents: [
                    { parts: [{ text: $prompt }] }
                ],
                generationConfig: {
                    maxOutputTokens: $maxTokens,
                    temperature: $temperature
                }
            }')
    else
        requestBody=$(jq -n \
            --argjson maxTokens "$maxTokens" \
            --argjson temperature "$temperature" \
            --arg prompt "$prompt" \
            '{
                contents: [
                    { parts: [{ text: $prompt }] }
                ],
                generationConfig: {
                    maxOutputTokens: $maxTokens,
                    temperature: $temperature
                }
            }')
    fi

    curl -s \
        --max-time "$AI_TIMEOUT" \
        -H "Content-Type: application/json" \
        -d "$requestBody" \
        "${AI_ACTIVE_ENDPOINT}:generateContent?key=${AI_ACTIVE_KEY}"
}

# ==============================================================================
# RESPONSE PARSING (internal)
# ==============================================================================

# Extract the text content from a provider-specific response
# Arguments: $1 - Raw JSON response
# Returns: Extracted text via stdout
_ai_extract_text() {
    local response=$1

    case "$AI_PROVIDER" in
        anthropic)
            echo "$response" | jq -r '.content[0].text // empty'
            ;;
        openai)
            echo "$response" | jq -r '.choices[0].message.content // empty'
            ;;
        google)
            echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty'
            ;;
    esac
}

# ==============================================================================
# CONVENIENCE FUNCTIONS
# ==============================================================================

# Query with a system prompt for a specific role
# Globals: AI_* (via ai_query)
# Arguments:
#   $1 - Role description (system prompt)
#   $2 - User prompt
# Returns: Model response via stdout
ai_query_as() {
    local role=$1
    local prompt=$2
    ai_query "$prompt" --system "$role"
}

# Summarize the content of a file
# Globals: AI_* (via ai_query)
# Arguments:
#   $1 - File path
#   $2 - Optional additional instructions
# Returns: Summary text via stdout
ai_summarize_file() {
    local filePath=$1
    local instructions=${2:-"Provide a concise summary of the following content."}

    if [[ ! -r "$filePath" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "ai_summarize_file: Cannot read file: ${filePath}"
        fi
        return 1
    fi

    local content
    content=$(<"$filePath")
    ai_query "$instructions" --input "$content"
}

# Ask the AI to analyze and explain a code snippet or log
# Globals: AI_* (via ai_query)
# Arguments:
#   $1 - Code or log text
#   $2 - Optional question about the code/log
# Returns: Analysis text via stdout
ai_analyze() {
    local content=$1
    local question=${2:-"Analyze the following and explain what it does, any issues, and suggestions for improvement."}

    ai_query "$question" --input "$content"
}

# Generate structured output (JSON) from a prompt
# Globals: AI_* (via ai_query)
# Arguments:
#   $1 - Prompt describing desired JSON structure
#   $2 - Input data (optional)
# Returns: JSON text via stdout
ai_json() {
    local prompt=$1
    local input=${2:-""}

    local systemPrompt="You are a data extraction assistant. Respond ONLY with valid JSON, no markdown fences, no preamble, no commentary. Output raw JSON only."

    if [[ -n "$input" ]]; then
        ai_query "$prompt" --system "$systemPrompt" --input "$input"
    else
        ai_query "$prompt" --system "$systemPrompt"
    fi
}

# ==============================================================================
# DIAGNOSTICS
# ==============================================================================

# Print current AI configuration (for debugging)
# Globals: AI_*
# Arguments: None
# Returns: None (prints to stdout)
ai_status() {
    printf 'AI Integration Status:\n'
    printf '  Provider:     %s\n' "$AI_PROVIDER"
    printf '  Model:        %s\n' "$AI_ACTIVE_MODEL"
    printf '  Endpoint:     %s\n' "$AI_ACTIVE_ENDPOINT"
    printf '  API Key:      %s\n' "${AI_ACTIVE_KEY:+set (${#AI_ACTIVE_KEY} chars)}"
    printf '  Max Tokens:   %s\n' "$AI_MAX_TOKENS"
    printf '  Temperature:  %s\n' "$AI_TEMPERATURE"
    printf '  Timeout:      %ss\n' "$AI_TIMEOUT"
    printf '  Initialized:  %s\n' "$AI_INITIALIZED"
}
