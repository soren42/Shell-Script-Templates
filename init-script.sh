#!/usr/bin/env bash
# init-script.sh(1)
#
# Description:
#   Interactive wizard for generating new shell scripts from the
#   Shell Script Templates v4 framework. Supports creating new scripts
#   from scratch or porting existing v1-v3 scripts to v4 format.
#
# Usage:
#   init-script.sh [OPTIONS]
#   init-script.sh --port <existing-script>
#
# Author:
#   jason c. kay
#
# Copyright:
#   Copyright (c) 2026 jason c. kay
#
# License:
#   CC BY-SA 4.0 - https://creativecommons.org/licenses/by-sa/4.0/

set -o errexit
set -o nounset
set -o pipefail

# ==============================================================================
# CONSTANTS
# ==============================================================================
readonly INIT_VERSION="4.1.0"
readonly INIT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMPLATE_DIR="${INIT_SCRIPT_DIR}/templates"
readonly PLUGIN_DIR="${INIT_SCRIPT_DIR}/plugins"

# Default values for metadata
readonly DEFAULT_VERSION="1.0.0"
readonly DEFAULT_LICENSE="CC BY-SA 4.0"
readonly DEFAULT_LICENSE_URL="https://creativecommons.org/licenses/by-sa/4.0/"

# Known dependency relationships (child -> parent)
# If a user lists a dependency, we check if its parent is also needed
declare -A DEPENDENCY_MAP=(
    [ld]="gcc"
    [as]="binutils"
    [ar]="binutils"
    [nm]="binutils"
    [objdump]="binutils"
    [objcopy]="binutils"
    [make]="build-essential"
    [cmake]="cmake"
    [g++]="gcc"
    [c++]="gcc"
    [pip]="python3"
    [pip3]="python3"
    [pydoc]="python3"
    [node]="nodejs"
    [npm]="nodejs"
    [npx]="nodejs"
    [gem]="ruby"
    [irb]="ruby"
    [bundle]="ruby"
    [cargo]="rust"
    [rustc]="rust"
    [javac]="java"
    [jar]="java"
    [go]="golang"
    [gofmt]="golang"
    [docker-compose]="docker"
    [psql]="postgresql-client"
    [mysql]="mysql-client"
    [sqlite3]="sqlite3"
    [convert]="imagemagick"
    [identify]="imagemagick"
    [mogrify]="imagemagick"
    [ffprobe]="ffmpeg"
    [ffplay]="ffmpeg"
    [openssl]="openssl"
    [ssh-keygen]="openssh-client"
    [scp]="openssh-client"
    [sftp]="openssh-client"
)

# Valid argument types for generated validation
readonly -a VALID_ARG_TYPES=(
    "string"
    "integer"
    "float"
    "file_readable"
    "file_writable"
    "dir_readable"
    "dir_writable"
    "executable"
    "pipe"
    "email"
    "url"
    "ipv4"
    "hostname"
    "path"
)

# Available licenses
readonly -a AVAILABLE_LICENSES=(
    "CC BY-SA 4.0"
    "MIT"
    "Apache 2.0"
    "GPL 3.0"
    "BSD 2-Clause"
    "BSD 3-Clause"
    "ISC"
    "Unlicense"
    "Proprietary"
)

# ==============================================================================
# TERMINAL COLORS AND FORMATTING
# ==============================================================================
declare -A C=()

init_colors() {
    if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
        C[reset]='\033[0m'
        C[bold]='\033[1m'
        C[dim]='\033[2m'
        C[red]='\033[31m'
        C[green]='\033[32m'
        C[yellow]='\033[33m'
        C[blue]='\033[34m'
        C[magenta]='\033[35m'
        C[cyan]='\033[36m'
        C[white]='\033[37m'
    fi
}

# ==============================================================================
# OUTPUT HELPERS
# ==============================================================================

# Print a styled section header
# Arguments: $1 - Section title
print_header() {
    local title=$1
    printf '\n%b══════════════════════════════════════════════════════════════%b\n' \
        "${C[cyan]:-}" "${C[reset]:-}"
    printf '%b  %s%b\n' "${C[bold]:-}${C[cyan]:-}" "$title" "${C[reset]:-}"
    printf '%b══════════════════════════════════════════════════════════════%b\n\n' \
        "${C[cyan]:-}" "${C[reset]:-}"
}

# Print an informational message
# Arguments: $1 - Message
print_info() {
    printf '%b→%b %s\n' "${C[blue]:-}" "${C[reset]:-}" "$1"
}

# Print a success message
# Arguments: $1 - Message
print_success() {
    printf '%b✓%b %s\n' "${C[green]:-}" "${C[reset]:-}" "$1"
}

# Print a warning message
# Arguments: $1 - Message
print_warn() {
    printf '%b!%b %s\n' "${C[yellow]:-}" "${C[reset]:-}" "$1"
}

# Print an error message
# Arguments: $1 - Message
print_error() {
    printf '%b✗%b %s\n' "${C[red]:-}" "${C[reset]:-}" "$1" >&2
}

# ==============================================================================
# INPUT HELPERS
# ==============================================================================

# Prompt user for a text value with default
# Arguments:
#   $1 - Prompt text
#   $2 - Default value (optional)
# Returns: User input via stdout
prompt_text() {
    local promptText=$1
    local defaultValue=${2:-}
    local userInput

    if [[ -n "$defaultValue" ]]; then
        printf '%b?%b %s [%b%s%b]: ' \
            "${C[green]:-}" "${C[reset]:-}" "$promptText" \
            "${C[dim]:-}" "$defaultValue" "${C[reset]:-}"
    else
        printf '%b?%b %s: ' "${C[green]:-}" "${C[reset]:-}" "$promptText"
    fi

    read -r userInput
    echo "${userInput:-$defaultValue}"
}

# Prompt user for yes/no/default with assumed default
# Arguments:
#   $1 - Prompt text
#   $2 - Default value (true/false)
# Returns: "true" or "false" via stdout
prompt_flag() {
    local promptText=$1
    local defaultValue=$2
    local defaultHint="d"
    local userInput

    if [[ "$defaultValue" == "true" ]]; then
        defaultHint="Y/n/d"
    else
        defaultHint="y/N/d"
    fi

    printf '%b?%b %s [%s]: ' "${C[green]:-}" "${C[reset]:-}" "$promptText" "$defaultHint"
    read -r userInput

    case "${userInput,,}" in
        y|yes)  echo "true"  ;;
        n|no)   echo "false" ;;
        d|"")   echo "$defaultValue" ;;
        *)      echo "$defaultValue" ;;
    esac
}

