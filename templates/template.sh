#!/usr/bin/env bash
# script_name(1)
#
# Description:
#   Brief description of what this script does.
#
# Usage:
#   script_name [OPTIONS] [ARGS]
#
# Author:
#   Your Name <your@email.com>
#
# Copyright:
#   Copyright (c) 2026 Your Name
#
# License:
#   CC BY-SA 4.0 - https://creativecommons.org/licenses/by-sa/4.0/

# ==============================================================================
# FEATURE FLAGS - Configure script behavior
# ==============================================================================
# These flags control which features and validations are enabled.
# Set to true/false or comment out to use defaults.

# Execution Requirements
readonly REQUIRE_ROOT=false                 # Must run as root (default: false)
readonly REQUIRES_NETWORK=false             # Needs network access (default: false)
readonly REQUIRES_DISK_SPACE=false          # Creates significant temp/output files (default: false)
readonly DISK_SPACE_REQUIRED_MB=100         # Minimum MB needed if REQUIRES_DISK_SPACE=true

# Capabilities
readonly CAN_RUN_IN_USERSPACE=true          # Can run in user directories (default: true)
readonly SUPPORTS_DRY_RUN=true              # Supports --dry-run mode (default: true)
readonly IDEMPOTENT=false                   # Safe to run multiple times (default: false)
readonly INTERACTIVE=false                  # Requires user input beyond CLI (default: false)
readonly CREATES_ARTIFACTS=false            # Produces persistent output files (default: false)

# Feature Toggles
readonly HAS_EXTERNAL_DEPENDENCIES=true     # Uses external binaries (default: true)
readonly USES_CONFIG_FILES=true             # Loads configuration files (default: true)
readonly SUPPORTS_PARALLEL=false            # Safe for concurrent execution (default: false)
readonly VERBOSE_BY_DEFAULT=false           # Start with verbose output (default: false)
readonly INCLUDES_SELF_TEST=false           # Includes test functions (default: false)

# Plugin System
readonly ENABLED_PLUGINS=""                 # Comma-separated plugin list (default: "")
readonly PLUGIN_DIR="${HOME}/.shell-script-templates/plugins"

# ==============================================================================
# STRICT MODE AND SHELL OPTIONS
# ==============================================================================
set -o errexit   # Exit on any command failure
set -o nounset   # Error on undefined variables
set -o pipefail  # Pipeline fails if any command fails

# Verify bash version
if ((BASH_VERSINFO[0] < 4)); then
    echo >&2 "Error: This script requires bash 4.0 or later"
    echo >&2 "Current version: ${BASH_VERSION}"
    exit 1
fi

# ==============================================================================
# CONSTANTS AND DEFAULTS
# ==============================================================================
# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_AUTHOR="Your Name <your@email.com>"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"

# Exit codes (sysexits.h style)
readonly E_SUCCESS=0        # Success
readonly E_GENERAL=1        # General error
readonly E_USAGE=2          # Command syntax error
readonly E_NOINPUT=66       # Input file not found
readonly E_NOUSER=67        # User not found
readonly E_NOHOST=68        # Host not found
readonly E_UNAVAILABLE=69   # Service unavailable
readonly E_SOFTWARE=70      # Internal software error
readonly E_OSERR=71         # Operating system error
readonly E_OSFILE=72        # OS file missing
readonly E_CANTCREAT=73     # Cannot create file
readonly E_IOERR=74         # I/O error
readonly E_TEMPFAIL=75      # Temporary failure
readonly E_PROTOCOL=76      # Protocol error
readonly E_NOPERM=77        # Permission denied
readonly E_CONFIG=78        # Configuration error

# Verbosity levels
readonly V_QUIET=0          # Errors only
readonly V_NORMAL=1         # Standard output
readonly V_VERBOSE=2        # Detailed progress
readonly V_DEBUG=3          # Debug information
readonly V_TRACE=4          # Full execution trace

