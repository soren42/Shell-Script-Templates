#!/usr/bin/env bash
# shellcheck disable=SC2034  # Template defines variables for user implementation
#
# Template: v3.0 (20260124)
# script_name(1)
#
# Created by jason c. kay <j@son-kay.com>
# Copyright 2022-2026 jason c kay
# Some rights reserved.
#
# This work is licensed under the Creative Commons
# Attribution-ShareAlike 4.0 International License. To
# view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/4.0/.
#
# Description:
#   Brief description of what this script does.
#
# Usage:
#   script_name [OPTIONS] <argument>
#
# Options:
#   -h, --help      Show this help message and exit
#   -V, --version   Show version information and exit
#   -v, --verbose   Increase verbosity (can be repeated: -vvv)
#   -q, --quiet     Suppress all non-error output
#   -n, --dry-run   Show what would be done without doing it
#   -d, --debug     Enable debug mode (implies -vvv)
#
# Examples:
#   script_name file.txt
#   script_name -v --dry-run file.txt
#

# ==============================================================================
# STRICT MODE AND SHELL OPTIONS
# ==============================================================================

# Exit on error, undefined variable, pipe failure
set -o errexit
set -o nounset
set -o pipefail

# Debug mode: uncomment to trace execution
# set -o xtrace

# Bash 4.0+ required for associative arrays and other features
if ((BASH_VERSINFO[0] < 4)); then
    echo "Error: This script requires bash 4.0 or later" >&2
    exit 1
fi

# ==============================================================================
# CONSTANTS AND DEFAULTS
# ==============================================================================

# Script metadata
readonly SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_AUTHOR="jason c. kay <j@son-kay.com>"

# Exit codes (semantic meaning)
readonly E_SUCCESS=0
readonly E_GENERAL=1
readonly E_USAGE=2
readonly E_NOINPUT=66
readonly E_NOUSER=67
readonly E_NOHOST=68
readonly E_UNAVAILABLE=69
readonly E_SOFTWARE=70
readonly E_OSERR=71
readonly E_OSFILE=72
readonly E_CANTCREAT=73
readonly E_IOERR=74
readonly E_TEMPFAIL=75
readonly E_PROTOCOL=76
readonly E_NOPERM=77
readonly E_CONFIG=78

# Verbosity levels
readonly V_QUIET=0
readonly V_NORMAL=1
readonly V_VERBOSE=2
readonly V_DEBUG=3
readonly V_TRACE=4

# Colors (populated in init_colors)
declare -A COLORS=()

# ==============================================================================
# GLOBAL VARIABLES (mutable state)
# ==============================================================================

# Verbosity level (default: normal)
VERBOSITY=$V_NORMAL

# Dry run mode
DRY_RUN=false

# Temp files to clean up
declare -a TEMP_FILES=()

# Temp directory
TEMP_DIR=""

# Required binaries (name -> path)
declare -A REQUIRED_BINARIES=()

# Optional binaries (name -> path or empty)
declare -A OPTIONAL_BINARIES=()

# ==============================================================================
# LOGGING AND OUTPUT
# ==============================================================================

# Initialize terminal colors if supported
# Globals: COLORS
# Arguments: None
# Outputs: Populates COLORS associative array
init_colors() {
    if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
        COLORS=(
            [reset]='\033[0m'
            [bold]='\033[1m'
            [dim]='\033[2m'
            [red]='\033[0;31m'
            [green]='\033[0;32m'
            [yellow]='\033[0;33m'
            [blue]='\033[0;34m'
            [magenta]='\033[0;35m'
            [cyan]='\033[0;36m'
            [white]='\033[0;37m'
        )
    else
        COLORS=(
            [reset]='' [bold]='' [dim]=''
            [red]='' [green]='' [yellow]='' [blue]=''
            [magenta]='' [cyan]='' [white]=''
        )
    fi
}