# Prompt user to select from a numbered list
# Arguments:
#   $1 - Prompt text
#   $2...$N - Options
# Returns: Selected option via stdout
prompt_select() {
    local promptText=$1
    shift
    local -a options=("$@")
    local -i i=1
    local userInput

    printf '%b?%b %s\n' "${C[green]:-}" "${C[reset]:-}" "$promptText"
    for opt in "${options[@]}"; do
        printf '  %b%d%b) %s\n' "${C[cyan]:-}" "$i" "${C[reset]:-}" "$opt"
        ((i++))
    done

    printf '  Selection: '
    read -r userInput

    # Validate input
    if [[ "$userInput" =~ ^[0-9]+$ ]] && ((userInput >= 1 && userInput <= ${#options[@]})); then
        echo "${options[$((userInput - 1))]}"
    else
        echo "${options[0]}"
    fi
}

# Prompt for multi-line input (dependencies, etc.)
# Arguments:
#   $1 - Prompt text
#   $2 - End marker instruction
# Returns: Space-separated values via stdout
prompt_list() {
    local promptText=$1
    local endHint=${2:-"Enter empty line when done"}
    local -a items=()
    local userInput

    printf '%b?%b %s (%s)\n' "${C[green]:-}" "${C[reset]:-}" "$promptText" "$endHint"

    while true; do
        printf '  %b+%b ' "${C[dim]:-}" "${C[reset]:-}"
        read -r userInput
        if [[ -z "$userInput" ]]; then
            break
        fi
        items+=("$userInput")
    done

    echo "${items[*]}"
}

# ==============================================================================
# DEPENDENCY DETECTION
# ==============================================================================

# Check if a binary exists on the system
# Arguments: $1 - Binary name
# Returns: 0 if found, 1 if not
check_binary() {
    command -v "$1" >/dev/null 2>&1
}

# Find the full path of a binary
# Arguments: $1 - Binary name
# Returns: Full path via stdout, empty if not found
find_binary_path() {
    command -v "$1" 2>/dev/null || echo ""
}

# Detect sub-dependencies for a given binary
# Arguments: $1 - Binary name
# Returns: Space-separated list of implied dependencies via stdout
detect_sub_dependencies() {
    local binary=$1
    local -a subDeps=()

    # Check our known dependency map
    if [[ -n "${DEPENDENCY_MAP[$binary]:-}" ]]; then
        local parent="${DEPENDENCY_MAP[$binary]}"
        subDeps+=("$parent")
    fi

    echo "${subDeps[*]}"
}

# Validate a list of dependencies and detect sub-dependencies
# Arguments: $1 - Space-separated list of binary names
# Returns: Prints analysis to stdout
analyze_dependencies() {
    local -a binaries=($1)
    local -a verified=()
    local -a missing=()
    local -a subDepsFound=()

    for binary in "${binaries[@]}"; do
        local binPath
        binPath=$(find_binary_path "$binary")

        if [[ -n "$binPath" ]]; then
            verified+=("${binary}:${binPath}")
            print_success "Found: ${binary} -> ${binPath}"
        else
            missing+=("$binary")
            print_warn "Not found: ${binary} (will be checked at runtime)"
        fi

        # Check for sub-dependencies
        local subDeps
        subDeps=$(detect_sub_dependencies "$binary")
        if [[ -n "$subDeps" ]]; then
            for subDep in $subDeps; do
                # Avoid duplicates
                local alreadyListed=false
                for existing in "${binaries[@]}" "${subDepsFound[@]}"; do
                    if [[ "$existing" == "$subDep" ]]; then
                        alreadyListed=true
                        break
                    fi
                done

                if [[ "$alreadyListed" == false ]]; then
                    subDepsFound+=("$subDep")
                    print_info "Implied dependency: ${binary} requires ${subDep}"
                fi
            done
        fi
    done

    # Return structured data via global variables
    ANALYZED_VERIFIED=("${verified[@]}")
    ANALYZED_MISSING=("${missing[@]}")
    ANALYZED_SUB_DEPS=("${subDepsFound[@]}")
}

# ==============================================================================
# V1-V3 SCRIPT PORTING
# ==============================================================================

# Extract metadata from an existing script
# Arguments: $1 - Path to existing script
# Returns: Sets global PORT_* variables
extract_script_metadata() {
    local scriptPath=$1

    # Detect shell type from shebang
    local shebang
    shebang=$(head -1 "$scriptPath")
    case "$shebang" in
        *zsh*)  PORT_SHELL="zsh"  ;;
        *bash*) PORT_SHELL="bash" ;;
        *)      PORT_SHELL="bash" ;;
    esac

    # Extract version string
    PORT_VERSION=$(grep -oP 'VERSION\s*=\s*"?\K[^"]+' "$scriptPath" 2>/dev/null | head -1 || echo "")

    # Extract author
    PORT_AUTHOR=$(grep -i '^\s*#.*author' "$scriptPath" 2>/dev/null | \
        sed 's/.*[Aa]uthor[: ]*//' | head -1 || echo "")

    # Extract description
    PORT_DESCRIPTION=$(grep -i '^\s*#.*[Dd]escription' "$scriptPath" 2>/dev/null | \
        sed 's/.*[Dd]escription[: ]*//' | head -1 || echo "")

    # Extract required binaries from require_binary calls
    PORT_DEPENDENCIES=$(grep -oP 'require_binary\s+\K[^\s]+' "$scriptPath" 2>/dev/null | \
        tr '\n' ' ' || echo "")

    # Extract optional binaries
    PORT_OPT_DEPENDENCIES=$(grep -oP 'optional_binary\s+\K[^\s]+' "$scriptPath" 2>/dev/null | \
        tr '\n' ' ' || echo "")

    # Check for existing feature flags
    PORT_HAS_DRY_RUN=$(grep -qE 'DRY_RUN|dry.run' "$scriptPath" && echo "true" || echo "false")
    PORT_HAS_CONFIG=$(grep -qE 'load_config|CONFIG_FILE' "$scriptPath" && echo "true" || echo "false")

    # Check for JSON metadata block (v3+)
    if grep -q 'JSON_METADATA_START' "$scriptPath" 2>/dev/null; then
        local jsonBlock
        jsonBlock=$(sed -n '/JSON_METADATA_START/,/JSON_METADATA_END/p' "$scriptPath" | \
            grep -v 'JSON_METADATA' | sed 's/^#\s*//')

        # Try to extract fields from JSON
        PORT_JSON_NAME=$(echo "$jsonBlock" | grep -oP '"name"\s*:\s*"\K[^"]+' 2>/dev/null || echo "")
        PORT_JSON_VERSION=$(echo "$jsonBlock" | grep -oP '"version"\s*:\s*"\K[^"]+' 2>/dev/null || echo "")
    fi
}

# ==============================================================================
# CODE GENERATION FUNCTIONS
# ==============================================================================

# Generate the feature flags section for the output script
# Arguments: None (reads from global SCRIPT_* variables)
# Returns: Generated code via stdout
generate_feature_flags() {
    local shell=$1

    if [[ "$shell" == "zsh" ]]; then
        cat <<'FLAGSEOF'
# ==============================================================================
# FEATURE FLAGS - Configure script behavior
# ==============================================================================
FLAGSEOF
        printf 'typeset -gr REQUIRE_ROOT=%s\n' "$FLAG_REQUIRE_ROOT"
        printf 'typeset -gr REQUIRES_NETWORK=%s\n' "$FLAG_REQUIRES_NETWORK"
        printf 'typeset -gr REQUIRES_DISK_SPACE=%s\n' "$FLAG_REQUIRES_DISK_SPACE"
        printf 'typeset -gi DISK_SPACE_REQUIRED_MB=%s\n' "$FLAG_DISK_SPACE_MB"
        printf 'typeset -gr CAN_RUN_IN_USERSPACE=%s\n' "$FLAG_CAN_RUN_IN_USERSPACE"
        printf 'typeset -gr SUPPORTS_DRY_RUN=%s\n' "$FLAG_SUPPORTS_DRY_RUN"
        printf 'typeset -gr IDEMPOTENT=%s\n' "$FLAG_IDEMPOTENT"
        printf 'typeset -gr INTERACTIVE=%s\n' "$FLAG_INTERACTIVE"
        printf 'typeset -gr CREATES_ARTIFACTS=%s\n' "$FLAG_CREATES_ARTIFACTS"
        printf 'typeset -gr HAS_EXTERNAL_DEPENDENCIES=%s\n' "$FLAG_HAS_EXTERNAL_DEPS"
        printf 'typeset -gr USES_CONFIG_FILES=%s\n' "$FLAG_USES_CONFIG_FILES"
        printf 'typeset -gr SUPPORTS_PARALLEL=%s\n' "$FLAG_SUPPORTS_PARALLEL"
        printf 'typeset -gr VERBOSE_BY_DEFAULT=%s\n' "$FLAG_VERBOSE_BY_DEFAULT"
        printf 'typeset -gr INCLUDES_SELF_TEST=%s\n' "$FLAG_INCLUDES_SELF_TEST"
        printf 'typeset -gr COMPILABLE=%s\n' "$FLAG_COMPILABLE"
        printf 'typeset -gr ENABLED_PLUGINS="%s"\n' "$FLAG_ENABLED_PLUGINS"
        printf 'typeset -gr PLUGIN_DIR="${HOME}/.shell-script-templates/plugins"\n'
    else
        cat <<'FLAGSEOF'
# ==============================================================================
# FEATURE FLAGS - Configure script behavior
# ==============================================================================
FLAGSEOF
        printf 'readonly REQUIRE_ROOT=%s\n' "$FLAG_REQUIRE_ROOT"
        printf 'readonly REQUIRES_NETWORK=%s\n' "$FLAG_REQUIRES_NETWORK"
        printf 'readonly REQUIRES_DISK_SPACE=%s\n' "$FLAG_REQUIRES_DISK_SPACE"
        printf 'readonly DISK_SPACE_REQUIRED_MB=%s\n' "$FLAG_DISK_SPACE_MB"
        printf 'readonly CAN_RUN_IN_USERSPACE=%s\n' "$FLAG_CAN_RUN_IN_USERSPACE"
        printf 'readonly SUPPORTS_DRY_RUN=%s\n' "$FLAG_SUPPORTS_DRY_RUN"
        printf 'readonly IDEMPOTENT=%s\n' "$FLAG_IDEMPOTENT"
        printf 'readonly INTERACTIVE=%s\n' "$FLAG_INTERACTIVE"
        printf 'readonly CREATES_ARTIFACTS=%s\n' "$FLAG_CREATES_ARTIFACTS"
        printf 'readonly HAS_EXTERNAL_DEPENDENCIES=%s\n' "$FLAG_HAS_EXTERNAL_DEPS"
        printf 'readonly USES_CONFIG_FILES=%s\n' "$FLAG_USES_CONFIG_FILES"
        printf 'readonly SUPPORTS_PARALLEL=%s\n' "$FLAG_SUPPORTS_PARALLEL"
        printf 'readonly VERBOSE_BY_DEFAULT=%s\n' "$FLAG_VERBOSE_BY_DEFAULT"
        printf 'readonly INCLUDES_SELF_TEST=%s\n' "$FLAG_INCLUDES_SELF_TEST"
        printf 'readonly ENABLED_PLUGINS="%s"\n' "$FLAG_ENABLED_PLUGINS"
        printf 'readonly PLUGIN_DIR="${HOME}/.shell-script-templates/plugins"\n'
    fi
}