# ==============================================================================
# GLOBAL VARIABLES (mutable state)
# ==============================================================================
# Verbosity control
VERBOSITY=${V_NORMAL}
[[ "${VERBOSE_BY_DEFAULT}" == true ]] && VERBOSITY=${V_VERBOSE}

# Execution control
DRY_RUN=false
RUN_SELF_TEST=false

# Resource tracking
declare -a TEMP_FILES=()
TEMP_DIR=""

# Dependency tracking
declare -A REQUIRED_BINARIES=()
declare -A OPTIONAL_BINARIES=()

# Argument storage
declare -a POSITIONAL_ARGS=()
CONFIG_FILE=""
OUTPUT_FILE=""

# Terminal colors
declare -A COLORS=(
    [reset]=''
    [bold]=''
    [dim]=''
    [red]=''
    [green]=''
    [yellow]=''
    [blue]=''
    [magenta]=''
    [cyan]=''
    [white]=''
)

# ==============================================================================
# LOGGING AND OUTPUT
# ==============================================================================

# Initialize terminal colors if supported
# Globals: COLORS (modified)
# Arguments: None
# Returns: None
init_colors() {
    # Only enable colors for terminal output
    if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
        COLORS[reset]='\033[0m'
        COLORS[bold]='\033[1m'
        COLORS[dim]='\033[2m'
        COLORS[red]='\033[31m'
        COLORS[green]='\033[32m'
        COLORS[yellow]='\033[33m'
        COLORS[blue]='\033[34m'
        COLORS[magenta]='\033[35m'
        COLORS[cyan]='\033[36m'
        COLORS[white]='\033[37m'
    fi
}

# Format a log message with timestamp and level
# Globals: None
# Arguments:
#   $1 - Log level string
#   $2 - Message
# Returns: Formatted string via stdout
format_log_message() {
    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '[%s] [%s] %s\n' "$timestamp" "$level" "$message"
}

# Log trace message (verbosity 4+)
# Globals: VERBOSITY, COLORS
# Arguments: Message string
# Returns: None
trace() {
    if ((VERBOSITY >= V_TRACE)); then
        printf '%b%s%b\n' "${COLORS[dim]}" "$(format_log_message "TRACE" "$*")" "${COLORS[reset]}"
    fi
}

# Log debug message (verbosity 3+)
# Globals: VERBOSITY, COLORS
# Arguments: Message string
# Returns: None
debug() {
    if ((VERBOSITY >= V_DEBUG)); then
        printf '%b%s%b\n' "${COLORS[cyan]}" "$(format_log_message "DEBUG" "$*")" "${COLORS[reset]}"
    fi
}

# Log info message (verbosity 1+)
# Globals: VERBOSITY, COLORS
# Arguments: Message string
# Returns: None
info() {
    if ((VERBOSITY >= V_NORMAL)); then
        printf '%b%s%b\n' "${COLORS[green]}" "$(format_log_message "INFO" "$*")" "${COLORS[reset]}"
    fi
}

# Log warning message (verbosity 1+)
# Globals: VERBOSITY, COLORS
# Arguments: Message string
# Returns: None
warn() {
    if ((VERBOSITY >= V_NORMAL)); then
        printf '%b%s%b\n' "${COLORS[yellow]}" "$(format_log_message "WARN" "$*")" "${COLORS[reset]}" >&2
    fi
}

# Log error message (always shown)
# Globals: COLORS
# Arguments: Message string
# Returns: None
error() {
    printf '%b%s%b\n' "${COLORS[red]}" "$(format_log_message "ERROR" "$*")" "${COLORS[reset]}" >&2
}

# Log fatal error and exit
# Globals: COLORS
# Arguments:
#   $1 - Error message
#   $2 - Exit code (optional, default: E_GENERAL)
# Returns: Never (exits)
fatal() {
    local message=$1
    local exit_code=${2:-$E_GENERAL}
    printf '%b%b%s%b\n' "${COLORS[bold]}" "${COLORS[red]}" \
        "$(format_log_message "FATAL" "$message")" "${COLORS[reset]}" >&2
    exit "$exit_code"
}

