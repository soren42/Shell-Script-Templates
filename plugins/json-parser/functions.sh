# JSON Parser Plugin - Functions
# Provides convenient wrappers around jq for common JSON operations.
#
# Usage:
#   value=$(json_get '{"name":"Claude"}' '.name')
#   json_validate '{"valid": true}'
#   json_set '{}' '.name' '"Claude"'
#   json_pretty '{"a":1,"b":2}'

# ==============================================================================
# READING AND QUERYING
# ==============================================================================

# Extract a value from JSON using a jq expression
# Arguments:
#   $1 - JSON string (or "-" to read from stdin)
#   $2 - jq filter expression
#   $3 - Default value if query returns null/empty (optional)
# Returns: Extracted value via stdout
json_get() {
    local jsonInput=$1
    local filter=$2
    local defaultVal=${3:-""}

    local result
    if [[ "$jsonInput" == "-" ]]; then
        result=$(jq -r "$filter // empty" 2>/dev/null)
    else
        result=$(echo "$jsonInput" | jq -r "$filter // empty" 2>/dev/null)
    fi

    if [[ -z "$result" ]]; then
        echo "$defaultVal"
    else
        echo "$result"
    fi
}

# Extract a raw (unquoted) value from JSON
# Arguments:
#   $1 - JSON string
#   $2 - jq filter expression
# Returns: Raw value via stdout
json_get_raw() {
    local jsonInput=$1
    local filter=$2
    echo "$jsonInput" | jq "$filter" 2>/dev/null
}

# Extract all values matching a filter as newline-separated list
# Arguments:
#   $1 - JSON string
#   $2 - jq filter expression
# Returns: One value per line via stdout
json_get_all() {
    local jsonInput=$1
    local filter=$2
    echo "$jsonInput" | jq -r "$filter[]?" 2>/dev/null
}

# Get the type of a JSON value
# Arguments:
#   $1 - JSON string
#   $2 - jq path (optional, default: ".")
# Returns: Type name (object, array, string, number, boolean, null) via stdout
json_type() {
    local jsonInput=$1
    local path=${2:-.}
    echo "$jsonInput" | jq -r "${path} | type" 2>/dev/null
}

# Count elements in a JSON array or keys in an object
# Arguments:
#   $1 - JSON string
#   $2 - jq path to array/object (optional, default: ".")
# Returns: Count via stdout
json_count() {
    local jsonInput=$1
    local path=${2:-.}
    echo "$jsonInput" | jq "${path} | length" 2>/dev/null
}

# Get all keys from a JSON object
# Arguments:
#   $1 - JSON string
#   $2 - jq path to object (optional, default: ".")
# Returns: One key per line via stdout
json_keys() {
    local jsonInput=$1
    local path=${2:-.}
    echo "$jsonInput" | jq -r "${path} | keys[]" 2>/dev/null
}

# Check if a key exists in a JSON object
# Arguments:
#   $1 - JSON string
#   $2 - Key path (e.g., ".name", ".data.items")
# Returns: 0 if exists, 1 if not
json_has() {
    local jsonInput=$1
    local keyPath=$2
    echo "$jsonInput" | jq -e "${keyPath} // empty" >/dev/null 2>&1
}

# ==============================================================================
# MODIFICATION
# ==============================================================================

# Set a value in a JSON object
# Arguments:
#   $1 - JSON string
#   $2 - jq path (e.g., ".name")
#   $3 - New value (must be valid JSON: '"string"', '42', 'true', etc.)
# Returns: Modified JSON via stdout
json_set() {
    local jsonInput=$1
    local path=$2
    local value=$3
    echo "$jsonInput" | jq "${path} = ${value}" 2>/dev/null
}

# Set a string value (automatically quotes)
# Arguments:
#   $1 - JSON string
#   $2 - jq path
#   $3 - String value (unquoted)
# Returns: Modified JSON via stdout
json_set_string() {
    local jsonInput=$1
    local path=$2
    local value=$3
    echo "$jsonInput" | jq --arg v "$value" "${path} = \$v" 2>/dev/null
}

# Delete a key from a JSON object
# Arguments:
#   $1 - JSON string
#   $2 - jq path to delete
# Returns: Modified JSON via stdout
json_delete() {
    local jsonInput=$1
    local path=$2
    echo "$jsonInput" | jq "del(${path})" 2>/dev/null
}