# Generate the dependency validation section
# Arguments:
#   $1 - shell type (bash/zsh)
#   $2 - space-separated required binaries
#   $3 - space-separated optional binaries
# Returns: Generated code via stdout
generate_dependency_section() {
    local shell=$1
    local -a reqBinaries=($2)
    local -a optBinaries=(${3:-})

    if [[ "$shell" == "zsh" ]]; then
        printf 'validate_dependencies() {\n'
        printf '    emulate -L zsh\n'
    else
        printf 'validate_dependencies() {\n'
    fi

    printf '    if [[ "${HAS_EXTERNAL_DEPENDENCIES}" == false ]]; then\n'
    printf '        debug "No external dependencies required"\n'
    printf '        return 0\n'
    printf '    fi\n\n'
    printf '    debug "Validating dependencies..."\n\n'

    if [[ ${#reqBinaries[@]} -gt 0 ]]; then
        printf '    # Required binaries (script will exit if any are missing)\n'
        for binary in "${reqBinaries[@]}"; do
            printf '    require_binary %s\n' "$binary"
        done
        printf '\n'
    fi

    if [[ ${#optBinaries[@]} -gt 0 ]]; then
        printf '    # Optional binaries (script continues if missing)\n'
        for binary in "${optBinaries[@]}"; do
            printf '    optional_binary %s\n' "$binary"
        done
        printf '\n'
    fi

    printf '    debug "All required dependencies satisfied"\n'
    printf '}\n'
}

# Generate argument parsing for bash
# Arguments: Reads from global CUSTOM_ARGS array
# Returns: Generated code via stdout
generate_bash_argument_cases() {
    local -n argList=$1

    for argDef in "${argList[@]}"; do
        # Parse the argument definition (format: short:long:type:required:description)
        local IFS='|'
        read -r shortOpt longOpt argType isRequired helpText <<< "$argDef"

        # Generate case entries
        if [[ -n "$longOpt" ]]; then
            if [[ "$argType" == "boolean" ]]; then
                # Boolean flag - no value needed
                if [[ -n "$shortOpt" ]]; then
                    printf '            -%s|--%s)\n' "$shortOpt" "$longOpt"
                else
                    printf '            --%s)\n' "$longOpt"
                fi
                local varName
                varName=$(echo "${longOpt}" | sed 's/-/_/g' | tr '[:lower:]' '[:upper:]')
                printf '                %s=true\n' "$varName"
                printf '                shift\n'
                printf '                ;;\n'
            else
                # Option with value
                if [[ -n "$shortOpt" ]]; then
                    printf '            -%s|--%s)\n' "$shortOpt" "$longOpt"
                else
                    printf '            --%s)\n' "$longOpt"
                fi
                local varName
                varName=$(echo "${longOpt}" | sed 's/-/_/g' | tr '[:lower:]' '[:upper:]')
                printf '                if [[ -z "${2:-}" ]]; then\n'
                printf '                    error "Option --%s requires an argument"\n' "$longOpt"
                printf '                    usage\n'
                printf '                    exit $E_USAGE\n'
                printf '                fi\n'
                printf '                %s="$2"\n' "$varName"
                printf '                shift 2\n'
                printf '                ;;\n'

                # Also generate --long=value form
                printf '            --%s=*)\n' "$longOpt"
                printf '                %s="${1#*=}"\n' "$varName"
                printf '                shift\n'
                printf '                ;;\n'
            fi
        fi
    done
}

# Generate argument parsing for zsh (zparseopts format)
# Arguments: Reads from global CUSTOM_ARGS array
# Returns: Generated code via stdout
generate_zsh_zparseopts() {
    local -n argList=$1

    for argDef in "${argList[@]}"; do
        local IFS='|'
        read -r shortOpt longOpt argType isRequired helpText <<< "$argDef"

        local varName
        varName="opt_$(echo "${longOpt}" | sed 's/-/_/g')"

        if [[ "$argType" == "boolean" ]]; then
            if [[ -n "$shortOpt" ]]; then
                printf '        %s=%s     -%s=%s \\\n' "$shortOpt" "$varName" "$longOpt" "$varName"
            else
                printf '        -%s=%s \\\n' "$longOpt" "$varName"
            fi
        else
            if [[ -n "$shortOpt" ]]; then
                printf '        %s:=%s    -%s:=%s \\\n' "$shortOpt" "$varName" "$longOpt" "$varName"
            else
                printf '        -%s:=%s \\\n' "$longOpt" "$varName"
            fi
        fi
    done
}

# Generate validation code for a specific argument type
# Arguments:
#   $1 - Variable name
#   $2 - Argument type
#   $3 - Whether required (true/false)
# Returns: Generated validation code via stdout
generate_arg_validation() {
    local varName=$1
    local argType=$2
    local isRequired=$3

    if [[ "$isRequired" == "true" ]]; then
        printf '    if [[ -z "${%s:-}" ]]; then\n' "$varName"
        printf '        error "%s is required"\n' "$varName"
        printf '        usage\n'
        printf '        exit $E_USAGE\n'
        printf '    fi\n\n'
    fi

    case "$argType" in
        integer)
            printf '    if [[ -n "${%s:-}" ]] && ! validate_integer "$%s"; then\n' "$varName" "$varName"
            printf '        fatal "Invalid integer value for %s: ${%s}" $E_USAGE\n' "$varName" "$varName"
            printf '    fi\n\n'
            ;;
        float)
            printf '    if [[ -n "${%s:-}" ]]; then\n' "$varName"
            printf '        if ! [[ "$%s" =~ ^-?[0-9]*\\.?[0-9]+$ ]]; then\n' "$varName"
            printf '            fatal "Invalid float value for %s: ${%s}" $E_USAGE\n' "$varName" "$varName"
            printf '        fi\n'
            printf '    fi\n\n'
            ;;
        file_readable)
            printf '    if [[ -n "${%s:-}" ]] && ! validate_file_readable "$%s"; then\n' "$varName" "$varName"
            printf '        exit $E_NOINPUT\n'
            printf '    fi\n\n'
            ;;
        dir_writable)
            printf '    if [[ -n "${%s:-}" ]] && ! validate_dir_writable "$%s"; then\n' "$varName" "$varName"
            printf '        exit $E_NOPERM\n'
            printf '    fi\n\n'
            ;;
        executable)
            printf '    if [[ -n "${%s:-}" ]] && [[ ! -x "$%s" ]]; then\n' "$varName" "$varName"
            printf '        fatal "Not executable: ${%s}" $E_NOPERM\n' "$varName"
            printf '    fi\n\n'
            ;;
        email)
            printf '    if [[ -n "${%s:-}" ]]; then\n' "$varName"
            printf '        if ! [[ "$%s" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$ ]]; then\n' "$varName"
            printf '            fatal "Invalid email address: ${%s}" $E_USAGE\n' "$varName"
            printf '        fi\n'
            printf '    fi\n\n'
            ;;
        url)
            printf '    if [[ -n "${%s:-}" ]]; then\n' "$varName"
            printf '        if ! [[ "$%s" =~ ^(https?|ftp)://[A-Za-z0-9.-]+(/.*)?$ ]]; then\n' "$varName"
            printf '            fatal "Invalid URL: ${%s}" $E_USAGE\n' "$varName"
            printf '        fi\n'
            printf '    fi\n\n'
            ;;
        ipv4)
            printf '    if [[ -n "${%s:-}" ]]; then\n' "$varName"
            printf '        if ! [[ "$%s" =~ ^([0-9]{1,3}\\.){3}[0-9]{1,3}$ ]]; then\n' "$varName"
            printf '            fatal "Invalid IPv4 address: ${%s}" $E_USAGE\n' "$varName"
            printf '        fi\n'
            printf '    fi\n\n'
            ;;
    esac
}