# Print a formatted log message
# Globals: VERBOSITY, COLORS
# Arguments:
#   $1 - Log level (trace, debug, info, warn, error, fatal)
#   $2 - Message
# Outputs: Writes to stdout or stderr depending on level
_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    local color=""
    local prefix=""
    local min_verbosity=$V_NORMAL
    local output_fd=1

    case "$level" in
        trace)
            color="${COLORS[dim]}"
            prefix="TRACE"
            min_verbosity=$V_TRACE
            ;;
        debug)
            color="${COLORS[cyan]}"
            prefix="DEBUG"
            min_verbosity=$V_DEBUG
            ;;
        info)
            color="${COLORS[green]}"
            prefix="INFO"
            min_verbosity=$V_NORMAL
            ;;
        warn)
            color="${COLORS[yellow]}"
            prefix="WARN"
            min_verbosity=$V_NORMAL
            output_fd=2
            ;;
        error)
            color="${COLORS[red]}"
            prefix="ERROR"
            min_verbosity=$V_QUIET
            output_fd=2
            ;;
        fatal)
            color="${COLORS[red]}${COLORS[bold]}"
            prefix="FATAL"
            min_verbosity=$V_QUIET
            output_fd=2
            ;;
    esac

    if ((VERBOSITY >= min_verbosity)); then
        printf '%b[%s] [%s] %s%b\n' \
            "$color" "$timestamp" "$prefix" "$message" "${COLORS[reset]}" >&$output_fd
    fi
}

# Convenience logging functions
trace() { _log trace "$@"; }
debug() { _log debug "$@"; }
info()  { _log info "$@"; }
warn()  { _log warn "$@"; }
error() { _log error "$@"; }

# Print fatal error and exit
# Globals: None
# Arguments:
#   $1 - Error message
#   $2 - Exit code (optional, default: E_GENERAL)
# Outputs: Error message to stderr
# Returns: Never (exits)
fatal() {
    _log fatal "$1"
    exit "${2:-$E_GENERAL}"
}

# Print a message only if not in quiet mode
# Globals: VERBOSITY
# Arguments: Message to print
# Outputs: Message to stdout
msg() {
    if ((VERBOSITY >= V_NORMAL)); then
        printf '%s\n' "$*"
    fi
}

# Print a message without newline
# Globals: VERBOSITY
# Arguments: Message to print
# Outputs: Message to stdout (no newline)
msgn() {
    if ((VERBOSITY >= V_NORMAL)); then
        printf '%s' "$*"
    fi
}

# ==============================================================================
# ERROR HANDLING AND CLEANUP
# ==============================================================================

# Print stack trace
# Globals: BASH_SOURCE, FUNCNAME, BASH_LINENO
# Arguments: None
# Outputs: Stack trace to stderr
print_stack_trace() {
    local i
    error "Stack trace:"
    for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
        local func="${FUNCNAME[$i]}"
        local line="${BASH_LINENO[$((i - 1))]}"
        local src="${BASH_SOURCE[$i]}"
        error "  at ${func}() in ${src}:${line}"
    done
}

# Error handler for ERR trap
# Globals: BASH_COMMAND, BASH_LINENO
# Arguments: None
# Outputs: Error information to stderr
on_error() {
    local exit_code=$?
    local line_no="${BASH_LINENO[0]}"
    local command="$BASH_COMMAND"

    error "Command failed with exit code ${exit_code}"
    error "  Line: ${line_no}"
    error "  Command: ${command}"

    if ((VERBOSITY >= V_DEBUG)); then
        print_stack_trace
    fi
}

# Cleanup handler for EXIT trap
# Globals: TEMP_FILES, TEMP_DIR
# Arguments: None
# Outputs: None
cleanup() {
    local exit_code=$?

    # Remove temporary files
    local temp_file
    for temp_file in "${TEMP_FILES[@]:-}"; do
        if [[ -f "$temp_file" ]]; then
            debug "Removing temp file: ${temp_file}"
            rm -f "$temp_file"
        fi
    done

    # Remove temporary directory if it exists and is ours
    if [[ -n "${TEMP_DIR:-}" ]] && [[ -d "$TEMP_DIR" ]]; then
        debug "Removing temp directory: ${TEMP_DIR}"
        rm -rf "$TEMP_DIR"
    fi

    debug "Cleanup complete, exiting with code ${exit_code}"
    exit "$exit_code"
}

# Signal handler for INT/TERM
# Globals: None
# Arguments:
#   $1 - Signal name
# Outputs: Message to stderr
on_signal() {
    local signal="$1"
    error "Caught signal: ${signal}"
    exit $((128 + $(kill -l "$signal")))
}

# Set up all traps
# Globals: None
# Arguments: None
# Outputs: None
setup_traps() {
    trap cleanup EXIT
    trap on_error ERR
    trap 'on_signal INT' INT
    trap 'on_signal TERM' TERM
    trap 'on_signal HUP' HUP
}

# ==============================================================================
# DEPENDENCY VALIDATION
# ==============================================================================

# Check if a command exists and is executable
# Globals: None
# Arguments:
#   $1 - Command name
# Returns: 0 if command exists, 1 otherwise
command_exists() {
    command -v "$1" &>/dev/null
}

