# YAML Plugin - Functions
# Provides wrappers around yq (Mike Farah's Go implementation) for
# common YAML operations: reading, modifying, validating, and converting.
#
# Usage:
#   value=$(yaml_get config.yaml '.server.port')
#   yaml_set config.yaml '.server.port' '8080'
#   yaml_validate config.yaml
#   yaml_to_json config.yaml > config.json

# ==============================================================================
# READING AND QUERYING
# ==============================================================================

# Extract a value from a YAML file
# Arguments:
#   $1 - YAML file path (or "-" for stdin)
#   $2 - yq expression (e.g., '.server.port')
#   $3 - Default value if result is null (optional)
# Returns: Value via stdout
yaml_get() {
    local source=$1
    local expression=$2
    local defaultVal=${3:-""}

    local result
    if [[ "$source" == "-" ]]; then
        result=$(yq "$expression" 2>/dev/null)
    else
        result=$(yq "$expression" "$source" 2>/dev/null)
    fi

    if [[ -z "$result" ]] || [[ "$result" == "null" ]]; then
        echo "$defaultVal"
    else
        echo "$result"
    fi
}

# Extract a value from a YAML string (not a file)
# Arguments:
#   $1 - YAML string
#   $2 - yq expression
# Returns: Value via stdout
yaml_get_string() {
    local yamlInput=$1
    local expression=$2
    echo "$yamlInput" | yq "$expression" 2>/dev/null
}

# Get all values matching an expression as newline-separated list
# Arguments:
#   $1 - YAML file path
#   $2 - yq expression (should target an array or use [])
# Returns: One value per line via stdout
yaml_get_all() {
    local source=$1
    local expression=$2
    yq "${expression}[]?" "$source" 2>/dev/null
}

# Get all keys at a given path
# Arguments:
#   $1 - YAML file path
#   $2 - yq path (optional, default: root)
# Returns: One key per line via stdout
yaml_keys() {
    local source=$1
    local path=${2:-.}
    yq "${path} | keys | .[]" "$source" 2>/dev/null
}

# Get the type of a value at a path
# Arguments:
#   $1 - YAML file path
#   $2 - yq path
# Returns: Type string (!!map, !!seq, !!str, !!int, !!float, !!bool, !!null)
yaml_type() {
    local source=$1
    local path=${2:-.}
    yq "${path} | tag" "$source" 2>/dev/null
}

# Count elements in a sequence or keys in a map
# Arguments:
#   $1 - YAML file path
#   $2 - yq path (optional, default: root)
# Returns: Count via stdout
yaml_count() {
    local source=$1
    local path=${2:-.}
    yq "${path} | length" "$source" 2>/dev/null
}

# Check if a key exists at a path
# Arguments:
#   $1 - YAML file path
#   $2 - yq path to check
# Returns: 0 if exists, 1 if not
yaml_has() {
    local source=$1
    local path=$2
    local result
    result=$(yq "${path}" "$source" 2>/dev/null)
    [[ -n "$result" ]] && [[ "$result" != "null" ]]
}

# ==============================================================================
# MODIFICATION
# ==============================================================================

# Set a value in a YAML file (in-place)
# Arguments:
#   $1 - YAML file path
#   $2 - yq path
#   $3 - New value
# Returns: 0 on success
yaml_set() {
    local source=$1
    local path=$2
    local value=$3
    yq -i "${path} = ${value}" "$source" 2>/dev/null
}

# Set a string value (properly quoted)
# Arguments:
#   $1 - YAML file path
#   $2 - yq path
#   $3 - String value
# Returns: 0 on success
yaml_set_string() {
    local source=$1
    local path=$2
    local value=$3
    yq -i "${path} = \"${value}\"" "$source" 2>/dev/null
}

# Delete a key from a YAML file (in-place)
# Arguments:
#   $1 - YAML file path
#   $2 - yq path to delete
# Returns: 0 on success
yaml_delete() {
    local source=$1
    local path=$2
    yq -i "del(${path})" "$source" 2>/dev/null
}

# Append a value to a sequence in a YAML file (in-place)
# Arguments:
#   $1 - YAML file path
#   $2 - yq path to sequence
#   $3 - Value to append
# Returns: 0 on success
yaml_append() {
    local source=$1
    local path=$2
    local value=$3
    yq -i "${path} += [${value}]" "$source" 2>/dev/null
}

# Merge two YAML files (second overwrites first on conflict)
# Arguments:
#   $1 - Base YAML file
#   $2 - Override YAML file
# Returns: Merged YAML via stdout
yaml_merge() {
    local base=$1
    local override=$2
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
        "$base" "$override" 2>/dev/null
}

# ==============================================================================
# VALIDATION
# ==============================================================================

# Validate that a file contains valid YAML
# Arguments:
#   $1 - File path or "-" for stdin
# Returns: 0 if valid, 1 if invalid
yaml_validate() {
    local source=$1
    if [[ "$source" == "-" ]]; then
        yq 'true' >/dev/null 2>&1
    else
        yq 'true' "$source" >/dev/null 2>&1
    fi
}

# Validate YAML and report errors
# Arguments:
#   $1 - File path
# Returns: 0 if valid, 1 if invalid (error to stderr)
yaml_validate_verbose() {
    local source=$1
    local result
    result=$(yq '.' "$source" 2>&1)
    local exitCode=$?

    if [[ $exitCode -ne 0 ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "yaml: Invalid YAML in ${source}: ${result}"
        else
            echo "Invalid YAML: ${result}" >&2
        fi
        return 1
    fi
    return 0
}

# ==============================================================================
# CONVERSION
# ==============================================================================

# Convert YAML to JSON
# Arguments:
#   $1 - YAML file path (or "-" for stdin)
# Returns: JSON via stdout
yaml_to_json() {
    local source=$1
    if [[ "$source" == "-" ]]; then
        yq -o=json '.' 2>/dev/null
    else
        yq -o=json '.' "$source" 2>/dev/null
    fi
}

# Convert JSON to YAML
# Arguments:
#   $1 - JSON file path (or "-" for stdin)
# Returns: YAML via stdout
yaml_from_json() {
    local source=$1
    if [[ "$source" == "-" ]]; then
        yq -p=json '.' 2>/dev/null
    else
        yq -p=json '.' "$source" 2>/dev/null
    fi
}

# Pretty-print a YAML file
# Arguments:
#   $1 - YAML file path
# Returns: Formatted YAML via stdout
yaml_pretty() {
    local source=$1
    yq '.' "$source" 2>/dev/null
}

# ==============================================================================
# FILE OPERATIONS
# ==============================================================================

# Read a YAML file and apply an expression
# Arguments:
#   $1 - YAML file path
#   $2 - yq expression (optional, default: ".")
# Returns: Result via stdout
yaml_read_file() {
    local filePath=$1
    local expression=${2:-.}

    if [[ ! -r "$filePath" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "yaml_read_file: Cannot read file: ${filePath}"
        fi
        return 1
    fi

    yq "$expression" "$filePath" 2>/dev/null
}

# Create a new YAML file from key-value pairs
# Arguments:
#   $1 - Output file path
#   $2...$N - "key=value" pairs
# Returns: 0 on success
yaml_create_file() {
    local filePath=$1
    shift

    # Start with empty document
    echo "---" > "$filePath"

    for pair in "$@"; do
        local key="${pair%%=*}"
        local value="${pair#*=}"
        yq -i ".${key} = \"${value}\"" "$filePath" 2>/dev/null
    done
}