# Simple message output (verbosity 1+)
# Globals: VERBOSITY
# Arguments: Message string
# Returns: None
msg() {
    if ((VERBOSITY >= V_NORMAL)); then
        printf '%s\n' "$*"
    fi
}

# Simple message without newline (verbosity 1+)
# Globals: VERBOSITY
# Arguments: Message string
# Returns: None
msgn() {
    if ((VERBOSITY >= V_NORMAL)); then
        printf '%s' "$*"
    fi
}

# ==============================================================================
# ERROR HANDLING AND CLEANUP
# ==============================================================================

# Print stack trace for debugging
# Globals: BASH_SOURCE, FUNCNAME, BASH_LINENO
# Arguments: None
# Returns: None
print_stack_trace() {
    local frame=0
    error "Stack trace:"
    while [[ ${frame} -lt ${#FUNCNAME[@]} ]]; do
        local func="${FUNCNAME[$frame]}"
        local line="${BASH_LINENO[$((frame - 1))]}"
        local src="${BASH_SOURCE[$frame]}"
        
        if [[ "$func" != "print_stack_trace" ]] && [[ "$func" != "on_error" ]]; then
            error "  at ${func}() in ${src}:${line}"
        fi
        
        ((frame++)) || true
    done
}

# Handle command errors
# Globals: BASH_COMMAND, BASH_SOURCE, BASH_LINENO, VERBOSITY
# Arguments: None
# Returns: None
on_error() {
    local exit_code=$?
    error "Command failed with exit code ${exit_code}"
    error "  Line: ${BASH_LINENO[0]}"
    error "  Command: ${BASH_COMMAND}"
    
    # Print stack trace if debug verbosity
    if ((VERBOSITY >= V_DEBUG)); then
        print_stack_trace
    fi
}

# Handle signals (INT, TERM, HUP)
# Globals: None
# Arguments:
#   $1 - Signal name
# Returns: None
on_signal() {
    local signal=$1
    local exit_code=$((128 + $(kill -l "$signal")))
    error "Received signal: ${signal}"
    exit "$exit_code"
}

# Clean up resources on exit
# Globals: TEMP_FILES, TEMP_DIR
# Arguments: None
# Returns: None
cleanup() {
    local exit_code=$?
    
    # Remove temporary files
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        debug "Cleaning up ${#TEMP_FILES[@]} temporary file(s)"
        for file in "${TEMP_FILES[@]}"; do
            if [[ -f "$file" ]]; then
                rm -f "$file" 2>/dev/null || true
            fi
        done
    fi
    
    # Remove temporary directory
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        debug "Cleaning up temporary directory: ${TEMP_DIR}"
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    
    exit "$exit_code"
}

# Set up trap handlers
# Globals: None
# Arguments: None
# Returns: None
setup_traps() {
    trap cleanup EXIT
    trap on_error ERR
    trap 'on_signal INT' INT
    trap 'on_signal TERM' TERM
    trap 'on_signal HUP' HUP
}

# ==============================================================================
# FEATURE FLAG VALIDATION
# ==============================================================================

# Validate that script can run with current privileges
# Globals: REQUIRE_ROOT
# Arguments: None
# Returns: 0 if valid, exits on failure
validate_privileges() {
    if [[ "${REQUIRE_ROOT}" == true ]]; then
        if [[ $EUID -ne 0 ]]; then
            fatal "This script must be run as root (use sudo)" $E_NOPERM
        fi
        debug "Root privileges confirmed"
    else
        debug "Running without root privileges"
    fi
}

# Validate network connectivity if required
# Globals: REQUIRES_NETWORK
# Arguments: None
# Returns: 0 if network available or not required, exits on failure
validate_network() {
    if [[ "${REQUIRES_NETWORK}" == true ]]; then
        debug "Checking network connectivity..."
        
        # Try to reach a reliable host
        if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            fatal "Network connectivity required but not available" $E_UNAVAILABLE
        fi
        
        debug "Network connectivity confirmed"
    fi
}

# Validate available disk space if required
# Globals: REQUIRES_DISK_SPACE, DISK_SPACE_REQUIRED_MB
# Arguments: None
# Returns: 0 if sufficient space or not required, exits on failure
validate_disk_space() {
    if [[ "${REQUIRES_DISK_SPACE}" == true ]]; then
        local available_mb
        
        # Get available space in MB for /tmp
        available_mb=$(df -m /tmp | awk 'NR==2 {print $4}')
        
        debug "Available disk space: ${available_mb}MB, required: ${DISK_SPACE_REQUIRED_MB}MB"
        
        if ((available_mb < DISK_SPACE_REQUIRED_MB)); then
            fatal "Insufficient disk space: ${available_mb}MB available, ${DISK_SPACE_REQUIRED_MB}MB required" $E_IOERR
        fi
        
        debug "Sufficient disk space confirmed"
    fi
}

# Validate runtime environment restrictions
# Globals: CAN_RUN_IN_USERSPACE
# Arguments: None
# Returns: 0 if environment valid, exits on failure
validate_environment() {
    if [[ "${CAN_RUN_IN_USERSPACE}" == false ]]; then
        # Check if we're in a system directory
        case "$PWD" in
            /home/*|/tmp/*|/var/tmp/*)
                fatal "This script cannot run from user directories" $E_NOPERM
                ;;
        esac
        debug "Environment validation passed"
    fi
}

# ==============================================================================
# PLUGIN SYSTEM
# ==============================================================================

# Check if a plugin exists
# Globals: PLUGIN_DIR
# Arguments:
#   $1 - Plugin name
# Returns: 0 if exists, 1 if not
plugin_exists() {
    local plugin_name=$1
    [[ -d "${PLUGIN_DIR}/${plugin_name}" ]] && [[ -f "${PLUGIN_DIR}/${plugin_name}/plugin.conf" ]]
}

# Load a plugin's functions
# Globals: PLUGIN_DIR
# Arguments:
#   $1 - Plugin name
# Returns: 0 on success, 1 on failure
source_plugin() {
    local plugin_name=$1
    local plugin_path="${PLUGIN_DIR}/${plugin_name}"
    
    if ! plugin_exists "$plugin_name"; then
        warn "Plugin not found: ${plugin_name}"
        return 1
    fi
    
    debug "Loading plugin: ${plugin_name}"
    
    # Source plugin configuration
    # shellcheck disable=SC1090
    source "${plugin_path}/plugin.conf"
    
    # Source plugin functions if they exist
    if [[ -f "${plugin_path}/functions.sh" ]]; then
        # shellcheck disable=SC1090
        source "${plugin_path}/functions.sh"
    fi
    
    # Call plugin init if it exists
    if [[ -f "${plugin_path}/init.sh" ]]; then
        # shellcheck disable=SC1090
        source "${plugin_path}/init.sh"
    fi
    
    return 0
}

# Load all enabled plugins
# Globals: ENABLED_PLUGINS
# Arguments: None
# Returns: None
load_plugins() {
    if [[ -z "$ENABLED_PLUGINS" ]]; then
        debug "No plugins enabled"
        return 0
    fi
    
    debug "Loading plugins: ${ENABLED_PLUGINS}"
    
    # Split comma-separated list and load each plugin
    local IFS=','
    for plugin in $ENABLED_PLUGINS; do
        plugin=$(echo "$plugin" | xargs)  # Trim whitespace
        source_plugin "$plugin" || warn "Failed to load plugin: ${plugin}"
    done
}

# ==============================================================================
# DEPENDENCY VALIDATION
# ==============================================================================

# Check if a command exists
# Globals: None
# Arguments:
#   $1 - Command name
# Returns: 0 if exists, 1 if not
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get the first available command from a list
# Globals: None
# Arguments: Command names to try
# Returns: Path to first found command, or empty string
get_command() {
    for cmd in "$@"; do
        if command_exists "$cmd"; then
            command -v "$cmd"
            return 0
        fi
    done
    return 1
}

# Register and validate a required binary
# Globals: REQUIRED_BINARIES (modified)
# Arguments: Binary names (tries each in order)
# Returns: Exits if not found
require_binary() {
    local primary_name=$1
    local found_path
    
    found_path=$(get_command "$@")
    
    if [[ -z "$found_path" ]]; then
        error "Required binary not found: ${primary_name}"
        error "Tried: $*"
        error "Please install one of these packages:"
        error "  - Check your distribution's package manager"
        exit $E_UNAVAILABLE
    fi
    
    REQUIRED_BINARIES[$primary_name]=$found_path
    debug "Found required binary: ${primary_name} -> ${found_path}"
}

# Register and validate an optional binary
# Globals: OPTIONAL_BINARIES (modified)
# Arguments: Binary names (tries each in order)
# Returns: 0 if found, 1 if not
optional_binary() {
    local primary_name=$1
    local found_path
    
    found_path=$(get_command "$@")
    
    if [[ -n "$found_path" ]]; then
        OPTIONAL_BINARIES[$primary_name]=$found_path
        debug "Found optional binary: ${primary_name} -> ${found_path}"
        return 0
    fi
    
    debug "Optional binary not found: ${primary_name}"
    return 1
}

# Validate all dependencies
# Globals: HAS_EXTERNAL_DEPENDENCIES
# Arguments: None
# Returns: Exits if required dependencies missing
validate_dependencies() {
    if [[ "${HAS_EXTERNAL_DEPENDENCIES}" == false ]]; then
        debug "No external dependencies required"
        return 0
    fi
    
    debug "Validating dependencies..."
    
    # Required binaries (script will exit if any are missing)
    require_binary sed gsed
    require_binary awk gawk mawk
    
    # Optional binaries (script continues if missing)
    optional_binary bat cat
    
    debug "All required dependencies satisfied"
}

# ==============================================================================
# TEMP FILE MANAGEMENT
# ==============================================================================

# Create a temporary file and register for cleanup
# Globals: TEMP_FILES (modified)
# Arguments:
#   $1 - Optional suffix for temp file
# Returns: Path to temp file via stdout
create_temp_file() {
    local suffix="${1:-}"
    local temp_file
    
    if [[ -n "$suffix" ]]; then
        temp_file=$(mktemp "/tmp/${SCRIPT_NAME}.XXXXXX${suffix}")
    else
        temp_file=$(mktemp "/tmp/${SCRIPT_NAME}.XXXXXX")
    fi
    
    TEMP_FILES+=("$temp_file")
    debug "Created temp file: ${temp_file}"
    echo "$temp_file"
}

# Create a temporary directory and register for cleanup
# Globals: TEMP_DIR (modified)
# Arguments: None
# Returns: Path to temp directory via stdout
create_temp_dir() {
    # Only create one temp directory per script run
    if [[ -z "$TEMP_DIR" ]]; then
        TEMP_DIR=$(mktemp -d "/tmp/${SCRIPT_NAME}.XXXXXX")
        debug "Created temp directory: ${TEMP_DIR}"
    fi
    echo "$TEMP_DIR"
}

# ==============================================================================
# INPUT VALIDATION
# ==============================================================================

# Validate that a value is an integer
# Globals: None
# Arguments:
#   $1 - Value to validate
#   $2 - Minimum value (optional)
#   $3 - Maximum value (optional)
# Returns: 0 if valid, 1 if invalid
validate_integer() {
    local value=$1
    local min=${2:-}
    local max=${3:-}
    
    # Check if it's an integer
    if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
        return 1
    fi
    
    # Check minimum
    if [[ -n "$min" ]] && ((value < min)); then
        return 1
    fi
    
    # Check maximum
    if [[ -n "$max" ]] && ((value > max)); then
        return 1
    fi
    
    return 0
}

# Validate string length
# Globals: None
# Arguments:
#   $1 - String to validate
#   $2 - Minimum length (optional, default: 1)
#   $3 - Maximum length (optional)
# Returns: 0 if valid, 1 if invalid
validate_string() {
    local value=$1
    local min=${2:-1}
    local max=${3:-}
    local length=${#value}
    
    # Check minimum length
    if ((length < min)); then
        return 1
    fi
    
    # Check maximum length
    if [[ -n "$max" ]] && ((length > max)); then
        return 1
    fi
    
    return 0
}

# Validate that a file exists and is readable
# Globals: None
# Arguments:
#   $1 - File path
# Returns: 0 if valid, 1 if invalid
validate_file_readable() {
    local file=$1
    
    if [[ ! -f "$file" ]]; then
        error "File not found: ${file}"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        error "File not readable: ${file}"
        return 1
    fi
    
    return 0
}

# Validate that a directory exists and is writable
# Globals: None
# Arguments:
#   $1 - Directory path
# Returns: 0 if valid, 1 if invalid
validate_dir_writable() {
    local dir=$1
    
    if [[ ! -d "$dir" ]]; then
        error "Directory not found: ${dir}"
        return 1
    fi
    
    if [[ ! -w "$dir" ]]; then
        error "Directory not writable: ${dir}"
        return 1
    fi
    
    return 0
}

# Sanitize a string for use as a filename
# Globals: None
# Arguments:
#   $1 - String to sanitize
# Returns: Sanitized string via stdout
sanitize_filename() {
    local input=$1
    local sanitized
    
    # Replace non-alphanumeric characters (except . _ -) with underscore
    sanitized=$(echo "$input" | sed 's/[^[:alnum:]._-]/_/g')
    
    # Collapse multiple underscores
    sanitized=$(echo "$sanitized" | sed 's/__*/_/g')
    
    echo "$sanitized"
}

# ==============================================================================
# USAGE AND HELP
# ==============================================================================

# Display usage information (brief)
# Globals: SCRIPT_NAME
# Arguments: None
# Returns: None
usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] [ARGS]

Try '${SCRIPT_NAME} --help' for more information.
EOF
}

# Display detailed help information
# Globals: SCRIPT_NAME, SCRIPT_VERSION
# Arguments: None
# Returns: None
show_help() {
    cat <<EOF
${SCRIPT_NAME} ${SCRIPT_VERSION} - Brief description

Usage:
    ${SCRIPT_NAME} [OPTIONS] [ARGS]

Options:
    -h, --help              Show this help message and exit
    -V, --version           Show version information and exit
    -v, --verbose           Increase verbosity (repeatable: -vvv)
    -q, --quiet             Suppress non-error output
    -n, --dry-run           Show what would be done without executing
    -d, --debug             Enable debug mode (maximum verbosity + xtrace)
    -c, --config FILE       Specify configuration file
    -o, --output FILE       Specify output file
    --self-test             Run internal self-tests and exit

Arguments:
    Add your positional arguments here

Examples:
    ${SCRIPT_NAME} input.txt
    ${SCRIPT_NAME} -v --dry-run input.txt
    ${SCRIPT_NAME} --config custom.conf input.txt

Environment Variables:
    ${SCRIPT_NAME}_CONFIG_FILE    Configuration file path
    NO_COLOR                      Disable colored output

Exit Codes:
    0   Success
    1   General error
    2   Usage/syntax error
    66  Input file not found
    77  Permission denied
    78  Configuration error

For more information, see the documentation.
EOF
}

# Display version information
# Globals: SCRIPT_NAME, SCRIPT_VERSION, SCRIPT_AUTHOR
# Arguments: None
# Returns: None
show_version() {
    cat <<EOF
${SCRIPT_NAME} ${SCRIPT_VERSION}
Author: ${SCRIPT_AUTHOR}
License: CC BY-SA 4.0 - https://creativecommons.org/licenses/by-sa/4.0/
EOF
}

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================

# Parse command-line arguments
# Globals: VERBOSITY, DRY_RUN, CONFIG_FILE, OUTPUT_FILE, POSITIONAL_ARGS (modified)
# Arguments: All command-line arguments ($@)
# Returns: None, exits on invalid arguments
parse_arguments() {
    local positional_args=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit $E_SUCCESS
                ;;
            -V|--version)
                show_version
                exit $E_SUCCESS
                ;;
            -v|--verbose)
                ((VERBOSITY++)) || true
                shift
                ;;
            -q|--quiet)
                VERBOSITY=$V_QUIET
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                info "Dry-run mode enabled"
                shift
                ;;
            -d|--debug)
                VERBOSITY=$V_TRACE
                set -o xtrace
                shift
                ;;
            --self-test)
                RUN_SELF_TEST=true
                shift
                ;;
            -c|--config)
                if [[ -z "${2:-}" ]]; then
                    error "Option --config requires an argument"
                    usage
                    exit $E_USAGE
                fi
                CONFIG_FILE="$2"
                shift 2
                ;;
            --config=*)
                CONFIG_FILE="${1#*=}"
                shift
                ;;
            -o|--output)
                if [[ -z "${2:-}" ]]; then
                    error "Option --output requires an argument"
                    usage
                    exit $E_USAGE
                fi
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --output=*)
                OUTPUT_FILE="${1#*=}"
                shift
                ;;
            --)
                shift
                positional_args+=("$@")
                break
                ;;
            -*)
                error "Unknown option: $1"
                usage
                exit $E_USAGE
                ;;
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done
    
    POSITIONAL_ARGS=("${positional_args[@]}")
}