# Get the path to a command, preferring certain implementations
# Globals: None
# Arguments:
#   $@ - Command names in order of preference
# Outputs: Path to first found command
# Returns: 0 if found, 1 if none found
get_command() {
    local cmd
    for cmd in "$@"; do
        if command -v "$cmd" &>/dev/null; then
            command -v "$cmd"
            return 0
        fi
    done
    return 1
}

# Validate a required binary exists
# Globals: REQUIRED_BINARIES
# Arguments:
#   $1 - Binary name
#   $2 - Optional: alternative binary names
# Outputs: Error message if not found
# Returns: 0 if found, exits on failure
require_binary() {
    local name="$1"
    shift
    local alternatives=("$name" "$@")
    local path

    if path=$(get_command "${alternatives[@]}"); then
        REQUIRED_BINARIES["$name"]="$path"
        debug "Found required binary: ${name} -> ${path}"
        return 0
    fi

    error "Required binary not found: ${name}"
    error "Tried: ${alternatives[*]}"
    error "Please install one of these packages:"
    case "$name" in
        gawk|awk)
            error "  - Debian/Ubuntu: apt install gawk"
            error "  - macOS: brew install gawk"
            error "  - RHEL/CentOS: yum install gawk"
            ;;
        gsed|sed)
            error "  - Debian/Ubuntu: apt install sed"
            error "  - macOS: brew install gnu-sed"
            ;;
        *)
            error "  - Check your distribution's package manager"
            ;;
    esac
    exit $E_UNAVAILABLE
}

# Register an optional binary (won't fail if missing)
# Globals: OPTIONAL_BINARIES
# Arguments:
#   $1 - Binary name
#   $2 - Optional: alternative binary names
# Outputs: None
# Returns: 0 if found, 1 if not found
optional_binary() {
    local name="$1"
    shift
    local alternatives=("$name" "$@")
    local path

    if path=$(get_command "${alternatives[@]}"); then
        OPTIONAL_BINARIES["$name"]="$path"
        debug "Found optional binary: ${name} -> ${path}"
        return 0
    fi

    OPTIONAL_BINARIES["$name"]=""
    debug "Optional binary not found: ${name}"
    return 1
}

# Validate all required dependencies
# Globals: REQUIRED_BINARIES, OPTIONAL_BINARIES
# Arguments: None
# Outputs: Error messages for missing dependencies
validate_dependencies() {
    debug "Validating dependencies..."

    # Required binaries (script will exit if any are missing)
    require_binary sed gsed
    require_binary awk gawk mawk

    # Optional binaries (script continues if missing)
    optional_binary jq || warn "jq not found, JSON output disabled"

    debug "All required dependencies satisfied"
}

# ==============================================================================
# TEMP FILE MANAGEMENT
# ==============================================================================

# Create a temporary file and register it for cleanup
# Globals: TEMP_FILES
# Arguments:
#   $1 - Optional suffix for the temp file
# Outputs: Path to the temp file
# Returns: 0 on success, exits on failure
create_temp_file() {
    local suffix="${1:-}"
    local temp_file

    temp_file=$(mktemp "${TMPDIR:-/tmp}/${SCRIPT_NAME}.XXXXXX${suffix}") || {
        fatal "Failed to create temporary file" $E_CANTCREAT
    }

    TEMP_FILES+=("$temp_file")
    debug "Created temp file: ${temp_file}"
    printf '%s' "$temp_file"
}

# Create a temporary directory and register it for cleanup
# Globals: TEMP_DIR
# Arguments: None
# Outputs: Path to the temp directory
# Returns: 0 on success, exits on failure
create_temp_dir() {
    if [[ -n "${TEMP_DIR:-}" ]]; then
        printf '%s' "$TEMP_DIR"
        return 0
    fi

    TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/${SCRIPT_NAME}.XXXXXX") || {
        fatal "Failed to create temporary directory" $E_CANTCREAT
    }

    debug "Created temp directory: ${TEMP_DIR}"
    printf '%s' "$TEMP_DIR"
}

# ==============================================================================
# INPUT VALIDATION
# ==============================================================================

# Validate that a value is an integer
# Globals: None
# Arguments:
#   $1 - Value to validate
#   $2 - Optional minimum value
#   $3 - Optional maximum value
# Returns: 0 if valid, 1 if invalid
validate_integer() {
    local value="$1"
    local min="${2:-}"
    local max="${3:-}"

    # Check if it's a valid integer (including negative)
    if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
        return 1
    fi

    # Check minimum bound
    if [[ -n "$min" ]] && ((value < min)); then
        return 1
    fi

    # Check maximum bound
    if [[ -n "$max" ]] && ((value > max)); then
        return 1
    fi

    return 0
}