# Merge two JSON objects (second overwrites first on conflict)
# Arguments:
#   $1 - Base JSON object
#   $2 - Override JSON object
# Returns: Merged JSON via stdout
json_merge() {
    local base=$1
    local override=$2
    echo "$base" | jq --argjson o "$override" '. * $o' 2>/dev/null
}

# Append a value to a JSON array
# Arguments:
#   $1 - JSON string containing an array
#   $2 - Value to append (valid JSON)
#   $3 - jq path to array (optional, default: ".")
# Returns: Modified JSON via stdout
json_append() {
    local jsonInput=$1
    local value=$2
    local path=${3:-.}
    echo "$jsonInput" | jq "${path} += [${value}]" 2>/dev/null
}

# ==============================================================================
# VALIDATION
# ==============================================================================

# Validate that a string is valid JSON
# Arguments:
#   $1 - String to validate
# Returns: 0 if valid JSON, 1 if invalid
json_validate() {
    local input=$1
    echo "$input" | jq empty 2>/dev/null
}

# Validate JSON and report errors
# Arguments:
#   $1 - String to validate
# Returns: 0 if valid, 1 if invalid (error message to stderr)
json_validate_verbose() {
    local input=$1
    local result
    result=$(echo "$input" | jq empty 2>&1)
    local exitCode=$?

    if [[ $exitCode -ne 0 ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "json-parser: Invalid JSON: ${result}"
        else
            echo "Invalid JSON: ${result}" >&2
        fi
        return 1
    fi
    return 0
}

# ==============================================================================
# FORMATTING
# ==============================================================================

# Pretty-print JSON with indentation
# Arguments:
#   $1 - JSON string (or "-" for stdin)
#   $2 - Indent width (optional, default: 2)
# Returns: Formatted JSON via stdout
json_pretty() {
    local jsonInput=$1
    local indent=${2:-2}

    if [[ "$jsonInput" == "-" ]]; then
        jq --indent "$indent" '.' 2>/dev/null
    else
        echo "$jsonInput" | jq --indent "$indent" '.' 2>/dev/null
    fi
}

# Compact JSON (remove whitespace)
# Arguments:
#   $1 - JSON string
# Returns: Compacted JSON via stdout
json_compact() {
    local jsonInput=$1
    echo "$jsonInput" | jq -c '.' 2>/dev/null
}

# Sort JSON object keys
# Arguments:
#   $1 - JSON string
# Returns: Sorted JSON via stdout
json_sort_keys() {
    local jsonInput=$1
    echo "$jsonInput" | jq -S '.' 2>/dev/null
}

# ==============================================================================
# GENERATION
# ==============================================================================

# Create a new JSON object from key-value pairs
# Arguments: key1 value1 key2 value2 ...
# Returns: JSON object via stdout
json_object() {
    local result="{}"
    while [[ $# -ge 2 ]]; do
        local key=$1
        local value=$2
        shift 2
        result=$(echo "$result" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
    done
    echo "$result"
}

# Create a JSON array from arguments
# Arguments: item1 item2 item3 ...
# Returns: JSON array via stdout
json_array() {
    printf '%s\n' "$@" | jq -R '.' | jq -s '.'
}

# ==============================================================================
# FILE OPERATIONS
# ==============================================================================

# Read and parse a JSON file
# Arguments:
#   $1 - File path
#   $2 - jq filter (optional, default: ".")
# Returns: Parsed content via stdout
json_read_file() {
    local filePath=$1
    local filter=${2:-.}

    if [[ ! -r "$filePath" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "json_read_file: Cannot read file: ${filePath}"
        fi
        return 1
    fi

    jq "$filter" "$filePath" 2>/dev/null
}

# Write JSON to a file (pretty-printed)
# Arguments:
#   $1 - JSON string
#   $2 - Output file path
# Returns: 0 on success, 1 on failure
json_write_file() {
    local jsonInput=$1
    local filePath=$2

    if ! json_validate "$jsonInput"; then
        if declare -f error >/dev/null 2>&1; then
            error "json_write_file: Invalid JSON, not writing"
        fi
        return 1
    fi

    echo "$jsonInput" | jq '.' > "$filePath" 2>/dev/null
}