# Validate parsed arguments
# Globals: POSITIONAL_ARGS
# Arguments: None
# Returns: Exits if validation fails
validate_arguments() {
    # Add your argument validation here
    # Example:
    # if [[ ${#POSITIONAL_ARGS[@]} -lt 1 ]]; then
    #     error "At least one argument required"
    #     usage
    #     exit $E_USAGE
    # fi
    
    debug "Arguments validated"
}

# ==============================================================================
# DRY RUN SUPPORT
# ==============================================================================

# Execute or simulate a command based on DRY_RUN flag
# Globals: DRY_RUN
# Arguments: Command and arguments to execute
# Returns: Command exit code, or 0 in dry-run mode
run() {
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would execute: $*"
        return 0
    else
        "$@"
        return $?
    fi
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Load a single configuration file
# Globals: None
# Arguments:
#   $1 - Configuration file path
# Returns: 0 if loaded, 1 if not found or error
load_config() {
    local config_file=$1
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    if [[ ! -r "$config_file" ]]; then
        warn "Configuration file not readable: ${config_file}"
        return 1
    fi
    
    debug "Loading configuration: ${config_file}"
    
    # Source the configuration file
    # shellcheck disable=SC1090
    source "$config_file"
    
    return 0
}

# Load configuration files from hierarchy
# Globals: SCRIPT_NAME, CONFIG_FILE, USES_CONFIG_FILES
# Arguments: None
# Returns: None
load_configuration() {
    if [[ "${USES_CONFIG_FILES}" == false ]]; then
        debug "Configuration file loading disabled"
        return 0
    fi
    
    local config_name="${SCRIPT_NAME%.sh}"
    local -a config_paths=(
        "/etc/${config_name}/${config_name}.conf"
        "/etc/${config_name}.conf"
        "${HOME}/.config/${config_name}/${config_name}.conf"
        "${HOME}/.${config_name}.conf"
        "./${config_name}.conf"
    )
    
    # Add environment variable config
    local env_var="${config_name^^}"
    env_var="${env_var//[^A-Z0-9]/_}_CONFIG_FILE"
    if [[ -n "${!env_var:-}" ]]; then
        config_paths+=("${!env_var}")
    fi
    
    # Add command-line config (highest priority)
    if [[ -n "$CONFIG_FILE" ]]; then
        config_paths+=("$CONFIG_FILE")
    fi
    
    # Load configs in order (later ones override earlier)
    for config_path in "${config_paths[@]}"; do
        load_config "$config_path" || true
    done
}

# ==============================================================================
# SELF-TEST FUNCTIONS
# ==============================================================================

# Test validation functions
# Globals: None
# Arguments: None
# Returns: 0 if all tests pass, 1 if any fail
test_validation_functions() {
    local failed=0
    
    # Test validate_integer
    if ! validate_integer "42"; then
        error "Test failed: validate_integer with valid integer"
        ((failed++))
    fi
    
    if validate_integer "not_a_number"; then
        error "Test failed: validate_integer with invalid input"
        ((failed++))
    fi
    
    if ! validate_integer "50" 0 100; then
        error "Test failed: validate_integer with valid range"
        ((failed++))
    fi
    
    # Test validate_string
    if ! validate_string "hello"; then
        error "Test failed: validate_string with valid string"
        ((failed++))
    fi
    
    if validate_string "" 1; then
        error "Test failed: validate_string with empty string"
        ((failed++))
    fi
    
    if ((failed == 0)); then
        info "Validation function tests passed"
    fi
    
    return "$failed"
}

# Test dependency checking
# Globals: None
# Arguments: None
# Returns: 0 if all tests pass, 1 if any fail
test_dependency_check() {
    local failed=0
    
    # Test that basic commands are found
    if ! command_exists "sh"; then
        error "Test failed: command_exists with 'sh'"
        ((failed++))
    fi
    
    if command_exists "this_command_does_not_exist_12345"; then
        error "Test failed: command_exists with non-existent command"
        ((failed++))
    fi
    
    if ((failed == 0)); then
        info "Dependency check tests passed"
    fi
    
    return "$failed"
}

# Run all self-tests
# Globals: None
# Arguments: None
# Returns: 0 if all tests pass, exits with E_SOFTWARE if any fail
run_self_test() {
    local failed=0
    
    info "Running self-tests..."
    
    test_validation_functions || ((failed++))
    test_dependency_check || ((failed++))
    
    if ((failed == 0)); then
        msg "All self-tests passed"
        return 0
    else
        error "${failed} test suite(s) failed"
        exit $E_SOFTWARE
    fi
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

# Main function - implement your script logic here
# Globals: POSITIONAL_ARGS, OUTPUT_FILE
# Arguments: None
# Returns: Exit code
main() {
    debug "Starting main execution"
    
    # Example: Access positional arguments
    # local input_file="${POSITIONAL_ARGS[0]:-}"
    
    # Example: Check if we have required arguments
    # if [[ -z "$input_file" ]]; then
    #     error "Input file required"
    #     usage
    #     exit $E_USAGE
    # fi
    
    # Example: Validate input file
    # if ! validate_file_readable "$input_file"; then
    #     exit $E_NOINPUT
    # fi
    
    # YOUR CODE HERE
    info "Script execution completed"
    
    return $E_SUCCESS
}

# ==============================================================================
# INITIALIZATION AND ENTRY POINT
# ==============================================================================

# Initialize script
# Globals: Multiple (calls various init functions)
# Arguments: None
# Returns: None
init() {
    init_colors
    setup_traps
    debug "Initialization complete"
}

# Main entry point
# Globals: All
# Arguments: All command-line arguments ($@)
# Returns: Exit code from main()
_main() {
    init
    parse_arguments "$@"
    load_configuration
    
    # Run self-test if requested
    if [[ "$RUN_SELF_TEST" == true ]]; then
        run_self_test
        exit $?
    fi
    
    # Validate feature flag requirements
    validate_privileges
    validate_network
    validate_disk_space
    validate_environment
    
    # Load plugins
    load_plugins
    
    # Validate dependencies and arguments
    validate_dependencies
    validate_arguments
    
    # Run main logic
    main
    exit $?
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _main "$@"
fi

# ==============================================================================
# METADATA (Auto-generated by init-script - safe to remove)
# ==============================================================================
# This section contains structured metadata about the script configuration.
# It can be safely removed without affecting script functionality.
# JSON_METADATA_START
# {
#   "generator": "shell-script-templates-init",
#   "version": "4.0.0",
#   "created": "",
#   "script": {
#     "name": "script_name",
#     "version": "1.0.0",
#     "author": "",
#     "description": ""
#   }
# }
# JSON_METADATA_END