# Validate that a value is a non-empty string
# Globals: None
# Arguments:
#   $1 - Value to validate
#   $2 - Optional minimum length
#   $3 - Optional maximum length
# Returns: 0 if valid, 1 if invalid
validate_string() {
    local value="$1"
    local min_len="${2:-1}"
    local max_len="${3:-}"

    local len=${#value}

    if ((len < min_len)); then
        return 1
    fi

    if [[ -n "$max_len" ]] && ((len > max_len)); then
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
    local file="$1"

    if [[ ! -e "$file" ]]; then
        error "File does not exist: ${file}"
        return 1
    fi

    if [[ ! -f "$file" ]]; then
        error "Not a regular file: ${file}"
        return 1
    fi

    if [[ ! -r "$file" ]]; then
        error "File is not readable: ${file}"
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
    local dir="$1"

    if [[ ! -e "$dir" ]]; then
        error "Directory does not exist: ${dir}"
        return 1
    fi

    if [[ ! -d "$dir" ]]; then
        error "Not a directory: ${dir}"
        return 1
    fi

    if [[ ! -w "$dir" ]]; then
        error "Directory is not writable: ${dir}"
        return 1
    fi

    return 0
}

# Sanitize a string for use as a filename
# Globals: None
# Arguments:
#   $1 - String to sanitize
# Outputs: Sanitized string
sanitize_filename() {
    local input="$1"
    # Remove or replace problematic characters
    printf '%s' "$input" | tr -cs '[:alnum:]._-' '_' | tr -s '_'
}

# ==============================================================================
# USAGE AND HELP
# ==============================================================================

# Print brief usage message
# Globals: SCRIPT_NAME
# Arguments: None
# Outputs: Usage line to stderr
usage() {
    cat >&2 <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] <argument>
Try '${SCRIPT_NAME} --help' for more information.
EOF
}

# Print full help message
# Globals: SCRIPT_NAME, SCRIPT_VERSION, SCRIPT_AUTHOR
# Arguments: None
# Outputs: Help text to stdout
show_help() {
    cat <<EOF
${SCRIPT_NAME} - Brief description of what this script does

Usage:
    ${SCRIPT_NAME} [OPTIONS] <argument>

Options:
    -h, --help              Show this help message and exit
    -V, --version           Show version information and exit
    -v, --verbose           Increase verbosity level (can be repeated)
    -q, --quiet             Suppress all non-error output
    -n, --dry-run           Show what would be done without doing it
    -d, --debug             Enable debug mode (implies maximum verbosity)
    -c, --config FILE       Use specified configuration file
    -o, --output FILE       Write output to FILE instead of stdout

Arguments:
    argument                Description of the required argument

Examples:
    ${SCRIPT_NAME} file.txt
        Process file.txt with default settings

    ${SCRIPT_NAME} -v --dry-run file.txt
        Show what would be done to file.txt without actually doing it

    ${SCRIPT_NAME} -vvv file.txt
        Process file.txt with maximum verbosity

Exit Codes:
    0   Success
    1   General error
    2   Usage/syntax error
    66  Input file not found
    77  Permission denied
    78  Configuration error

Report bugs to: ${SCRIPT_AUTHOR}
EOF
}

# Print version information
# Globals: SCRIPT_NAME, SCRIPT_VERSION
# Arguments: None
# Outputs: Version info to stdout
show_version() {
    cat <<EOF
${SCRIPT_NAME} version ${SCRIPT_VERSION}
EOF
}

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================

# Parse command-line arguments
# Globals: VERBOSITY, DRY_RUN
# Arguments: Command line arguments "$@"
# Outputs: Error messages for invalid arguments
# Returns: Sets global variables based on arguments
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
            -vv)
                VERBOSITY=$V_VERBOSE
                shift
                ;;
            -vvv)
                VERBOSITY=$V_DEBUG
                shift
                ;;
            -q|--quiet)
                VERBOSITY=$V_QUIET
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -d|--debug)
                VERBOSITY=$V_TRACE
                set -o xtrace
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
                # End of options
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

    # Store positional arguments in a global array
    POSITIONAL_ARGS=("${positional_args[@]}")

    debug "Verbosity level: ${VERBOSITY}"
    debug "Dry run: ${DRY_RUN}"
    debug "Positional arguments: ${POSITIONAL_ARGS[*]:-none}"
}

