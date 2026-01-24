#!/usr/bin/env zsh
# -*- mode: zsh; sh-shell: zsh; -*-
# zsh-specific: shellcheck does not apply to zsh scripts
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
# Compilation:
#   This script is designed to be compatible with zcompile.
#   To compile: zcompile template.zsh
#   This creates template.zsh.zwc (zsh word code) for faster loading.
#
# IMPORTANT: Zsh variable naming caveat:
#   Do NOT use 'path' as a local variable name in functions that invoke
#   subshells (e.g., $(...)). In zsh, 'local path' shadows the global $PATH
#   and causes command lookups to fail in subshells. Use 'cmd_path' or
#   similar instead.

# ==============================================================================
# ZSH STRICT MODE AND SHELL OPTIONS
# ==============================================================================

# Ensure we're running in zsh and set local options
# emulate -L zsh ensures this function/script uses zsh mode with local options
emulate -L zsh

# Core strict mode options (equivalent to bash set -euo pipefail)
setopt ERR_EXIT          # Exit on error (like set -e)
setopt NO_UNSET          # Error on undefined variables (like set -u)
setopt PIPE_FAIL         # Fail on first error in pipeline (like set -o pipefail)

# Additional safety options
setopt WARN_CREATE_GLOBAL    # Warn if a global is created in a function
setopt NO_CLOBBER            # Don't overwrite files with > (use >| to override)
setopt LOCAL_OPTIONS         # Options set in functions are local
setopt LOCAL_TRAPS           # Traps set in functions are local
setopt LOCAL_PATTERNS        # Patterns set in functions are local

# Useful zsh options for scripting
setopt EXTENDED_GLOB         # Enable extended globbing (#, ~, ^, etc.)
setopt NO_NOMATCH            # Don't error if glob pattern has no matches
setopt NUMERIC_GLOB_SORT     # Sort numeric filenames numerically
setopt RC_QUOTES             # Allow '' inside single quotes to represent '
setopt FUNCTION_ARGZERO      # Set $0 to function name in functions
setopt C_BASES               # Output hex as 0xFF not 16#FF
setopt MULTIOS               # Allow multiple redirections

# Debug mode: uncomment to trace execution
# setopt XTRACE

# Check zsh version (5.0+ required for full feature set)
if [[ ${ZSH_VERSION%%.*} -lt 5 ]]; then
    print -u2 "Error: This script requires zsh 5.0 or later (found: ${ZSH_VERSION})"
    exit 1
fi

# ==============================================================================
# CONSTANTS AND DEFAULTS
# ==============================================================================

# Script metadata
# ${(%):-%x} is the zsh way to get the script path (like ${BASH_SOURCE[0]})
# In sourced scripts, use ${(%):-%N} for the sourced file path
typeset -gr SCRIPT_NAME="${${(%):-%x}:t}"
typeset -gr SCRIPT_DIR="${${(%):-%x}:A:h}"
typeset -gr SCRIPT_VERSION="3.0.0"
typeset -gr SCRIPT_AUTHOR="jason c. kay <j@son-kay.com>"

# Exit codes (semantic meaning) - BSD sysexits.h compatible
typeset -gri E_SUCCESS=0
typeset -gri E_GENERAL=1
typeset -gri E_USAGE=2
typeset -gri E_NOINPUT=66
typeset -gri E_NOUSER=67
typeset -gri E_NOHOST=68
typeset -gri E_UNAVAILABLE=69
typeset -gri E_SOFTWARE=70
typeset -gri E_OSERR=71
typeset -gri E_OSFILE=72
typeset -gri E_CANTCREAT=73
typeset -gri E_IOERR=74
typeset -gri E_TEMPFAIL=75
typeset -gri E_PROTOCOL=76
typeset -gri E_NOPERM=77
typeset -gri E_CONFIG=78

# Verbosity levels
typeset -gri V_QUIET=0
typeset -gri V_NORMAL=1
typeset -gri V_VERBOSE=2
typeset -gri V_DEBUG=3
typeset -gri V_TRACE=4

# Colors (populated in init_colors)
# Using typeset -gA for global associative array
typeset -gA COLORS

# ==============================================================================
# GLOBAL VARIABLES (mutable state)
# ==============================================================================

# Verbosity level (default: normal)
typeset -gi VERBOSITY=$V_NORMAL

# Dry run mode
typeset -g DRY_RUN=false

# Temp files to clean up (array)
typeset -ga TEMP_FILES=()