# Generate the JSON metadata block
# Arguments: None (reads from global variables)
# Returns: JSON metadata via stdout
generate_metadata_json() {
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    cat <<JSONEOF
# ==============================================================================
# METADATA (Auto-generated by init-script - safe to remove)
# ==============================================================================
# JSON_METADATA_START
# {
#   "generator": "shell-script-templates-init",
#   "generatorVersion": "${INIT_VERSION}",
#   "created": "${timestamp}",
#   "script": {
#     "name": "${SCRIPT_META_NAME}",
#     "version": "${SCRIPT_META_VERSION}",
#     "author": "${SCRIPT_META_AUTHOR}",
#     "email": "${SCRIPT_META_EMAIL}",
#     "description": "${SCRIPT_META_DESCRIPTION}",
#     "license": "${SCRIPT_META_LICENSE}",
#     "shell": "${SCRIPT_META_SHELL}"
#   },
#   "flags": {
#     "requireRoot": ${FLAG_REQUIRE_ROOT},
#     "requiresNetwork": ${FLAG_REQUIRES_NETWORK},
#     "requiresDiskSpace": ${FLAG_REQUIRES_DISK_SPACE},
#     "diskSpaceRequiredMb": ${FLAG_DISK_SPACE_MB},
#     "canRunInUserspace": ${FLAG_CAN_RUN_IN_USERSPACE},
#     "supportsDryRun": ${FLAG_SUPPORTS_DRY_RUN},
#     "idempotent": ${FLAG_IDEMPOTENT},
#     "interactive": ${FLAG_INTERACTIVE},
#     "createsArtifacts": ${FLAG_CREATES_ARTIFACTS},
#     "hasExternalDependencies": ${FLAG_HAS_EXTERNAL_DEPS},
#     "usesConfigFiles": ${FLAG_USES_CONFIG_FILES},
#     "supportsParallel": ${FLAG_SUPPORTS_PARALLEL},
#     "verboseByDefault": ${FLAG_VERBOSE_BY_DEFAULT},
#     "includesSelfTest": ${FLAG_INCLUDES_SELF_TEST},
#     "compilable": ${FLAG_COMPILABLE:-false},
#     "enabledPlugins": "${FLAG_ENABLED_PLUGINS}"
#   },
#   "dependencies": {
#     "required": [$(printf '"%s", ' ${SCRIPT_META_REQ_DEPS} | sed 's/, $//')],
#     "optional": [$(printf '"%s", ' ${SCRIPT_META_OPT_DEPS} | sed 's/, $//')]
#   }
# }
# JSON_METADATA_END
JSONEOF
}

# ==============================================================================
# SCRIPT ASSEMBLY
# ==============================================================================