# Validate parsed arguments
# Globals: POSITIONAL_ARGS
# Arguments: None
# Outputs: Error messages for missing/invalid arguments
# Returns: 0 on success, exits on failure
validate_arguments() {
    # Example: require at least one positional argument
    # Uncomment and customize as needed:
    #
    # if [[ ${#POSITIONAL_ARGS[@]} -lt 1 ]]; then
    #     error "Missing required argument"
    #     usage
    #     exit $E_USAGE
    # fi

    # Example: validate first argument is a readable file
    # if [[ ${#POSITIONAL_ARGS[@]} -ge 1 ]]; then
    #     if ! validate_file_readable "${POSITIONAL_ARGS[0]}"; then
    #         exit $E_NOINPUT
    #     fi
    # fi

    debug "Arguments validated successfully"
}

# ==============================================================================
# DRY RUN SUPPORT
# ==============================================================================

# Execute a command, or just print it if in dry-run mode
# Globals: DRY_RUN
# Arguments:
#   $@ - Command and arguments to execute
# Outputs: Command output or dry-run message
# Returns: Command exit code, or 0 in dry-run mode
run() {
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would execute: $*"
        return 0
    fi

    debug "Executing: $*"
    "$@"
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Load configuration from file
# Globals: CONFIG_FILE
# Arguments:
#   $1 - Configuration file path
# Outputs: Debug messages
# Returns: 0 on success, 1 if file not found
load_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        debug "Configuration file not found: ${config_file}"
        return 1
    fi

    if [[ ! -r "$config_file" ]]; then
        warn "Configuration file not readable: ${config_file}"
        return 1
    fi

    debug "Loading configuration from: ${config_file}"

    # Source the config file in a subshell first to validate it
    if ! bash -n "$config_file" 2>/dev/null; then
        error "Syntax error in configuration file: ${config_file}"
        return 1
    fi

    # shellcheck source=/dev/null
    source "$config_file"
    return 0
}

# Load configuration from standard locations
# Globals: SCRIPT_NAME, CONFIG_FILE
# Arguments: None
# Outputs: Debug messages
load_configuration() {
    local config_name="${SCRIPT_NAME%.sh}"
    local config_locations=(
        "/etc/${config_name}/${config_name}.conf"
        "/etc/${config_name}.conf"
        "${HOME}/.config/${config_name}/${config_name}.conf"
        "${HOME}/.${config_name}.conf"
        "./${config_name}.conf"
    )

    # Add environment-specified config file
    local env_var="${config_name^^}_CONFIG_FILE"
    env_var="${env_var//-/_}"
    if [[ -n "${!env_var:-}" ]]; then
        config_locations+=("${!env_var}")
    fi

    # Add command-line specified config file (highest priority)
    if [[ -n "${CONFIG_FILE:-}" ]]; then
        if ! load_config "$CONFIG_FILE"; then
            fatal "Cannot load specified configuration file: ${CONFIG_FILE}" $E_CONFIG
        fi
        return 0
    fi

    # Load configs in order (later ones override earlier)
    local config
    for config in "${config_locations[@]}"; do
        load_config "$config" || true
    done
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

# Main function - implement your script logic here
# Globals: POSITIONAL_ARGS, DRY_RUN, VERBOSITY
# Arguments: None
# Outputs: Script output
# Returns: 0 on success, non-zero on failure
main() {
    debug "Starting main execution"

    # Example: process positional arguments
    local arg
    for arg in "${POSITIONAL_ARGS[@]:-}"; do
        info "Processing: ${arg}"
        # Add your processing logic here
    done

    # Example: demonstrate dry-run support
    # run some_command --with-args

    info "Script completed successfully"
    return $E_SUCCESS
}

# ==============================================================================
# INITIALIZATION AND ENTRY POINT
# ==============================================================================

# Initialize the script environment
# Globals: All
# Arguments: None
init() {
    # Initialize colors first (for logging)
    init_colors

    # Set up error and cleanup handlers
    setup_traps

    debug "Initializing ${SCRIPT_NAME} v${SCRIPT_VERSION}"
    debug "Running on: $(uname -s) $(uname -r)"
    debug "Bash version: ${BASH_VERSION}"
    debug "Script directory: ${SCRIPT_DIR}"
}

# Entry point
# Globals: None
# Arguments: Command line arguments "$@"
_main() {
    # Initialize environment
    init

    # Parse command-line arguments
    parse_arguments "$@"

    # Load configuration files
    load_configuration

    # Validate dependencies
    validate_dependencies

    # Validate arguments after config is loaded
    validate_arguments

    # Run main logic
    main

    # Exit with success (cleanup happens via trap)
    exit $E_SUCCESS
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _main "$@"
fi