# Temp directory
typeset -g TEMP_DIR=""

# Required binaries (name -> path)
typeset -gA REQUIRED_BINARIES=()

# Optional binaries (name -> path or empty)
typeset -gA OPTIONAL_BINARIES=()

# Positional arguments (populated by parse_arguments)
typeset -ga POSITIONAL_ARGS=()

# Configuration file path
typeset -g CONFIG_FILE=""

# Output file path
typeset -g OUTPUT_FILE=""

# ==============================================================================
# LOGGING AND OUTPUT
# ==============================================================================

# Initialize terminal colors if supported
# Globals: COLORS
# Arguments: None
# Outputs: Populates COLORS associative array
init_colors() {
    emulate -L zsh

    if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
        COLORS=(
            reset   $'\033[0m'
            bold    $'\033[1m'
            dim     $'\033[2m'
            red     $'\033[0;31m'
            green   $'\033[0;32m'
            yellow  $'\033[0;33m'
            blue    $'\033[0;34m'
            magenta $'\033[0;35m'
            cyan    $'\033[0;36m'
            white   $'\033[0;37m'
        )
    else
        COLORS=(
            reset '' bold '' dim ''
            red '' green '' yellow '' blue ''
            magenta '' cyan '' white ''
        )
    fi
}

# Print a formatted log message
# Globals: VERBOSITY, COLORS
# Arguments:
#   $1 - Log level (trace, debug, info, warn, error, fatal)
#   $2+ - Message
# Outputs: Writes to stdout or stderr depending on level
_log() {
    emulate -L zsh
    local level=$1
    shift
    local message="$*"
    local timestamp
    # Use zsh's date formatting via strftime
    zmodload -F zsh/datetime b:strftime
    strftime -s timestamp '%Y-%m-%d %H:%M:%S'

    local color prefix min_verbosity output_fd=1

    case $level in
        trace)
            color=${COLORS[dim]}
            prefix="TRACE"
            min_verbosity=$V_TRACE
            ;;
        debug)
            color=${COLORS[cyan]}
            prefix="DEBUG"
            min_verbosity=$V_DEBUG
            ;;
        info)
            color=${COLORS[green]}
            prefix="INFO"
            min_verbosity=$V_NORMAL
            ;;
        warn)
            color=${COLORS[yellow]}
            prefix="WARN"
            min_verbosity=$V_NORMAL
            output_fd=2
            ;;
        error)
            color=${COLORS[red]}
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

    if (( VERBOSITY >= min_verbosity )); then
        # Use print -u for file descriptor, -P for prompt expansion
        print -u $output_fd "${color}[${timestamp}] [${prefix}] ${message}${COLORS[reset]}"
    fi
}

# Convenience logging functions
trace() { _log trace "$@" }
debug() { _log debug "$@" }
info()  { _log info "$@" }
warn()  { _log warn "$@" }
error() { _log error "$@" }

# Print fatal error and exit
# Globals: None
# Arguments:
#   $1 - Error message
#   $2 - Exit code (optional, default: E_GENERAL)
# Outputs: Error message to stderr
# Returns: Never (exits)
fatal() {
    emulate -L zsh
    _log fatal "$1"
    exit ${2:-$E_GENERAL}
}

# Print a message only if not in quiet mode
# Globals: VERBOSITY
# Arguments: Message to print
# Outputs: Message to stdout
msg() {
    emulate -L zsh
    if (( VERBOSITY >= V_NORMAL )); then
        print -- "$*"
    fi
}

# Print a message without newline
# Globals: VERBOSITY
# Arguments: Message to print
# Outputs: Message to stdout (no newline)
msgn() {
    emulate -L zsh
    if (( VERBOSITY >= V_NORMAL )); then
        print -n -- "$*"
    fi
}

# ==============================================================================
# ERROR HANDLING AND CLEANUP
# ==============================================================================