# Generate a complete script from collected metadata
# Arguments:
#   $1 - Output file path
# Returns: 0 on success, exits on failure
assemble_script() {
    local outputPath=$1
    local templatePath
    local extension

    if [[ "$SCRIPT_META_SHELL" == "zsh" ]]; then
        templatePath="${TEMPLATE_DIR}/template.zsh"
        extension=".zsh"
    else
        templatePath="${TEMPLATE_DIR}/template.sh"
        extension=".sh"
    fi

    if [[ ! -f "$templatePath" ]]; then
        print_error "Template not found: ${templatePath}"
        exit 1
    fi

    print_info "Assembling script from template..."

    # Read the template
    local templateContent
    templateContent=$(<"$templatePath")

    # Replace metadata placeholders in the header comment block
    templateContent="${templateContent//script_name/${SCRIPT_META_NAME}}"
    templateContent="${templateContent//Brief description of what this script does./${SCRIPT_META_DESCRIPTION}}"
    templateContent="${templateContent//Your Name <your@email.com>/${SCRIPT_META_AUTHOR} <${SCRIPT_META_EMAIL}>}"
    templateContent="${templateContent//Copyright (c) 2026 Your Name/Copyright (c) $(date +%Y) ${SCRIPT_META_AUTHOR}}"

    # Replace version and author constants
    if [[ "$SCRIPT_META_SHELL" == "zsh" ]]; then
        templateContent=$(echo "$templateContent" | \
            sed "s|typeset -gr SCRIPT_VERSION=\"1.0.0\"|typeset -gr SCRIPT_VERSION=\"${SCRIPT_META_VERSION}\"|" | \
            sed "s|typeset -gr SCRIPT_AUTHOR=\"Your Name <your@email.com>\"|typeset -gr SCRIPT_AUTHOR=\"${SCRIPT_META_AUTHOR} <${SCRIPT_META_EMAIL}>\"|")
    else
        templateContent=$(echo "$templateContent" | \
            sed "s|readonly SCRIPT_VERSION=\"1.0.0\"|readonly SCRIPT_VERSION=\"${SCRIPT_META_VERSION}\"|" | \
            sed "s|readonly SCRIPT_AUTHOR=\"Your Name <your@email.com>\"|readonly SCRIPT_AUTHOR=\"${SCRIPT_META_AUTHOR} <${SCRIPT_META_EMAIL}>\"|")
    fi

    # Replace license info
    templateContent="${templateContent//CC BY-SA 4.0 - https:\/\/creativecommons.org\/licenses\/by-sa\/4.0\//${SCRIPT_META_LICENSE}}"

    # Replace feature flag values
    templateContent=$(echo "$templateContent" | \
        sed "s|REQUIRE_ROOT=false|REQUIRE_ROOT=${FLAG_REQUIRE_ROOT}|" | \
        sed "s|REQUIRES_NETWORK=false|REQUIRES_NETWORK=${FLAG_REQUIRES_NETWORK}|" | \
        sed "s|REQUIRES_DISK_SPACE=false|REQUIRES_DISK_SPACE=${FLAG_REQUIRES_DISK_SPACE}|" | \
        sed "s|DISK_SPACE_REQUIRED_MB=100|DISK_SPACE_REQUIRED_MB=${FLAG_DISK_SPACE_MB}|" | \
        sed "s|CAN_RUN_IN_USERSPACE=true|CAN_RUN_IN_USERSPACE=${FLAG_CAN_RUN_IN_USERSPACE}|" | \
        sed "s|SUPPORTS_DRY_RUN=true|SUPPORTS_DRY_RUN=${FLAG_SUPPORTS_DRY_RUN}|" | \
        sed "s|IDEMPOTENT=false|IDEMPOTENT=${FLAG_IDEMPOTENT}|" | \
        sed "s|INTERACTIVE=false|INTERACTIVE=${FLAG_INTERACTIVE}|" | \
        sed "s|CREATES_ARTIFACTS=false|CREATES_ARTIFACTS=${FLAG_CREATES_ARTIFACTS}|" | \
        sed "s|HAS_EXTERNAL_DEPENDENCIES=true|HAS_EXTERNAL_DEPENDENCIES=${FLAG_HAS_EXTERNAL_DEPS}|" | \
        sed "s|USES_CONFIG_FILES=true|USES_CONFIG_FILES=${FLAG_USES_CONFIG_FILES}|" | \
        sed "s|SUPPORTS_PARALLEL=false|SUPPORTS_PARALLEL=${FLAG_SUPPORTS_PARALLEL}|" | \
        sed "s|VERBOSE_BY_DEFAULT=false|VERBOSE_BY_DEFAULT=${FLAG_VERBOSE_BY_DEFAULT}|" | \
        sed "s|INCLUDES_SELF_TEST=false|INCLUDES_SELF_TEST=${FLAG_INCLUDES_SELF_TEST}|" | \
        sed "s|ENABLED_PLUGINS=\"\"|ENABLED_PLUGINS=\"${FLAG_ENABLED_PLUGINS}\"|")

    if [[ "$SCRIPT_META_SHELL" == "zsh" ]]; then
        templateContent=$(echo "$templateContent" | \
            sed "s|COMPILABLE=true|COMPILABLE=${FLAG_COMPILABLE}|")
    fi

    # Replace the validate_dependencies function body with generated code
    local depSection
    depSection=$(generate_dependency_section "$SCRIPT_META_SHELL" \
        "${SCRIPT_META_REQ_DEPS}" "${SCRIPT_META_OPT_DEPS}")

    # Use awk for multi-line replacement of validate_dependencies
    templateContent=$(echo "$templateContent" | awk -v newFunc="$depSection" '
        /^validate_dependencies\(\)/ { printing=1; print newFunc; next }
        printing && /^}/ { printing=0; next }
        !printing { print }
    ')

    # Replace the metadata block at the bottom
    local metadataBlock
    metadataBlock=$(generate_metadata_json)

    templateContent=$(echo "$templateContent" | awk -v newMeta="$metadataBlock" '
        /^# ==* *$/ && found_meta { printing=1 }
        /^# METADATA/ { found_meta=1; printing=1 }
        printing && /^# JSON_METADATA_END/ { print newMeta; printing=0; next }
        !printing { print }
    ')

    # Write the assembled script
    echo "$templateContent" > "$outputPath"
    chmod +x "$outputPath"

    print_success "Script generated: ${outputPath}"
}

# ==============================================================================
# WIZARD FLOW FUNCTIONS
# ==============================================================================

# Step 1: Shell selection
# Returns: Sets SCRIPT_META_SHELL
wizard_shell_selection() {
    print_header "Step 1: Shell Selection"

    SCRIPT_META_SHELL=$(prompt_select "Which shell will this script use?" "bash" "zsh")
    print_success "Selected: ${SCRIPT_META_SHELL}"
}

# Step 2: Script metadata
# Returns: Sets SCRIPT_META_* variables
wizard_metadata() {
    print_header "Step 2: Script Metadata"

    SCRIPT_META_NAME=$(prompt_text "Script name (no extension)" "my-script")
    SCRIPT_META_VERSION=$(prompt_text "Initial version" "${PORT_VERSION:-$DEFAULT_VERSION}")
    SCRIPT_META_AUTHOR=$(prompt_text "Author name" "${PORT_AUTHOR:-}")
    SCRIPT_META_EMAIL=$(prompt_text "Author email" "")
    SCRIPT_META_DESCRIPTION=$(prompt_text "Brief description" "${PORT_DESCRIPTION:-}")
    SCRIPT_META_COPYRIGHT=$(prompt_text "Copyright holder" "${SCRIPT_META_AUTHOR}")

    SCRIPT_META_LICENSE=$(prompt_select "License" "${AVAILABLE_LICENSES[@]}")

    print_success "Metadata collected"
}

# Step 3: Feature flags
# Returns: Sets FLAG_* variables
wizard_feature_flags() {
    print_header "Step 3: Feature Flags"

    print_info "Configure script behavior (y = yes, n = no, d or Enter = default)"
    echo ""

    FLAG_REQUIRE_ROOT=$(prompt_flag "Require root privileges?" "false")
    FLAG_REQUIRES_NETWORK=$(prompt_flag "Require network connectivity?" "false")
    FLAG_REQUIRES_DISK_SPACE=$(prompt_flag "Require significant disk space?" "false")

    if [[ "$FLAG_REQUIRES_DISK_SPACE" == "true" ]]; then
        FLAG_DISK_SPACE_MB=$(prompt_text "Minimum disk space (MB)" "100")
    else
        FLAG_DISK_SPACE_MB=100
    fi

    # Smart default: if root required, userspace is false
    local userspaceDefault="true"
    if [[ "$FLAG_REQUIRE_ROOT" == "true" ]]; then
        userspaceDefault="false"
        print_info "Note: REQUIRE_ROOT=true implies CAN_RUN_IN_USERSPACE=false"
    fi
    FLAG_CAN_RUN_IN_USERSPACE=$(prompt_flag "Can run in user directories?" "$userspaceDefault")

    FLAG_SUPPORTS_DRY_RUN=$(prompt_flag "Support --dry-run mode?" "true")
    FLAG_IDEMPOTENT=$(prompt_flag "Is the script idempotent (safe to re-run)?" "false")
    FLAG_INTERACTIVE=$(prompt_flag "Requires interactive user input?" "false")
    FLAG_CREATES_ARTIFACTS=$(prompt_flag "Creates persistent output files?" "false")
    FLAG_HAS_EXTERNAL_DEPS=$(prompt_flag "Uses external binaries?" "true")
    FLAG_USES_CONFIG_FILES=$(prompt_flag "Load configuration files?" "true")
    FLAG_SUPPORTS_PARALLEL=$(prompt_flag "Safe for concurrent execution?" "false")
    FLAG_VERBOSE_BY_DEFAULT=$(prompt_flag "Start with verbose output?" "false")
    FLAG_INCLUDES_SELF_TEST=$(prompt_flag "Include self-test functions?" "false")

    if [[ "$SCRIPT_META_SHELL" == "zsh" ]]; then
        FLAG_COMPILABLE=$(prompt_flag "Compatible with zcompile?" "true")

        if [[ "$FLAG_COMPILABLE" == "true" ]]; then
            echo ""
            print_info "Compilation notes for zsh scripts:"
            print_info "  - Compiled scripts (.zwc) load faster by skipping parsing"
            print_info "  - Run: zcompile ${SCRIPT_META_NAME}.zsh"
            print_info "  - Avoid eval and dynamic source for best compatibility"
            print_info "  - Recompile after any code changes"
        fi
    else
        FLAG_COMPILABLE="false"
    fi

    print_success "Feature flags configured"
}

# Step 4: Dependencies
# Returns: Sets SCRIPT_META_REQ_DEPS, SCRIPT_META_OPT_DEPS
wizard_dependencies() {
    print_header "Step 4: Dependencies"

    if [[ "$FLAG_HAS_EXTERNAL_DEPS" == "false" ]]; then
        print_info "External dependencies disabled by feature flag"
        SCRIPT_META_REQ_DEPS=""
        SCRIPT_META_OPT_DEPS=""
        return
    fi

    # Pre-populate from porting if available
    local defaultReq="${PORT_DEPENDENCIES:-}"
    local defaultOpt="${PORT_OPT_DEPENDENCIES:-}"

    if [[ -n "$defaultReq" ]]; then
        print_info "Detected dependencies from existing script: ${defaultReq}"
    fi

    print_info "Enter required binaries (one per line, empty line when done)"
    print_info "Use 'name alternative1 alternative2' for fallback chains"
    echo ""
    SCRIPT_META_REQ_DEPS=$(prompt_list "Required binaries" "Empty line to finish")

    echo ""
    SCRIPT_META_OPT_DEPS=$(prompt_list "Optional binaries" "Empty line to finish")

    # Analyze dependencies
    if [[ -n "$SCRIPT_META_REQ_DEPS" ]]; then
        echo ""
        print_info "Analyzing dependencies..."
        local -a ANALYZED_VERIFIED=()
        local -a ANALYZED_MISSING=()
        local -a ANALYZED_SUB_DEPS=()

        analyze_dependencies "$SCRIPT_META_REQ_DEPS"

        # Offer to add detected sub-dependencies
        if [[ ${#ANALYZED_SUB_DEPS[@]} -gt 0 ]]; then
            echo ""
            local addSubDeps
            addSubDeps=$(prompt_flag "Add implied dependencies (${ANALYZED_SUB_DEPS[*]})?" "true")
            if [[ "$addSubDeps" == "true" ]]; then
                SCRIPT_META_REQ_DEPS="${SCRIPT_META_REQ_DEPS} ${ANALYZED_SUB_DEPS[*]}"
                print_success "Added: ${ANALYZED_SUB_DEPS[*]}"
            fi
        fi
    fi

    print_success "Dependencies configured"
}

# Step 5: Command-line arguments
# Returns: Sets CUSTOM_ARGS array
wizard_arguments() {
    print_header "Step 5: Command-Line Arguments"

    print_info "Define custom command-line arguments"
    print_info "Built-in options (--help, --version, --verbose, --quiet,"
    print_info "  --dry-run, --debug, --config, --output) are already included."
    echo ""

    declare -ga CUSTOM_ARGS=()
    local addMore="true"

    while [[ "$addMore" == "true" ]]; do
        local hasArg
        hasArg=$(prompt_flag "Add a custom argument?" "false")

        if [[ "$hasArg" == "false" ]]; then
            break
        fi

        echo ""
        local shortOpt longOpt argType isRequired helpText

        longOpt=$(prompt_text "Long option name (without --)" "")

        if [[ -z "$longOpt" ]]; then
            print_warn "Long option name required, skipping"
            continue
        fi

        shortOpt=$(prompt_text "Short option letter (without -, or empty)" "")

        argType=$(prompt_select "Value type" \
            "boolean" "string" "integer" "float" \
            "file_readable" "dir_writable" "executable" \
            "email" "url" "ipv4" "path")

        if [[ "$argType" != "boolean" ]]; then
            isRequired=$(prompt_flag "Is this argument required?" "false")
        else
            isRequired="false"
        fi

        helpText=$(prompt_text "Help text for this option" "")

        # Store as delimited string
        CUSTOM_ARGS+=("${shortOpt}|${longOpt}|${argType}|${isRequired}|${helpText}")
        print_success "Added: --${longOpt}"
        echo ""
    done

    print_success "Arguments configured (${#CUSTOM_ARGS[@]} custom argument(s))"
}

# Step 6: Plugins
# Returns: Sets FLAG_ENABLED_PLUGINS
wizard_plugins() {
    print_header "Step 6: Plugins"

    FLAG_ENABLED_PLUGINS=""

    # List available plugins
    local -a availablePlugins=()
    if [[ -d "$PLUGIN_DIR" ]]; then
        for pluginPath in "${PLUGIN_DIR}"/*/plugin.conf; do
            if [[ -f "$pluginPath" ]]; then
                local pluginName
                pluginName=$(basename "$(dirname "$pluginPath")")
                availablePlugins+=("$pluginName")
            fi
        done
    fi

    # Also check the repo's plugin directory
    if [[ -d "${INIT_SCRIPT_DIR}/plugins" ]]; then
        for pluginPath in "${INIT_SCRIPT_DIR}/plugins"/*/plugin.conf; do
            if [[ -f "$pluginPath" ]]; then
                local pluginName
                pluginName=$(basename "$(dirname "$pluginPath")")
                # Avoid duplicates
                local isDuplicate=false
                for existing in "${availablePlugins[@]:-}"; do
                    [[ "$existing" == "$pluginName" ]] && isDuplicate=true
                done
                [[ "$isDuplicate" == "false" ]] && availablePlugins+=("$pluginName")
            fi
        done
    fi

    if [[ ${#availablePlugins[@]} -eq 0 ]]; then
        print_info "No plugins found. Plugins can be installed to:"
        print_info "  ${PLUGIN_DIR}/"
        return
    fi

    print_info "Available plugins:"
    local -a selectedPlugins=()

    for plugin in "${availablePlugins[@]}"; do
        # Read plugin description from conf
        local pluginDesc=""
        local confPath="${PLUGIN_DIR}/${plugin}/plugin.conf"
        [[ ! -f "$confPath" ]] && confPath="${INIT_SCRIPT_DIR}/plugins/${plugin}/plugin.conf"

        if [[ -f "$confPath" ]]; then
            pluginDesc=$(grep -oP 'PLUGIN_DESCRIPTION="\K[^"]+' "$confPath" 2>/dev/null || echo "")
        fi

        local enablePlugin
        enablePlugin=$(prompt_flag "  Enable '${plugin}'${pluginDesc:+ - $pluginDesc}?" "false")

        if [[ "$enablePlugin" == "true" ]]; then
            selectedPlugins+=("$plugin")
        fi
    done

    if [[ ${#selectedPlugins[@]} -gt 0 ]]; then
        FLAG_ENABLED_PLUGINS=$(printf '%s,' "${selectedPlugins[@]}" | sed 's/,$//')
        print_success "Enabled plugins: ${FLAG_ENABLED_PLUGINS}"
    else
        print_info "No plugins enabled"
    fi
}

# Step 7: Test scaffolding
# Returns: Sets FLAG_INCLUDES_SELF_TEST, GENERATE_TEST_FILE
wizard_testing() {
    print_header "Step 7: Test Scaffolding"

    local wantTests
    wantTests=$(prompt_flag "Include test scaffolding?" "${FLAG_INCLUDES_SELF_TEST}")
    FLAG_INCLUDES_SELF_TEST="$wantTests"

    GENERATE_TEST_FILE="false"
    if [[ "$wantTests" == "true" ]]; then
        print_info "Self-test functions will be included inline (--self-test flag)"
        echo ""
        GENERATE_TEST_FILE=$(prompt_flag "Also generate a separate test file?" "false")
    fi
}

# Step 8: Preview and confirm
# Returns: 0 if confirmed, 1 if cancelled
wizard_preview() {
    print_header "Step 8: Preview & Confirm"

    local extension
    [[ "$SCRIPT_META_SHELL" == "zsh" ]] && extension=".zsh" || extension=".sh"

    printf '%bScript Configuration Summary%b\n\n' "${C[bold]:-}" "${C[reset]:-}"
    printf '  %-24s %s\n' "Output file:" "${SCRIPT_META_NAME}${extension}"
    printf '  %-24s %s\n' "Shell:" "${SCRIPT_META_SHELL}"
    printf '  %-24s %s\n' "Version:" "${SCRIPT_META_VERSION}"
    printf '  %-24s %s\n' "Author:" "${SCRIPT_META_AUTHOR} <${SCRIPT_META_EMAIL}>"
    printf '  %-24s %s\n' "License:" "${SCRIPT_META_LICENSE}"
    printf '  %-24s %s\n' "Description:" "${SCRIPT_META_DESCRIPTION}"
    echo ""

    printf '  %bFeature Flags:%b\n' "${C[cyan]:-}" "${C[reset]:-}"
    printf '    %-28s %s\n' "Require root:" "${FLAG_REQUIRE_ROOT}"
    printf '    %-28s %s\n' "Requires network:" "${FLAG_REQUIRES_NETWORK}"
    printf '    %-28s %s\n' "Requires disk space:" "${FLAG_REQUIRES_DISK_SPACE}"
    printf '    %-28s %s\n' "Supports dry-run:" "${FLAG_SUPPORTS_DRY_RUN}"
    printf '    %-28s %s\n' "Idempotent:" "${FLAG_IDEMPOTENT}"
    printf '    %-28s %s\n' "Interactive:" "${FLAG_INTERACTIVE}"
    printf '    %-28s %s\n' "Creates artifacts:" "${FLAG_CREATES_ARTIFACTS}"
    printf '    %-28s %s\n' "External dependencies:" "${FLAG_HAS_EXTERNAL_DEPS}"
    printf '    %-28s %s\n' "Config files:" "${FLAG_USES_CONFIG_FILES}"
    printf '    %-28s %s\n' "Self-test:" "${FLAG_INCLUDES_SELF_TEST}"
    printf '    %-28s %s\n' "Plugins:" "${FLAG_ENABLED_PLUGINS:-none}"
    if [[ "$SCRIPT_META_SHELL" == "zsh" ]]; then
        printf '    %-28s %s\n' "Compilable:" "${FLAG_COMPILABLE}"
    fi
    echo ""

    if [[ -n "${SCRIPT_META_REQ_DEPS}" ]]; then
        printf '  %bRequired dependencies:%b %s\n' "${C[cyan]:-}" "${C[reset]:-}" "${SCRIPT_META_REQ_DEPS}"
    fi
    if [[ -n "${SCRIPT_META_OPT_DEPS}" ]]; then
        printf '  %bOptional dependencies:%b %s\n' "${C[cyan]:-}" "${C[reset]:-}" "${SCRIPT_META_OPT_DEPS}"
    fi
    if [[ ${#CUSTOM_ARGS[@]} -gt 0 ]]; then
        printf '  %bCustom arguments:%b %d defined\n' "${C[cyan]:-}" "${C[reset]:-}" "${#CUSTOM_ARGS[@]}"
    fi
    echo ""

    local confirm
    confirm=$(prompt_flag "Generate script with these settings?" "true")

    [[ "$confirm" == "true" ]]
}

# ==============================================================================
# HELP AND VERSION
# ==============================================================================

show_help() {
    cat <<EOF
init-script.sh ${INIT_VERSION} - Shell Script Template Initialization Wizard

Usage:
    init-script.sh [OPTIONS]
    init-script.sh --port <existing-script>

Options:
    -h, --help          Show this help message
    -V, --version       Show version information
    -p, --port FILE     Port an existing v1-v3 script to v4 format
    -o, --output DIR    Output directory (default: current directory)
    -q, --quiet         Minimal output
    --non-interactive   Use all defaults (for AI/CI integration)
    --shell SHELL       Pre-select shell type (bash or zsh)
    --name NAME         Pre-set script name

Examples:
    init-script.sh                           # Interactive wizard
    init-script.sh --port old-script.sh      # Port existing script
    init-script.sh --shell bash --name deploy  # Pre-filled wizard
    init-script.sh --non-interactive --shell bash --name build  # Automated

For more information, see INITIALIZATION_GUIDE.md in the repository.
EOF
}

show_version() {
    echo "init-script.sh ${INIT_VERSION}"
    echo "Part of Shell Script Templates v4.1"
    echo "License: CC BY-SA 4.0"
}

# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

main() {
    init_colors

    # Parse our own arguments
    local portFile=""
    local outputDir="."
    local presetShell=""
    local presetName=""
    local nonInteractive=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_help; exit 0 ;;
            -V|--version) show_version; exit 0 ;;
            -p|--port)    portFile="$2"; shift 2 ;;
            --port=*)     portFile="${1#*=}"; shift ;;
            -o|--output)  outputDir="$2"; shift 2 ;;
            --output=*)   outputDir="${1#*=}"; shift ;;
            --shell)      presetShell="$2"; shift 2 ;;
            --shell=*)    presetShell="${1#*=}"; shift ;;
            --name)       presetName="$2"; shift 2 ;;
            --name=*)     presetName="${1#*=}"; shift ;;
            -q|--quiet)   shift ;;
            --non-interactive) nonInteractive=true; shift ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Initialize port data variables
    PORT_SHELL=""
    PORT_VERSION=""
    PORT_AUTHOR=""
    PORT_DESCRIPTION=""
    PORT_DEPENDENCIES=""
    PORT_OPT_DEPENDENCIES=""
    PORT_HAS_DRY_RUN="false"
    PORT_HAS_CONFIG="false"
    PORT_JSON_NAME=""
    PORT_JSON_VERSION=""

    # Initialize script metadata
    SCRIPT_META_NAME="${presetName:-my-script}"
    SCRIPT_META_VERSION="${DEFAULT_VERSION}"
    SCRIPT_META_AUTHOR=""
    SCRIPT_META_EMAIL=""
    SCRIPT_META_DESCRIPTION=""
    SCRIPT_META_COPYRIGHT=""
    SCRIPT_META_LICENSE="${DEFAULT_LICENSE}"
    SCRIPT_META_SHELL="${presetShell:-bash}"
    SCRIPT_META_REQ_DEPS=""
    SCRIPT_META_OPT_DEPS=""

    # Initialize flags with defaults
    FLAG_REQUIRE_ROOT="false"
    FLAG_REQUIRES_NETWORK="false"
    FLAG_REQUIRES_DISK_SPACE="false"
    FLAG_DISK_SPACE_MB=100
    FLAG_CAN_RUN_IN_USERSPACE="true"
    FLAG_SUPPORTS_DRY_RUN="true"
    FLAG_IDEMPOTENT="false"
    FLAG_INTERACTIVE="false"
    FLAG_CREATES_ARTIFACTS="false"
    FLAG_HAS_EXTERNAL_DEPS="true"
    FLAG_USES_CONFIG_FILES="true"
    FLAG_SUPPORTS_PARALLEL="false"
    FLAG_VERBOSE_BY_DEFAULT="false"
    FLAG_INCLUDES_SELF_TEST="false"
    FLAG_COMPILABLE="true"
    FLAG_ENABLED_PLUGINS=""

    GENERATE_TEST_FILE="false"
    declare -ga CUSTOM_ARGS=()

    # Handle porting mode
    if [[ -n "$portFile" ]]; then
        if [[ ! -f "$portFile" ]]; then
            print_error "File not found: ${portFile}"
            exit 1
        fi

        print_header "Porting Mode: Analyzing Existing Script"
        print_info "Analyzing: ${portFile}"
        extract_script_metadata "$portFile"

        print_success "Detected shell: ${PORT_SHELL}"
        [[ -n "$PORT_VERSION" ]] && print_success "Detected version: ${PORT_VERSION}"
        [[ -n "$PORT_AUTHOR" ]] && print_success "Detected author: ${PORT_AUTHOR}"
        [[ -n "$PORT_DESCRIPTION" ]] && print_success "Detected description: ${PORT_DESCRIPTION}"
        [[ -n "$PORT_DEPENDENCIES" ]] && print_success "Detected dependencies: ${PORT_DEPENDENCIES}"

        SCRIPT_META_SHELL="${presetShell:-$PORT_SHELL}"
        SCRIPT_META_REQ_DEPS="${PORT_DEPENDENCIES}"
        SCRIPT_META_OPT_DEPS="${PORT_OPT_DEPENDENCIES}"
        echo ""
        print_info "Extracted metadata will pre-fill the wizard prompts."
        print_info "Press Enter to accept detected values, or type new values."
    fi

    # Print banner
    if [[ "$nonInteractive" == "false" ]]; then
        printf '\n%b╔══════════════════════════════════════════════════════════╗%b\n' \
            "${C[cyan]:-}" "${C[reset]:-}"
        printf '%b║  Shell Script Templates v4 - Initialization Wizard      ║%b\n' \
            "${C[bold]:-}${C[cyan]:-}" "${C[reset]:-}"
        printf '%b╚══════════════════════════════════════════════════════════╝%b\n' \
            "${C[cyan]:-}" "${C[reset]:-}"

        # Run wizard steps
        if [[ -z "$presetShell" ]]; then
            wizard_shell_selection
        else
            print_info "Shell pre-selected: ${SCRIPT_META_SHELL}"
        fi

        wizard_metadata
        wizard_feature_flags
        wizard_dependencies
        wizard_arguments
        wizard_plugins
        wizard_testing

        if ! wizard_preview; then
            print_warn "Script generation cancelled"
            exit 0
        fi
    else
        print_info "Non-interactive mode: using defaults"
    fi

    # Determine output path
    local extension
    [[ "$SCRIPT_META_SHELL" == "zsh" ]] && extension=".zsh" || extension=".sh"
    local outputPath="${outputDir}/${SCRIPT_META_NAME}${extension}"

    # Check for existing file
    if [[ -f "$outputPath" ]]; then
        if [[ "$nonInteractive" == "false" ]]; then
            local overwrite
            overwrite=$(prompt_flag "File exists: ${outputPath}. Overwrite?" "false")
            if [[ "$overwrite" == "false" ]]; then
                print_warn "Aborted - file not overwritten"
                exit 0
            fi
        else
            print_warn "Overwriting existing file: ${outputPath}"
        fi
    fi

    # Generate the script
    assemble_script "$outputPath"

    # Generate separate test file if requested
    if [[ "$GENERATE_TEST_FILE" == "true" ]]; then
        local testPath="${outputDir}/${SCRIPT_META_NAME}-test${extension}"
        print_info "Generating test file: ${testPath}"
        generate_test_file "$testPath"
    fi

    # Generate tab-completion scripts
    local completionsGenerated=false
    if [[ "$nonInteractive" == "false" ]]; then
        local wantCompletions
        wantCompletions=$(prompt_flag "Generate tab-completion scripts?" "true")
        if [[ "$wantCompletions" == "true" ]]; then
            generate_completions "$outputDir" "$extension"
            completionsGenerated=true
        fi
    fi

    # Final instructions
    echo ""
    print_header "Done!"
    print_success "Script generated: ${outputPath}"
    echo ""
    print_info "Next steps:"
    print_info "  1. Open ${outputPath} and implement your logic in main()"
    print_info "  2. Update the help text in show_help()"
    print_info "  3. Run: ./${SCRIPT_META_NAME}${extension} --help"
    print_info "  4. Test: ./${SCRIPT_META_NAME}${extension} --self-test"

    local nextStep=5
    if [[ "$SCRIPT_META_SHELL" == "zsh" ]] && [[ "$FLAG_COMPILABLE" == "true" ]]; then
        print_info "  ${nextStep}. Compile: zcompile ${SCRIPT_META_NAME}${extension}"
        ((nextStep++))
    fi

    if [[ "$completionsGenerated" == "true" ]]; then
        print_info "  ${nextStep}. Install completions:"
        print_info "       Bash: cp ${outputDir}/${SCRIPT_META_NAME}.bash-completion \\"
        print_info "             ~/.local/share/bash-completion/completions/"
        print_info "       Zsh:  cp ${outputDir}/_${SCRIPT_META_NAME} ~/.zsh/completions/"
    fi

    echo ""
}

# Generate bash and zsh completion scripts for the generated script
# Arguments:
#   $1 - Output directory
#   $2 - Script extension (.sh or .zsh)
# Returns: Creates completion files in output directory
generate_completions() {
    local outputDir=$1
    local extension=$2

    # Build option lists from built-in + custom arguments
    local longOpts="help version verbose quiet dry-run debug config output self-test"
    local shortOpts="h V v q n d c o"
    local fileOpts="config output"
    local dirOpts=""

    # Add custom argument options
    for argDef in "${CUSTOM_ARGS[@]:-}"; do
        [[ -z "$argDef" ]] && continue
        local IFS='|'
        read -r sOpt lOpt aType aReq aHelp <<< "$argDef"
        [[ -n "$lOpt" ]] && longOpts="${longOpts} ${lOpt}"
        [[ -n "$sOpt" ]] && shortOpts="${shortOpts} ${sOpt}"
        case "$aType" in
            file_readable|file_writable|path) fileOpts="${fileOpts} ${lOpt}" ;;
            dir_readable|dir_writable) dirOpts="${dirOpts} ${lOpt}" ;;
        esac
    done

    # --- Bash completion ---
    local bashFile="${outputDir}/${SCRIPT_META_NAME}.bash-completion"
    local funcName="_${SCRIPT_META_NAME//[^a-zA-Z0-9_]/_}"

    {
        printf '# bash completion for %s\n' "$SCRIPT_META_NAME"
        printf '# Generated by Shell Script Templates v4 init-script\n'
        printf '#\n'
        printf '# Installation:\n'
        printf '#   User:   cp this-file ~/.local/share/bash-completion/completions/%s\n' "$SCRIPT_META_NAME"
        printf '#   System: sudo cp this-file /etc/bash_completion.d/%s\n\n' "$SCRIPT_META_NAME"

        printf '%s() {\n' "$funcName"
        printf '    local cur prev opts\n'
        printf '    COMPREPLY=()\n'
        printf '    cur="${COMP_WORDS[COMP_CWORD]}"\n'
        printf '    prev="${COMP_WORDS[COMP_CWORD-1]}"\n\n'

        # Build full option string
        local allOpts=""
        for opt in $longOpts; do allOpts="${allOpts} --${opt}"; done
        for opt in $shortOpts; do allOpts="${allOpts} -${opt}"; done
        printf '    opts="%s"\n\n' "$allOpts"

        printf '    case "${prev}" in\n'
        for opt in $fileOpts; do
            printf '        --%s)\n' "$opt"
            printf '            COMPREPLY=( $(compgen -f -- "${cur}") )\n'
            printf '            return 0\n'
            printf '            ;;\n'
        done
        for opt in $dirOpts; do
            printf '        --%s)\n' "$opt"
            printf '            COMPREPLY=( $(compgen -d -- "${cur}") )\n'
            printf '            return 0\n'
            printf '            ;;\n'
        done
        printf '    esac\n\n'

        printf '    if [[ "${cur}" == -* ]]; then\n'
        printf '        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )\n'
        printf '        return 0\n'
        printf '    fi\n\n'
        printf '    COMPREPLY=( $(compgen -f -- "${cur}") )\n'
        printf '    return 0\n'
        printf '}\n\n'
        printf 'complete -F %s %s%s\n' "$funcName" "$SCRIPT_META_NAME" "$extension"
        printf 'complete -F %s %s\n' "$funcName" "$SCRIPT_META_NAME"
    } > "$bashFile"

    print_success "Generated: ${bashFile}"

    # --- Zsh completion ---
    local zshFile="${outputDir}/_${SCRIPT_META_NAME}"

    {
        printf '#compdef %s%s %s\n' "$SCRIPT_META_NAME" "$extension" "$SCRIPT_META_NAME"
        printf '# zsh completion for %s\n' "$SCRIPT_META_NAME"
        printf '# Generated by Shell Script Templates v4 init-script\n'
        printf '#\n'
        printf '# Installation:\n'
        printf '#   cp this-file ~/.zsh/completions/_%s\n' "$SCRIPT_META_NAME"
        printf '#   Then: autoload -Uz compinit && compinit\n\n'

        printf '%s() {\n' "$funcName"
        printf '    local -a options\n'
        printf '    options=(\n'
        printf "        '(-h --help)'{-h,--help}'[Show help message and exit]'\n"
        printf "        '(-V --version)'{-V,--version}'[Show version information and exit]'\n"
        printf "        '*'{-v,--verbose}'[Increase verbosity (repeatable)]'\n"
        printf "        '(-q --quiet)'{-q,--quiet}'[Suppress non-error output]'\n"
        printf "        '(-n --dry-run)'{-n,--dry-run}'[Show what would be done]'\n"
        printf "        '(-d --debug)'{-d,--debug}'[Enable debug mode]'\n"
        printf "        '(-c --config)'{-c,--config}'[Configuration file]:config file:_files'\n"
        printf "        '(-o --output)'{-o,--output}'[Output file]:output file:_files'\n"
        printf "        '--self-test[Run internal self-tests and exit]'\n"

        # Add custom arguments
        for argDef in "${CUSTOM_ARGS[@]:-}"; do
            [[ -z "$argDef" ]] && continue
            local IFS='|'
            read -r sOpt lOpt aType aReq aHelp <<< "$argDef"

            local actionSpec=""
            case "$aType" in
                boolean) actionSpec="" ;;
                file_readable|file_writable|path) actionSpec=":file:_files" ;;
                dir_readable|dir_writable) actionSpec=":directory:_directories" ;;
                executable) actionSpec=":command:_commands" ;;
                hostname) actionSpec=":host:_hosts" ;;
                *) actionSpec=":${aType}:" ;;
            esac

            if [[ -n "$sOpt" ]] && [[ -n "$lOpt" ]]; then
                if [[ "$aType" == "boolean" ]]; then
                    printf "        '(-%s --%s)'{-%s,--%s}'[%s]'\n" "$sOpt" "$lOpt" "$sOpt" "$lOpt" "$aHelp"
                else
                    printf "        '(-%s --%s)'{-%s,--%s}'[%s]%s'\n" "$sOpt" "$lOpt" "$sOpt" "$lOpt" "$aHelp" "$actionSpec"
                fi
            elif [[ -n "$lOpt" ]]; then
                if [[ "$aType" == "boolean" ]]; then
                    printf "        '--%s[%s]'\n" "$lOpt" "$aHelp"
                else
                    printf "        '--%s[%s]%s'\n" "$lOpt" "$aHelp" "$actionSpec"
                fi
            fi
        done

        printf '    )\n\n'
        printf "    _arguments -s \$options '*:file:_files'\n"
        printf '}\n\n'
        printf '%s "$@"\n' "$funcName"
    } > "$zshFile"

    print_success "Generated: ${zshFile}"
}

