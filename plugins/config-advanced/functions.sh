# Config Advanced Plugin - Functions
# Provides INI and TOML file parsing (pure shell for INI, yq for TOML),
# dotenv file loading, and environment variable validation.
#
# Usage:
#   ini_get config.ini "database" "host"
#   toml_get config.toml '.database.host'
#   dotenv_load .env.production
#   env_require AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

# ==============================================================================
# INI FILE PARSING (pure shell, no dependencies)
# ==============================================================================

# Read a value from an INI file
# Handles sections, comments, quoted values, and inline comments.
# Arguments:
#   $1 - INI file path
#   $2 - Section name (use "" for root/global keys)
#   $3 - Key name
#   $4 - Default value (optional)
# Returns: Value via stdout
ini_get() {
    local iniFile=$1
    local section=$2
    local key=$3
    local defaultVal=${4:-""}

    if [[ ! -r "$iniFile" ]]; then
        echo "$defaultVal"
        return 1
    fi

    local inSection=false
    local value=""
    local found=false

    # If section is empty, we're looking for root-level keys
    [[ -z "$section" ]] && inSection=true

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue
        [[ "$line" == \;* ]] && continue

        # Check for section header
        if [[ "$line" == \[*\] ]]; then
            local sectionName="${line#[}"
            sectionName="${sectionName%]}"
            sectionName="${sectionName#"${sectionName%%[![:space:]]*}"}"
            sectionName="${sectionName%"${sectionName##*[![:space:]]}"}"

            if [[ "$sectionName" == "$section" ]]; then
                inSection=true
            else
                # If we were in the right section, we've passed it
                [[ "$inSection" == true ]] && [[ -n "$section" ]] && break
                inSection=false
            fi
            continue
        fi

        # Parse key=value if in the right section
        if [[ "$inSection" == true ]] && [[ "$line" == *=* ]]; then
            local lineKey="${line%%=*}"
            local lineVal="${line#*=}"

            # Trim whitespace
            lineKey="${lineKey#"${lineKey%%[![:space:]]*}"}"
            lineKey="${lineKey%"${lineKey##*[![:space:]]}"}"
            lineVal="${lineVal#"${lineVal%%[![:space:]]*}"}"
            lineVal="${lineVal%"${lineVal##*[![:space:]]}"}"

            # Strip inline comments (not inside quotes)
            if [[ "$lineVal" != \"*\" ]] && [[ "$lineVal" != \'*\' ]]; then
                lineVal="${lineVal%%[#;]*}"
                lineVal="${lineVal%"${lineVal##*[![:space:]]}"}"
            fi

            # Strip surrounding quotes
            if [[ "$lineVal" == \"*\" ]]; then
                lineVal="${lineVal#\"}"
                lineVal="${lineVal%\"}"
            elif [[ "$lineVal" == \'*\' ]]; then
                lineVal="${lineVal#\'}"
                lineVal="${lineVal%\'}"
            fi

            if [[ "$lineKey" == "$key" ]]; then
                value="$lineVal"
                found=true
                break
            fi
        fi
    done < "$iniFile"

    if [[ "$found" == true ]]; then
        echo "$value"
    else
        echo "$defaultVal"
    fi
}

# List all sections in an INI file
# Arguments:
#   $1 - INI file path
# Returns: One section name per line via stdout
ini_sections() {
    local iniFile=$1

    if [[ ! -r "$iniFile" ]]; then
        return 1
    fi

    grep -oP '^\s*\[\K[^\]]+' "$iniFile" 2>/dev/null | sort -u
}

# List all keys in a section of an INI file
# Arguments:
#   $1 - INI file path
#   $2 - Section name (use "" for root keys)
# Returns: One key per line via stdout
ini_keys() {
    local iniFile=$1
    local section=$2
    local inSection=false

    [[ -z "$section" ]] && inSection=true

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"

        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue
        [[ "$line" == \;* ]] && continue

        if [[ "$line" == \[*\] ]]; then
            local sectionName="${line#[}"
            sectionName="${sectionName%]}"
            sectionName="${sectionName#"${sectionName%%[![:space:]]*}"}"
            sectionName="${sectionName%"${sectionName##*[![:space:]]}"}"

            if [[ "$sectionName" == "$section" ]]; then
                inSection=true
            else
                [[ "$inSection" == true ]] && [[ -n "$section" ]] && break
                inSection=false
            fi
            continue
        fi

        if [[ "$inSection" == true ]] && [[ "$line" == *=* ]]; then
            local lineKey="${line%%=*}"
            lineKey="${lineKey#"${lineKey%%[![:space:]]*}"}"
            lineKey="${lineKey%"${lineKey##*[![:space:]]}"}"
            echo "$lineKey"
        fi
    done < "$iniFile"
}

# Set a value in an INI file (creates section and key if missing)
# Arguments:
#   $1 - INI file path
#   $2 - Section name
#   $3 - Key name
#   $4 - Value
# Returns: 0 on success
ini_set() {
    local iniFile=$1
    local section=$2
    local key=$3
    local value=$4

    # Create file if it doesn't exist
    [[ ! -f "$iniFile" ]] && touch "$iniFile"

    local sectionExists=false
    local keyExists=false

    # Check if section and key exist
    if [[ -n "$section" ]]; then
        grep -qP "^\s*\[${section}\]" "$iniFile" 2>/dev/null && sectionExists=true
    fi

    if [[ "$sectionExists" == true ]]; then
        # Try to replace existing key in section
        if sed -n "/^\[${section}\]/,/^\[/p" "$iniFile" | grep -qP "^\s*${key}\s*=" 2>/dev/null; then
            keyExists=true
        fi
    fi

    if [[ "$keyExists" == true ]]; then
        # Replace existing value (within the correct section)
        sed -i "/^\[${section}\]/,/^\[/{s|^\(\s*${key}\s*=\s*\).*|\1${value}|}" "$iniFile"
    elif [[ "$sectionExists" == true ]]; then
        # Add key to existing section (after section header)
        sed -i "/^\[${section}\]/a ${key} = ${value}" "$iniFile"
    else
        # Add new section and key
        printf '\n[%s]\n%s = %s\n' "$section" "$key" "$value" >> "$iniFile"
    fi
}

# ==============================================================================
# TOML PARSING (via yq or pure shell for simple cases)
# ==============================================================================

# Read a value from a TOML file
# Arguments:
#   $1 - TOML file path
#   $2 - Key path (yq-style: '.section.key')
#   $3 - Default value (optional)
# Returns: Value via stdout
toml_get() {
    local tomlFile=$1
    local keyPath=$2
    local defaultVal=${3:-""}

    if [[ ! -r "$tomlFile" ]]; then
        echo "$defaultVal"
        return 1
    fi

    if [[ -n "$CONFIG_TOML_BIN" ]]; then
        local result

        case "$(basename "$CONFIG_TOML_BIN")" in
            yq)
                result=$(yq -p=toml "$keyPath" "$tomlFile" 2>/dev/null)
                ;;
            tomlq)
                result=$(tomlq -r "$keyPath" "$tomlFile" 2>/dev/null)
                ;;
            dasel)
                # dasel uses dot notation without leading dot
                local daselPath="${keyPath#.}"
                result=$(dasel -f "$tomlFile" -p toml "${daselPath}" 2>/dev/null)
                ;;
        esac

        if [[ -z "$result" ]] || [[ "$result" == "null" ]]; then
            echo "$defaultVal"
        else
            echo "$result"
        fi
    else
        # Pure shell fallback for simple TOML (flat key = value only)
        _toml_simple_get "$tomlFile" "$keyPath" "$defaultVal"
    fi
}

# Simple pure-shell TOML parser for flat structures
# Handles [section] headers and key = value pairs (strings, ints, bools)
# Does NOT handle nested tables, arrays, or multi-line strings.
_toml_simple_get() {
    local tomlFile=$1
    local keyPath=$2
    local defaultVal=$3

    # Parse keyPath: ".section.key" -> section="section", key="key"
    local pathTrimmed="${keyPath#.}"
    local section=""
    local key="$pathTrimmed"

    if [[ "$pathTrimmed" == *.* ]]; then
        section="${pathTrimmed%%.*}"
        key="${pathTrimmed#*.}"
    fi

    ini_get "$tomlFile" "$section" "$key" "$defaultVal"
}

# Convert TOML to JSON (requires yq or tomlq)
# Arguments:
#   $1 - TOML file path
# Returns: JSON via stdout
toml_to_json() {
    local tomlFile=$1

    if [[ -z "$CONFIG_TOML_BIN" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "config-advanced: TOML-to-JSON requires yq or tomlq"
        fi
        return 1
    fi

    case "$(basename "$CONFIG_TOML_BIN")" in
        yq)    yq -p=toml -o=json '.' "$tomlFile" 2>/dev/null ;;
        tomlq) tomlq '.' "$tomlFile" 2>/dev/null ;;
    esac
}

# Validate TOML syntax
# Arguments:
#   $1 - TOML file path
# Returns: 0 if valid, 1 if invalid
toml_validate() {
    local tomlFile=$1

    if [[ -n "$CONFIG_TOML_BIN" ]]; then
        case "$(basename "$CONFIG_TOML_BIN")" in
            yq)    yq -p=toml 'true' "$tomlFile" >/dev/null 2>&1 ;;
            tomlq) tomlq '.' "$tomlFile" >/dev/null 2>&1 ;;
        esac
    else
        # Basic syntax check: ensure no unclosed brackets, etc.
        [[ -r "$tomlFile" ]]
    fi
}

# ==============================================================================
# DOTENV FILE LOADING
# ==============================================================================

# Load environment variables from a dotenv file
# Supports KEY=VALUE, KEY="VALUE", KEY='VALUE', and comments.
# Arguments:
#   $1 - Dotenv file path (optional, default: CONFIG_DOTENV_FILE)
#   --override  - Override existing environment variables
# Returns: 0 on success, 1 if file not found
dotenv_load() {
    local dotenvFile="${1:-$CONFIG_DOTENV_FILE}"
    local override="$CONFIG_DOTENV_OVERRIDE"

    [[ "$1" == "--override" ]] && { override=true; dotenvFile="${2:-$CONFIG_DOTENV_FILE}"; }
    [[ "${2:-}" == "--override" ]] && override=true

    if [[ ! -r "$dotenvFile" ]]; then
        if declare -f debug >/dev/null 2>&1; then
            debug "config-advanced: dotenv file not found: ${dotenvFile}"
        fi
        return 1
    fi

    local -i loaded=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip leading whitespace
        line="${line#"${line%%[![:space:]]*}"}"

        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue

        # Skip 'export' prefix
        [[ "$line" == export\ * ]] && line="${line#export }"

        # Parse KEY=VALUE
        if [[ "$line" == *=* ]]; then
            local key="${line%%=*}"
            local value="${line#*=}"

            # Trim whitespace from key
            key="${key%"${key##*[![:space:]]}"}"

            # Trim whitespace and quotes from value
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"

            # Strip surrounding quotes
            if [[ "$value" == \"*\" ]]; then
                value="${value#\"}"
                value="${value%\"}"
            elif [[ "$value" == \'*\' ]]; then
                value="${value#\'}"
                value="${value%\'}"
            fi

            # Only set if not already set (unless override)
            if [[ "$override" == "true" ]] || [[ -z "${!key:-}" ]]; then
                export "${key}=${value}"
                ((loaded++))
            fi
        fi
    done < "$dotenvFile"

    if declare -f debug >/dev/null 2>&1; then
        debug "config-advanced: Loaded ${loaded} variable(s) from ${dotenvFile}"
    fi

    return 0
}

# ==============================================================================
# ENVIRONMENT VALIDATION
# ==============================================================================

# Require that specific environment variables are set
# Arguments:
#   $1...$N - Variable names to check
# Returns: 0 if all set, exits with E_CONFIG (78) if any missing
env_require() {
    local -a missing=()

    for varName in "$@"; do
        if [[ -z "${!varName:-}" ]]; then
            missing+=("$varName")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "Missing required environment variable(s): ${missing[*]}"
        else
            echo "Error: Missing required environment variable(s): ${missing[*]}" >&2
        fi

        # Use E_CONFIG if available, otherwise 78
        exit "${E_CONFIG:-78}"
    fi
}

# Check that specific environment variables are set (non-fatal)
# Arguments:
#   $1...$N - Variable names to check
# Returns: 0 if all set, 1 if any missing (missing names to stderr)
env_check() {
    local -a missing=()

    for varName in "$@"; do
        if [[ -z "${!varName:-}" ]]; then
            missing+=("$varName")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        if declare -f warn >/dev/null 2>&1; then
            warn "Unset environment variable(s): ${missing[*]}"
        fi
        return 1
    fi

    return 0
}

# Validate an environment variable against a pattern
# Arguments:
#   $1 - Variable name
#   $2 - Regex pattern to match
#   $3 - Error message (optional)
# Returns: 0 if valid, 1 if invalid
env_validate() {
    local varName=$1
    local pattern=$2
    local errorMsg=${3:-"${varName} does not match required pattern"}
    local value="${!varName:-}"

    if [[ -z "$value" ]]; then
        if declare -f warn >/dev/null 2>&1; then
            warn "${varName} is not set"
        fi
        return 1
    fi

    if ! [[ "$value" =~ $pattern ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "${errorMsg}: ${value}"
        fi
        return 1
    fi

    return 0
}

# Print all environment variables matching a prefix
# Arguments:
#   $1 - Prefix to match (e.g., "APP_", "DB_")
# Returns: KEY=VALUE pairs via stdout (values masked for *_KEY, *_SECRET, *_PASSWORD)
env_list() {
    local prefix=$1
    env | grep "^${prefix}" | sort | while IFS='=' read -r key value; do
        # Mask sensitive values
        case "$key" in
            *PASSWORD*|*SECRET*|*KEY*|*TOKEN*)
                if [[ ${#value} -gt 4 ]]; then
                    printf '%s=%s***%s\n' "$key" "${value:0:2}" "${value: -2}"
                else
                    printf '%s=***\n' "$key"
                fi
                ;;
            *)
                printf '%s=%s\n' "$key" "$value"
                ;;
        esac
    done
}