# Print stack trace using zsh's funcstack and funcsourcetrace
# Globals: funcstack, funcsourcetrace
# Arguments: None
# Outputs: Stack trace to stderr
print_stack_trace() {
    emulate -L zsh
    error "Stack trace:"

    local i
    for (( i = 1; i <= ${#funcstack[@]}; i++ )); do
        local func="${funcstack[$i]}"
        local source="${funcsourcetrace[$i]}"
        error "  at ${func}() in ${source}"
    done
}

# TRAPZERR: Called on non-zero exit from a command (like bash ERR trap)
# This is a special zsh trap function
TRAPZERR() {
    emulate -L zsh
    local exit_code=$?

    # Don't trigger on intentional failures in conditionals
    # Check if we're in a conditional context
    [[ -o ERR_EXIT ]] || return 0

    error "Command failed with exit code ${exit_code}"
    error "  Function: ${funcstack[2]:-main}"
    error "  Source: ${funcsourcetrace[2]:-unknown}"

    if (( VERBOSITY >= V_DEBUG )); then
        print_stack_trace
    fi
}

# TRAPEXIT: Called on script exit (like bash EXIT trap)
# This is a special zsh trap function
TRAPEXIT() {
    emulate -L zsh
    local exit_code=$?

    # Remove temporary files
    local temp_file
    for temp_file in "${TEMP_FILES[@]}"; do
        if [[ -f "$temp_file" ]]; then
            debug "Removing temp file: ${temp_file}"
            rm -f "$temp_file" 2>/dev/null
        fi
    done

    # Remove temporary directory if it exists and is ours
    if [[ -n "${TEMP_DIR:-}" ]] && [[ -d "$TEMP_DIR" ]]; then
        debug "Removing temp directory: ${TEMP_DIR}"
        rm -rf "$TEMP_DIR" 2>/dev/null
    fi

    debug "Cleanup complete, exiting with code ${exit_code}"
    return $exit_code
}

# TRAPINT: Called on SIGINT (Ctrl+C)
TRAPINT() {
    emulate -L zsh
    error "Caught signal: INT"
    # Return 128 + signal number (SIGINT = 2)
    return $(( 128 + 2 ))
}

# TRAPTERM: Called on SIGTERM
TRAPTERM() {
    emulate -L zsh
    error "Caught signal: TERM"
    # Return 128 + signal number (SIGTERM = 15)
    return $(( 128 + 15 ))
}

# TRAPHUP: Called on SIGHUP
TRAPHUP() {
    emulate -L zsh
    error "Caught signal: HUP"
    # Return 128 + signal number (SIGHUP = 1)
    return $(( 128 + 1 ))
}

# Setup traps (mostly handled by TRAP* functions, but we can add more here)
# Globals: None
# Arguments: None
# Outputs: None
setup_traps() {
    emulate -L zsh
    # The TRAP* functions are automatically recognized by zsh
    # We can add additional traps here if needed
    debug "Trap handlers configured"
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
    emulate -L zsh
    (( $+commands[$1] ))
}

# Get the path to a command, preferring certain implementations
# Globals: None
# Arguments:
#   $@ - Command names in order of preference
# Outputs: Path to first found command
# Returns: 0 if found, 1 if none found
# Uses reply convention: sets reply to the path
get_command() {
    emulate -L zsh
    local cmd
    for cmd in "$@"; do
        if (( $+commands[$cmd] )); then
            print -- "${commands[$cmd]}"
            return 0
        fi
    done
    return 1
}

# Validate a required binary exists
# Globals: REQUIRED_BINARIES
# Arguments:
#   $1 - Binary name
#   $2+ - Optional: alternative binary names
# Outputs: Error message if not found
# Returns: 0 if found, exits on failure
require_binary() {
    emulate -L zsh
    local name=$1
    shift
    local -a alternatives=("$name" "$@")
    # IMPORTANT: Do not use 'path' as variable name - it shadows $PATH in subshells
    local cmd_path

    if cmd_path=$(get_command "${alternatives[@]}"); then
        REQUIRED_BINARIES[$name]=$cmd_path
        debug "Found required binary: ${name} -> ${cmd_path}"
        return 0
    fi

    error "Required binary not found: ${name}"
    error "Tried: ${(j:, :)alternatives}"
    error "Please install one of these packages:"
    case $name in
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
#   $2+ - Optional: alternative binary names
# Outputs: None
# Returns: 0 if found, 1 if not found
optional_binary() {
    emulate -L zsh
    local name=$1
    shift
    local -a alternatives=("$name" "$@")
    # IMPORTANT: Do not use 'path' as variable name - it shadows $PATH in subshells
    local cmd_path

    if cmd_path=$(get_command "${alternatives[@]}"); then
        OPTIONAL_BINARIES[$name]=$cmd_path
        debug "Found optional binary: ${name} -> ${cmd_path}"
        return 0
    fi

    OPTIONAL_BINARIES[$name]=""
    debug "Optional binary not found: ${name}"
    return 1
}

# Validate all required dependencies
# Globals: REQUIRED_BINARIES, OPTIONAL_BINARIES
# Arguments: None
# Outputs: Error messages for missing dependencies
validate_dependencies() {
    emulate -L zsh
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
    emulate -L zsh
    local suffix=${1:-}
    local temp_file

    temp_file=$(mktemp "${TMPDIR:-/tmp}/${SCRIPT_NAME}.XXXXXX${suffix}") || {
        fatal "Failed to create temporary file" $E_CANTCREAT
    }

    TEMP_FILES+=("$temp_file")
    debug "Created temp file: ${temp_file}"
    print -- "$temp_file"
}

# Create a temporary directory and register it for cleanup
# Globals: TEMP_DIR
# Arguments: None
# Outputs: Path to the temp directory
# Returns: 0 on success, exits on failure
create_temp_dir() {
    emulate -L zsh

    if [[ -n "${TEMP_DIR:-}" ]]; then
        print -- "$TEMP_DIR"
        return 0
    fi

    TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/${SCRIPT_NAME}.XXXXXX") || {
        fatal "Failed to create temporary directory" $E_CANTCREAT
    }

    debug "Created temp directory: ${TEMP_DIR}"
    print -- "$TEMP_DIR"
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
    emulate -L zsh
    local value=$1
    local min=${2:-}
    local max=${3:-}

    # Check if it's a valid integer (including negative) using zsh pattern
    [[ $value == <-> ]] || [[ $value == -<-> ]] || return 1

    # Check minimum bound (zsh native arithmetic)
    [[ -z $min ]] || (( value >= min )) || return 1

    # Check maximum bound
    [[ -z $max ]] || (( value <= max )) || return 1

    return 0
}

# Validate that a value is a floating point number
# Globals: None
# Arguments:
#   $1 - Value to validate
#   $2 - Optional minimum value
#   $3 - Optional maximum value
# Returns: 0 if valid, 1 if invalid
validate_float() {
    emulate -L zsh
    local value=$1
    local min=${2:-}
    local max=${3:-}

    # zsh natively supports floating point
    # Check if it's a valid float using zsh floating point arithmetic
    local -F num
    num=$value 2>/dev/null || return 1

    # Check bounds using native float comparison
    [[ -z $min ]] || (( num >= min )) || return 1
    [[ -z $max ]] || (( num <= max )) || return 1

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
    emulate -L zsh
    local value=$1
    local min_len=${2:-1}
    local max_len=${3:-}

    # Use zsh's ${#var} for length
    local len=${#value}

    (( len >= min_len )) || return 1
    [[ -z $max_len ]] || (( len <= max_len )) || return 1

    return 0
}

# Validate that a file exists and is readable
# Globals: None
# Arguments:
#   $1 - File path
# Returns: 0 if valid, 1 if invalid
validate_file_readable() {
    emulate -L zsh
    local file=$1

    if [[ ! -e $file ]]; then
        error "File does not exist: ${file}"
        return 1
    fi

    if [[ ! -f $file ]]; then
        error "Not a regular file: ${file}"
        return 1
    fi

    if [[ ! -r $file ]]; then
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
    emulate -L zsh
    local dir=$1

    if [[ ! -e $dir ]]; then
        error "Directory does not exist: ${dir}"
        return 1
    fi

    if [[ ! -d $dir ]]; then
        error "Not a directory: ${dir}"
        return 1
    fi

    if [[ ! -w $dir ]]; then
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
    emulate -L zsh
    local input=$1
    # Use zsh parameter expansion to replace problematic characters
    # ${var//pattern/replacement} for global substitution
    local sanitized=${input//[^[:alnum:]._-]/_}
    # Collapse multiple underscores
    sanitized=${sanitized//_(#c2,)/_}
    print -- "$sanitized"
}

# ==============================================================================
# USAGE AND HELP
# ==============================================================================

# Print brief usage message
# Globals: SCRIPT_NAME
# Arguments: None
# Outputs: Usage line to stderr
usage() {
    emulate -L zsh
    print -u2 "Usage: ${SCRIPT_NAME} [OPTIONS] <argument>"
    print -u2 "Try '${SCRIPT_NAME} --help' for more information."
}

# Print full help message
# Globals: SCRIPT_NAME, SCRIPT_VERSION, SCRIPT_AUTHOR
# Arguments: None
# Outputs: Help text to stdout
show_help() {
    emulate -L zsh
    # Using print with here-doc
    print -r -- "\
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

Report bugs to: ${SCRIPT_AUTHOR}"
}

# Print version information
# Globals: SCRIPT_NAME, SCRIPT_VERSION
# Arguments: None
# Outputs: Version info to stdout
show_version() {
    emulate -L zsh
    print "${SCRIPT_NAME} version ${SCRIPT_VERSION}"
}

# ==============================================================================
# ARGUMENT PARSING (using zparseopts)
# ==============================================================================

# Parse command-line arguments using zparseopts
# Globals: VERBOSITY, DRY_RUN, CONFIG_FILE, OUTPUT_FILE, POSITIONAL_ARGS
# Arguments: Command line arguments "$@"
# Outputs: Error messages for invalid arguments
# Returns: Sets global variables based on arguments
parse_arguments() {
    emulate -L zsh

    # Load zsh/zutil for zparseopts
    zmodload zsh/zutil

    # Define option arrays for zparseopts
    local -a opt_help opt_version opt_verbose opt_quiet opt_dry_run opt_debug
    local -a opt_config opt_output

    # Parse options using zparseopts
    # -D: Remove parsed options from positional parameters
    # -E: Don't stop at first non-option (allows mixed arguments)
    # -F: Fail on unknown options
    # -K: Keep default values in arrays
    # -M: Allow -vvv style repetition
    zparseopts -D -E -F -K -- \
        h=opt_help     -help=opt_help \
        V=opt_version  -version=opt_version \
        v+=opt_verbose -verbose+=opt_verbose \
        q=opt_quiet    -quiet=opt_quiet \
        n=opt_dry_run  -dry-run=opt_dry_run \
        d=opt_debug    -debug=opt_debug \
        c:=opt_config  -config:=opt_config \
        o:=opt_output  -output:=opt_output \
        || {
            usage
            exit $E_USAGE
        }

    # Process parsed options
    if (( ${#opt_help} )); then
        show_help
        exit $E_SUCCESS
    fi

    if (( ${#opt_version} )); then
        show_version
        exit $E_SUCCESS
    fi

    # Handle verbosity (count -v occurrences)
    # Each -v or --verbose adds to the count
    if (( ${#opt_verbose} )); then
        VERBOSITY=$(( V_NORMAL + ${#opt_verbose} ))
        (( VERBOSITY > V_TRACE )) && VERBOSITY=$V_TRACE
    fi

    if (( ${#opt_quiet} )); then
        VERBOSITY=$V_QUIET
    fi

    if (( ${#opt_dry_run} )); then
        DRY_RUN=true
    fi

    if (( ${#opt_debug} )); then
        VERBOSITY=$V_TRACE
        setopt XTRACE
    fi

    # Handle options with values
    # zparseopts puts the option and value in array: (-c value) or (--config value)
    if (( ${#opt_config} )); then
        # The value is the second element
        CONFIG_FILE=${opt_config[-1]}
    fi

    if (( ${#opt_output} )); then
        OUTPUT_FILE=${opt_output[-1]}
    fi

    # Remaining arguments are positional
    # Remove leading -- separator if present (zparseopts -E leaves it in $@)
    if [[ ${1:-} == '--' ]]; then
        shift
    fi
    POSITIONAL_ARGS=("$@")

    debug "Verbosity level: ${VERBOSITY}"
    debug "Dry run: ${DRY_RUN}"
    debug "Positional arguments: ${(j:, :)POSITIONAL_ARGS:-none}"
}

# Validate parsed arguments
# Globals: POSITIONAL_ARGS
# Arguments: None
# Outputs: Error messages for missing/invalid arguments
# Returns: 0 on success, exits on failure
validate_arguments() {
    emulate -L zsh

    # Example: require at least one positional argument
    # Uncomment and customize as needed:
    #
    # if (( ${#POSITIONAL_ARGS} < 1 )); then
    #     error "Missing required argument"
    #     usage
    #     exit $E_USAGE
    # fi

    # Example: validate first argument is a readable file
    # if (( ${#POSITIONAL_ARGS} >= 1 )); then
    #     if ! validate_file_readable "${POSITIONAL_ARGS[1]}"; then
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
    emulate -L zsh

    if [[ $DRY_RUN == true ]]; then
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
    emulate -L zsh
    local config_file=$1

    if [[ ! -f $config_file ]]; then
        debug "Configuration file not found: ${config_file}"
        return 1
    fi

    if [[ ! -r $config_file ]]; then
        warn "Configuration file not readable: ${config_file}"
        return 1
    fi

    debug "Loading configuration from: ${config_file}"

    # Validate syntax by attempting to parse in a subshell
    if ! zsh -n "$config_file" 2>/dev/null; then
        error "Syntax error in configuration file: ${config_file}"
        return 1
    fi

    # Source the config file
    # Using emulate to ensure zsh mode in sourced file
    source "$config_file"
    return 0
}

# Load configuration from standard locations
# Globals: SCRIPT_NAME, CONFIG_FILE
# Arguments: None
# Outputs: Debug messages
load_configuration() {
    emulate -L zsh

    # Remove extension from script name for config name
    local config_name=${SCRIPT_NAME%.zsh}
    config_name=${config_name%.sh}

    # Configuration file search locations (in order of precedence)
    local -a config_locations=(
        "/etc/${config_name}/${config_name}.conf"
        "/etc/${config_name}.conf"
        "${HOME}/.config/${config_name}/${config_name}.conf"
        "${HOME}/.${config_name}.conf"
        "./${config_name}.conf"
    )

    # Add environment-specified config file
    # ${(U)var} converts to uppercase, tr replacements for valid var name
    local env_var="${(U)config_name//[^A-Za-z0-9]/_}_CONFIG_FILE"
    if [[ -n "${(P)env_var:-}" ]]; then
        config_locations+=("${(P)env_var}")
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
    emulate -L zsh
    debug "Starting main execution"

    # Example: process positional arguments using zsh's array iteration
    local arg
    for arg in "${POSITIONAL_ARGS[@]}"; do
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
    emulate -L zsh

    # Initialize colors first (for logging)
    init_colors

    # Set up error and cleanup handlers
    setup_traps

    debug "Initializing ${SCRIPT_NAME} v${SCRIPT_VERSION}"
    debug "Running on: $(uname -s) $(uname -r)"
    debug "Zsh version: ${ZSH_VERSION}"
    debug "Script directory: ${SCRIPT_DIR}"
}

# Entry point
# Globals: None
# Arguments: Command line arguments "$@"
_main() {
    emulate -L zsh

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

    # Run main logic using always block for guaranteed cleanup
    {
        main
    } always {
        # This block always executes, even on error
        # Useful for cleanup that must happen regardless of success/failure
        # Note: TRAPEXIT handles most cleanup, but this is available for
        # function-specific cleanup if needed
        :
    }

    # Exit with success (cleanup happens via TRAPEXIT)
    exit $E_SUCCESS
}

# ==============================================================================
# SOURCE GUARD AND EXECUTION
# ==============================================================================

# Only run if executed directly (not sourced)
# In zsh, we check if the script file matches $0
# ${(%):-%x} gives us the script path, ${(%):-%N} gives sourced file
# When sourced: %x != $0, when executed: %x == $0
#
# For oh-my-zsh / starship compatibility:
# - When sourced, only function definitions are loaded
# - Global state is not modified until _main is called
# - Use ZSH_SCRIPT for more reliable detection in complex scenarios

if [[ "${(%):-%x}" == "$0" ]] || [[ -n "${ZSH_SCRIPT:-}" ]]; then
    _main "$@"
fi

# ==============================================================================
# ZSH COMPLETION FUNCTION SCAFFOLD
# ==============================================================================
# To enable command completion, create a file named _script_name in your fpath
# with the following content (uncomment and customize):
#
# #compdef script_name
#
# _script_name() {
#     local -a options
#     options=(
#         '(-h --help)'{-h,--help}'[Show help message]'
#         '(-V --version)'{-V,--version}'[Show version]'
#         '*'{-v,--verbose}'[Increase verbosity]'
#         '(-q --quiet)'{-q,--quiet}'[Suppress output]'
#         '(-n --dry-run)'{-n,--dry-run}'[Dry run mode]'
#         '(-d --debug)'{-d,--debug}'[Enable debug mode]'
#         '(-c --config)'{-c,--config}'[Config file]:config file:_files'
#         '(-o --output)'{-o,--output}'[Output file]:output file:_files'
#     )
#
#     _arguments -s $options '*:file:_files'
# }
#
# _script_name "$@"

# ==============================================================================
# OH-MY-ZSH PLUGIN STRUCTURE (optional)
# ==============================================================================
# To use as an oh-my-zsh plugin, create this directory structure:
#
# ~/.oh-my-zsh/custom/plugins/script_name/
#     script_name.plugin.zsh    # Source this file or define aliases/functions
#     _script_name              # Completion function
#
# Then add 'script_name' to plugins=(...) in ~/.zshrc