# Generate a standalone test file
# Arguments: $1 - Output path
generate_test_file() {
    local testPath=$1
    local extension
    [[ "$SCRIPT_META_SHELL" == "zsh" ]] && extension=".zsh" || extension=".sh"
    local shebang
    [[ "$SCRIPT_META_SHELL" == "zsh" ]] && shebang="#!/usr/bin/env zsh" || shebang="#!/usr/bin/env bash"

    cat > "$testPath" <<TESTEOF
${shebang}
# ${SCRIPT_META_NAME}-test${extension}
#
# Description:
#   Test suite for ${SCRIPT_META_NAME}
#
# Usage:
#   ./${SCRIPT_META_NAME}-test${extension}
#
# Generated by Shell Script Templates v4 init-script

set -o errexit
set -o nounset
set -o pipefail

# ==============================================================================
# TEST CONFIGURATION
# ==============================================================================
readonly SCRIPT_UNDER_TEST="./${SCRIPT_META_NAME}${extension}"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

# ==============================================================================
# TEST FRAMEWORK
# ==============================================================================

# Assert that a command succeeds
# Arguments: Description, command...
assert_success() {
    local description=\$1
    shift
    ((TESTS_RUN++)) || true

    if "\$@" >/dev/null 2>&1; then
        printf '%b  PASS%b %s\n' "\$GREEN" "\$RESET" "\$description"
        ((TESTS_PASSED++)) || true
    else
        printf '%b  FAIL%b %s\n' "\$RED" "\$RESET" "\$description"
        ((TESTS_FAILED++)) || true
    fi
}

# Assert that a command fails
# Arguments: Description, command...
assert_failure() {
    local description=\$1
    shift
    ((TESTS_RUN++)) || true

    if ! "\$@" >/dev/null 2>&1; then
        printf '%b  PASS%b %s\n' "\$GREEN" "\$RESET" "\$description"
        ((TESTS_PASSED++)) || true
    else
        printf '%b  FAIL%b %s\n' "\$RED" "\$RESET" "\$description"
        ((TESTS_FAILED++)) || true
    fi
}

# Assert that output contains expected string
# Arguments: Description, expected string, command...
assert_output_contains() {
    local description=\$1
    local expected=\$2
    shift 2
    ((TESTS_RUN++)) || true

    local output
    output=\$("\$@" 2>&1 || true)

    if [[ "\$output" == *"\$expected"* ]]; then
        printf '%b  PASS%b %s\n' "\$GREEN" "\$RESET" "\$description"
        ((TESTS_PASSED++)) || true
    else
        printf '%b  FAIL%b %s (expected: %s)\n' "\$RED" "\$RESET" "\$description" "\$expected"
        ((TESTS_FAILED++)) || true
    fi
}

# ==============================================================================
# TEST CASES
# ==============================================================================

test_help_flag() {
    printf '\n%bTest Suite: Help and Version%b\n' "\$YELLOW" "\$RESET"
    assert_success "--help exits successfully" \$SCRIPT_UNDER_TEST --help
    assert_success "--version exits successfully" \$SCRIPT_UNDER_TEST --version
    assert_output_contains "--help shows usage" "Usage:" \$SCRIPT_UNDER_TEST --help
    assert_output_contains "--version shows version" "${SCRIPT_META_VERSION}" \$SCRIPT_UNDER_TEST --version
}

test_invalid_args() {
    printf '\n%bTest Suite: Invalid Arguments%b\n' "\$YELLOW" "\$RESET"
    assert_failure "Unknown option fails" \$SCRIPT_UNDER_TEST --nonexistent-option
}

test_self_test() {
    printf '\n%bTest Suite: Self-Test%b\n' "\$YELLOW" "\$RESET"
    assert_success "--self-test passes" \$SCRIPT_UNDER_TEST --self-test
}

# Add your custom tests below
# test_custom_feature() {
#     printf '\n%bTest Suite: Custom Feature%b\n' "\$YELLOW" "\$RESET"
#     assert_success "Custom test" \$SCRIPT_UNDER_TEST --your-flag
# }

# ==============================================================================
# MAIN
# ==============================================================================

printf '%b═══════════════════════════════════════════════%b\n' "\$YELLOW" "\$RESET"
printf '%b  Test Suite: %s%b\n' "\$YELLOW" "${SCRIPT_META_NAME}" "\$RESET"
printf '%b═══════════════════════════════════════════════%b\n' "\$YELLOW" "\$RESET"

# Verify script exists
if [[ ! -x "\$SCRIPT_UNDER_TEST" ]]; then
    printf '%bERROR: Script not found or not executable: %s%b\n' "\$RED" "\$SCRIPT_UNDER_TEST" "\$RESET"
    exit 1
fi

# Run test suites
test_help_flag
test_invalid_args
test_self_test

# Summary
printf '\n%b═══════════════════════════════════════════════%b\n' "\$YELLOW" "\$RESET"
printf '  Total: %d  Passed: %b%d%b  Failed: %b%d%b\n' \\
    "\$TESTS_RUN" \\
    "\$GREEN" "\$TESTS_PASSED" "\$RESET" \\
    "\$RED" "\$TESTS_FAILED" "\$RESET"
printf '%b═══════════════════════════════════════════════%b\n' "\$YELLOW" "\$RESET"

if ((TESTS_FAILED > 0)); then
    exit 1
fi
exit 0
TESTEOF

    chmod +x "$testPath"
    print_success "Test file generated: ${testPath}"
}

# Execute
main "$@"
