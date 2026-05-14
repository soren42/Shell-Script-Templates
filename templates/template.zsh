#!/usr/bin/env zsh
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
typeset -gr REQUIRE_ROOT=false                 # Must run as root (default: false)
typeset -gr REQUIRES_NETWORK=false             # Needs network access (default: false)
typeset -gr REQUIRES_DISK_SPACE=false          # Creates significant temp/output files (default: false)
typeset -gi DISK_SPACE_REQUIRED_MB=100         # Minimum MB needed if REQUIRES_DISK_SPACE=true

# Capabilities
typeset -gr CAN_RUN_IN_USERSPACE=true          # Can run in user directories (default: true)
typeset -gr SUPPORTS_DRY_RUN=true              # Supports --dry-run mode (default: true)
typeset -gr IDEMPOTENT=false                   # Safe to run multiple times (default: false)
typeset -gr INTERACTIVE=false                  # Requires user input beyond CLI (default: false)
typeset -gr CREATES_ARTIFACTS=false            # Produces persistent output files (default: false)

# Feature Toggles
typeset -gr HAS_EXTERNAL_DEPENDENCIES=true     # Uses external binaries (default: true)
typeset -gr USES_CONFIG_FILES=true             # Loads configuration files (default: true)
typeset -gr SUPPORTS_PARALLEL=false            # Safe for concurrent execution (default: false)
typeset -gr VERBOSE_BY_DEFAULT=false           # Start with verbose output (default: false)
typeset -gr INCLUDES_SELF_TEST=false           # Includes test functions (default: false)

# Zsh-Specific
typeset -gr COMPILABLE=true                    # Safe for zcompile (default: true)

# Plugin System
typeset -gr ENABLED_PLUGINS=""                 # Comma-separated plugin list (default: "")
typeset -gr PLUGIN_DIR="${HOME}/.shell-script-templates/plugins"

# ==============================================================================
# ZSH STRICT MODE AND SHELL OPTIONS
# ==============================================================================
emulate -L zsh

# Core strict mode
setopt ERR_EXIT             # Exit on error
setopt NO_UNSET             # Error on undefined variables
setopt PIPE_FAIL            # Pipeline fails on first error

# Additional safety
setopt WARN_CREATE_GLOBAL   # Warn if global created in function
setopt NO_CLOBBER           # Don't overwrite with >
setopt LOCAL_OPTIONS        # Options set in functions are local
setopt LOCAL_TRAPS          # Traps set in functions are local
setopt LOCAL_PATTERNS       # Patterns set in functions are local

# Extended features
setopt EXTENDED_GLOB        # Enable extended globbing

# Verify zsh version
autoload -Uz is-at-least
if ! is-at-least 5.0; then
    print -u2 "Error: This script requires zsh 5.0 or later"
    print -u2 "Current version: ${ZSH_VERSION}"
    exit 1
fi

# ==============================================================================
# CONSTANTS AND DEFAULTS
# ==============================================================================
# Script metadata
typeset -gr SCRIPT_VERSION="1.0.0"
typeset -gr SCRIPT_AUTHOR="Your Name <your@email.com>"
typeset -gr SCRIPT_NAME="${${(%):-%x}:t}"
typeset -gr SCRIPT_DIR="${${(%):-%x}:A:h}"
typeset -gr SCRIPT_PATH="${${(%):-%x}:A}"

# Exit codes (sysexits.h style)
typeset -gri E_SUCCESS=0        # Success
typeset -gri E_GENERAL=1        # General error
typeset -gri E_USAGE=2          # Command syntax error
typeset -gri E_NOINPUT=66       # Input file not found
typeset -gri E_NOUSER=67        # User not found
typeset -gri E_NOHOST=68        # Host not found
typeset -gri E_UNAVAILABLE=69   # Service unavailable
typeset -gri E_SOFTWARE=70      # Internal software error
typeset -gri E_OSERR=71         # Operating system error
typeset -gri E_OSFILE=72        # OS file missing
typeset -gri E_CANTCREAT=73     # Cannot create file
typeset -gri E_IOERR=74         # I/O error
typeset -gri E_TEMPFAIL=75      # Temporary failure
typeset -gri E_PROTOCOL=76      # Protocol error
typeset -gri E_NOPERM=77        # Permission denied
typeset -gri E_CONFIG=78        # Configuration error

# Verbosity levels
typeset -gri V_QUIET=0          # Errors only
typeset -gri V_NORMAL=1         # Standard output
typeset -gri V_VERBOSE=2        # Detailed progress
typeset -gri V_DEBUG=3          # Debug information
typeset -gri V_TRACE=4          # Full execution trace

# ==============================================================================
# GLOBAL VARIABLES (mutable state)
# ==============================================================================
# Verbosity control
typeset -gi VERBOSITY=${V_NORMAL}
[[ "${VERBOSE_BY_DEFAULT}" == true ]] && VERBOSITY=${V_VERBOSE}

# Execution control
typeset -g DRY_RUN=false
typeset -g RUN_SELF_TEST=false

# Resource tracking
typeset -ga TEMP_FILES=()
typeset -g TEMP_DIR=""

# Dependency tracking
typeset -gA REQUIRED_BINARIES=()
typeset -gA OPTIONAL_BINARIES=()

# Argument storage
typeset -ga POSITIONAL_ARGS=()
typeset -g CONFIG_FILE=""
typeset -g OUTPUT_FILE=""

# Terminal colors
typeset -gA COLORS=(
    reset ''
    bold ''
    dim ''
    red ''
    green ''
    yellow ''
    blue ''
    magenta ''
    cyan ''
    white ''
)

# ==============================================================================
# LOGGING AND OUTPUT
# ==============================================================================

# Initialize terminal colors if supported
# Globals: COLORS (modified)
# Arguments: None
# Returns: None
init_colors() {
    emulate -L zsh
    
    # Only enable colors for terminal output
    if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
        COLORS[reset]=$'\033[0m'
        COLORS[bold]=$'\033[1m'
        COLORS[dim]=$'\033[2m'
        COLORS[red]=$'\033[31m'
        COLORS[green]=$'\033[32m'
        COLORS[yellow]=$'\033[33m'
        COLORS[blue]=$'\033[34m'
        COLORS[magenta]=$'\033[35m'
        COLORS[cyan]=$'\033[36m'
        COLORS[white]=$'\033[37m'
    fi
}

# Format a log message with timestamp and level
# Globals: None
# Arguments:
#   $1 - Log level string
#   $2 - Message
# Returns: Formatted string via stdout
format_log_message() {
    emulate -L zsh
    local level=$1
    local message=$2
    local timestamp
    
    zmodload -F zsh/datetime b:strftime
    strftime -s timestamp '%Y-%m-%d %H:%M:%S'
    
    print -r -- "[${timestamp}] [${level}] ${message}"
}

# Log trace message (verbosity 4+)
# Globals: VERBOSITY, COLORS
# Arguments: Message string
# Returns: None
trace() {
    emulate -L zsh
    if (( VERBOSITY >= V_TRACE )); then
        print -r -- "${COLORS[dim]}$(format_log_message "TRACE" "$*")${COLORS[reset]}"
    fi
}

# Log debug message (verbosity 3+)
# Globals: VERBOSITY, COLORS
# Arguments: Message string
# Returns: None
debug() {
    emulate -L zsh
    if (( VERBOSITY >= V_DEBUG )); then
        print -r -- "${COLORS[cyan]}$(format_log_message "DEBUG" "$*")${COLORS[reset]}"
    fi
}

# Log info message (verbosity 1+)
# Globals: VERBOSITY, COLORS
# Arguments: Message string
# Returns: None
info() {
    emulate -L zsh
    if (( VERBOSITY >= V_NORMAL )); then
        print -r -- "${COLORS[green]}$(format_log_message "INFO" "$*")${COLORS[reset]}"
    fi
}

# Log warning message (verbosity 1+)
# Globals: VERBOSITY, COLORS
# Arguments: Message string
# Returns: None
warn() {
    emulate -L zsh
    if (( VERBOSITY >= V_NORMAL )); then
        print -u2 -r -- "${COLORS[yellow]}$(format_log_message "WARN" "$*")${COLORS[reset]}"
    fi
}

# Log error message (always shown)
# Globals: COLORS
# Arguments: Message string
# Returns: None
error() {
    emulate -L zsh
    print -u2 -r -- "${COLORS[red]}$(format_log_message "ERROR" "$*")${COLORS[reset]}"
}

# Log fatal error and exit
# Globals: COLORS
# Arguments:
#   $1 - Error message
#   $2 - Exit code (optional, default: E_GENERAL)
# Returns: Never (exits)
fatal() {
    emulate -L zsh
    local message=$1
    local exit_code=${2:-$E_GENERAL}
    print -u2 -r -- "${COLORS[bold]}${COLORS[red]}$(format_log_message "FATAL" "${message}")${COLORS[reset]}"
    exit "$exit_code"
}

# Simple message output (verbosity 1+)
# Globals: VERBOSITY
# Arguments: Message string
# Returns: None
msg() {
    emulate -L zsh
    if (( VERBOSITY >= V_NORMAL )); then
        print -r -- "$*"
    fi
}

# Simple message without newline (verbosity 1+)
# Globals: VERBOSITY
# Arguments: Message string
# Returns: None
msgn() {
    emulate -L zsh
    if (( VERBOSITY >= V_NORMAL )); then
        print -n -r -- "$*"
    fi
}

# ==============================================================================
# ERROR HANDLING AND CLEANUP
# ==============================================================================

# Print stack trace for debugging
# Globals: funcstack, funcsourcetrace
# Arguments: None
# Returns: None
print_stack_trace() {
    emulate -L zsh
    local -i i
    error "Stack trace:"
    
    for (( i = 2; i <= ${#funcstack}; i++ )); do
        local func="${funcstack[$i]}"
        local trace="${funcsourcetrace[$i]}"
        error "  at ${func}() in ${trace}"
    done
}

# TRAP function for errors
# Globals: funcstack, funcsourcetrace, VERBOSITY
# Arguments: None
# Returns: None
TRAPZERR() {
    emulate -L zsh
    local exit_code=$?
    
    error "Command failed with exit code ${exit_code}"
    
    if (( ${#funcstack} > 0 )); then
        error "  Function: ${funcstack[1]}"
    fi
    
    if (( ${#funcsourcetrace} > 0 )); then
        error "  Source: ${funcsourcetrace[1]}"
    fi
    
    # Print stack trace if debug verbosity
    if (( VERBOSITY >= V_DEBUG )); then
        print_stack_trace
    fi
}

# TRAP function for exit
# Globals: TEMP_FILES, TEMP_DIR
# Arguments: None
# Returns: None
TRAPEXIT() {
    emulate -L zsh
    local exit_code=$?
    
    # Remove temporary files
    if (( ${#TEMP_FILES} > 0 )); then
        debug "Cleaning up ${#TEMP_FILES} temporary file(s)"
        local file
        for file in "${TEMP_FILES[@]}"; do
            [[ -f "$file" ]] && rm -f "$file" 2>/dev/null || true
        done
    fi
    
    # Remove temporary directory
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        debug "Cleaning up temporary directory: ${TEMP_DIR}"
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    
    return "$exit_code"
}

# TRAP function for interrupt (Ctrl+C)
# Globals: None
# Arguments: None
# Returns: Exit code 130
TRAPINT() {
    emulate -L zsh
    error "Received interrupt signal (INT)"
    return 130
}

# TRAP function for termination
# Globals: None
# Arguments: None
# Returns: Exit code 143
TRAPTERM() {
    emulate -L zsh
    error "Received termination signal (TERM)"
    return 143
}

# TRAP function for hangup
# Globals: None
# Arguments: None
# Returns: Exit code 129
TRAPHUP() {
    emulate -L zsh
    error "Received hangup signal (HUP)"
    return 129
}

# ==============================================================================
# FEATURE FLAG VALIDATION
# ==============================================================================

# Validate that script can run with current privileges
# Globals: REQUIRE_ROOT
# Arguments: None
# Returns: 0 if valid, exits on failure
validate_privileges() {
    emulate -L zsh
    if [[ "${REQUIRE_ROOT}" == true ]]; then
        if (( EUID != 0 )); then
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
    emulate -L zsh
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
    emulate -L zsh
    if [[ "${REQUIRES_DISK_SPACE}" == true ]]; then
        local available_mb
        
        # Get available space in MB for /tmp
        available_mb=$(df -m /tmp | awk 'NR==2 {print $4}')
        
        debug "Available disk space: ${available_mb}MB, required: ${DISK_SPACE_REQUIRED_MB}MB"
        
        if (( available_mb < DISK_SPACE_REQUIRED_MB )); then
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
    emulate -L zsh
    if [[ "${CAN_RUN_IN_USERSPACE}" == false ]]; then
        # Check if we're in a system directory
        case "$PWD" in
            ${HOME}/*|/tmp/*|/var/tmp/*)
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
    emulate -L zsh
    local plugin_name=$1
    [[ -d "${PLUGIN_DIR}/${plugin_name}" ]] && [[ -f "${PLUGIN_DIR}/${plugin_name}/plugin.conf" ]]
}

# Load a plugin's functions
# Globals: PLUGIN_DIR
# Arguments:
#   $1 - Plugin name
# Returns: 0 on success, 1 on failure
source_plugin() {
    emulate -L zsh
    local plugin_name=$1
    local plugin_path="${PLUGIN_DIR}/${plugin_name}"
    
    if ! plugin_exists "$plugin_name"; then
        warn "Plugin not found: ${plugin_name}"
        return 1
    fi
    
    debug "Loading plugin: ${plugin_name}"
    
    # Source plugin configuration
    source "${plugin_path}/plugin.conf"
    
    # Source plugin functions if they exist
    if [[ -f "${plugin_path}/functions.sh" ]]; then
        source "${plugin_path}/functions.sh"
    fi
    
    # Call plugin init if it exists
    if [[ -f "${plugin_path}/init.sh" ]]; then
        source "${plugin_path}/init.sh"
    fi
    
    return 0
}

# Load all enabled plugins
# Globals: ENABLED_PLUGINS
# Arguments: None
# Returns: None
load_plugins() {
    emulate -L zsh
    if [[ -z "$ENABLED_PLUGINS" ]]; then
        debug "No plugins enabled"
        return 0
    fi
    
    debug "Loading plugins: ${ENABLED_PLUGINS}"
    
    # Split comma-separated list and load each plugin
    local plugin
    for plugin in ${(s:,:)ENABLED_PLUGINS}; do
        plugin=${plugin## ##}  # Trim whitespace
        plugin=${plugin%% ##}
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
    emulate -L zsh
    (( $+commands[$1] ))
}

# Get the first available command from a list
# Globals: commands
# Arguments: Command names to try
# Returns: Path to first found command, or empty string
get_command() {
    emulate -L zsh
    local cmd
    for cmd in "$@"; do
        if (( $+commands[$cmd] )); then
            print -r -- "$commands[$cmd]"
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
    emulate -L zsh
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
    emulate -L zsh
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
    emulate -L zsh
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
    emulate -L zsh
    local suffix="${1:-}"
    local temp_file
    
    if [[ -n "$suffix" ]]; then
        temp_file=$(mktemp "/tmp/${SCRIPT_NAME}.XXXXXX${suffix}")
    else
        temp_file=$(mktemp "/tmp/${SCRIPT_NAME}.XXXXXX")
    fi
    
    TEMP_FILES+=("$temp_file")
    debug "Created temp file: ${temp_file}"
    print -r -- "$temp_file"
}

# Create a temporary directory and register for cleanup
# Globals: TEMP_DIR (modified)
# Arguments: None
# Returns: Path to temp directory via stdout
create_temp_dir() {
    emulate -L zsh
    # Only create one temp directory per script run
    if [[ -z "$TEMP_DIR" ]]; then
        TEMP_DIR=$(mktemp -d "/tmp/${SCRIPT_NAME}.XXXXXX")
        debug "Created temp directory: ${TEMP_DIR}"
    fi
    print -r -- "$TEMP_DIR"
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
    emulate -L zsh
    local value=$1
    local min=${2:-}
    local max=${3:-}
    
    # Check if it's an integer using zsh pattern
    if ! [[ $value == <-> ]] && ! [[ $value == -<-> ]]; then
        return 1
    fi
    
    # Check minimum
    if [[ -n "$min" ]] && (( value < min )); then
        return 1
    fi
    
    # Check maximum
    if [[ -n "$max" ]] && (( value > max )); then
        return 1
    fi
    
    return 0
}

# Validate that a value is a float
# Globals: None
# Arguments:
#   $1 - Value to validate
#   $2 - Minimum value (optional)
#   $3 - Maximum value (optional)
# Returns: 0 if valid, 1 if invalid
validate_float() {
    emulate -L zsh
    local value=$1
    local min=${2:-}
    local max=${3:-}
    
    # Try to use as float in arithmetic
    local test_value
    if ! test_value=$(( value + 0.0 )) 2>/dev/null; then
        return 1
    fi
    
    # Check minimum
    if [[ -n "$min" ]] && (( value < min )); then
        return 1
    fi
    
    # Check maximum
    if [[ -n "$max" ]] && (( value > max )); then
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
    emulate -L zsh
    local value=$1
    local -i min=${2:-1}
    local -i max=${3:-0}
    local -i length=${#value}
    
    # Check minimum length
    if (( length < min )); then
        return 1
    fi
    
    # Check maximum length
    if (( max > 0 )) && (( length > max )); then
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
    emulate -L zsh
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
    emulate -L zsh
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
    emulate -L zsh
    local input=$1
    local sanitized
    
    # Replace non-alphanumeric characters (except . _ -) with underscore
    sanitized=${input//[^[:alnum:]._-]/_}
    
    # Collapse multiple underscores using extended glob
    sanitized=${sanitized//_(#c2,)/_}
    
    print -r -- "$sanitized"
}

# ==============================================================================
# USAGE AND HELP
# ==============================================================================

# Display usage information (brief)
# Globals: SCRIPT_NAME
# Arguments: None
# Returns: None
usage() {
    emulate -L zsh
    print -r -- "\
Usage: ${SCRIPT_NAME} [OPTIONS] [ARGS]

Try '${SCRIPT_NAME} --help' for more information."
}

# Display detailed help information
# Globals: SCRIPT_NAME, SCRIPT_VERSION
# Arguments: None
# Returns: None
show_help() {
    emulate -L zsh
    print -r -- "\
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

For more information, see the documentation."
}

# Display version information
# Globals: SCRIPT_NAME, SCRIPT_VERSION, SCRIPT_AUTHOR
# Arguments: None
# Returns: None
show_version() {
    emulate -L zsh
    print -r -- "\
${SCRIPT_NAME} ${SCRIPT_VERSION}
Author: ${SCRIPT_AUTHOR}
License: CC BY-SA 4.0 - https://creativecommons.org/licenses/by-sa/4.0/"
}

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================

# Parse command-line arguments using zparseopts
# Globals: VERBOSITY, DRY_RUN, CONFIG_FILE, OUTPUT_FILE, POSITIONAL_ARGS (modified)
# Arguments: All command-line arguments ($@)
# Returns: None, exits on invalid arguments
parse_arguments() {
    emulate -L zsh
    zmodload zsh/zutil
    
    # Option arrays
    local -a opt_help opt_version opt_verbose opt_quiet opt_dry_run opt_debug
    local -a opt_config opt_output opt_self_test
    
    zparseopts -D -E -F -K -- \
        h=opt_help     -help=opt_help \
        V=opt_version  -version=opt_version \
        v+=opt_verbose -verbose+=opt_verbose \
        q=opt_quiet    -quiet=opt_quiet \
        n=opt_dry_run  -dry-run=opt_dry_run \
        d=opt_debug    -debug=opt_debug \
        c:=opt_config  -config:=opt_config \
        o:=opt_output  -output:=opt_output \
        -self-test=opt_self_test \
        || {
            usage
            exit $E_USAGE
        }
    
    # Process options
    if (( ${#opt_help} )); then
        show_help
        exit $E_SUCCESS
    fi
    
    if (( ${#opt_version} )); then
        show_version
        exit $E_SUCCESS
    fi
    
    if (( ${#opt_verbose} )); then
        VERBOSITY=$(( V_NORMAL + ${#opt_verbose} ))
    fi
    
    if (( ${#opt_quiet} )); then
        VERBOSITY=$V_QUIET
    fi
    
    if (( ${#opt_dry_run} )); then
        DRY_RUN=true
        info "Dry-run mode enabled"
    fi
    
    if (( ${#opt_debug} )); then
        VERBOSITY=$V_TRACE
        setopt XTRACE
    fi
    
    if (( ${#opt_self_test} )); then
        RUN_SELF_TEST=true
    fi
    
    if (( ${#opt_config} )); then
        CONFIG_FILE=${opt_config[-1]}
    fi
    
    if (( ${#opt_output} )); then
        OUTPUT_FILE=${opt_output[-1]}
    fi
    
    # Store positional arguments
    POSITIONAL_ARGS=("$@")
}

# Validate parsed arguments
# Globals: POSITIONAL_ARGS
# Arguments: None
# Returns: Exits if validation fails
validate_arguments() {
    emulate -L zsh
    
    # Add your argument validation here
    # Example:
    # if (( ${#POSITIONAL_ARGS} < 1 )); then
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
    emulate -L zsh
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
    emulate -L zsh
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
    source "$config_file"
    
    return 0
}

# Load configuration files from hierarchy
# Globals: SCRIPT_NAME, CONFIG_FILE, USES_CONFIG_FILES
# Arguments: None
# Returns: None
load_configuration() {
    emulate -L zsh
    if [[ "${USES_CONFIG_FILES}" == false ]]; then
        debug "Configuration file loading disabled"
        return 0
    fi
    
    local config_name="${SCRIPT_NAME%.zsh}"
    local -a config_paths=(
        "/etc/${config_name}/${config_name}.conf"
        "/etc/${config_name}.conf"
        "${HOME}/.config/${config_name}/${config_name}.conf"
        "${HOME}/.${config_name}.conf"
        "./${config_name}.conf"
    )
    
    # Add environment variable config
    local env_var="${(U)config_name//[^A-Z0-9]/_}_CONFIG_FILE"
    if [[ -n "${(P)env_var:-}" ]]; then
        config_paths+=("${(P)env_var}")
    fi
    
    # Add command-line config (highest priority)
    if [[ -n "$CONFIG_FILE" ]]; then
        config_paths+=("$CONFIG_FILE")
    fi
    
    # Load configs in order (later ones override earlier)
    local config_path
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
    emulate -L zsh
    local -i failed=0
    
    # Test validate_integer
    if ! validate_integer "42"; then
        error "Test failed: validate_integer with valid integer"
        (( failed++ ))
    fi
    
    if validate_integer "not_a_number"; then
        error "Test failed: validate_integer with invalid input"
        (( failed++ ))
    fi
    
    if ! validate_integer "50" 0 100; then
        error "Test failed: validate_integer with valid range"
        (( failed++ ))
    fi
    
    # Test validate_string
    if ! validate_string "hello"; then
        error "Test failed: validate_string with valid string"
        (( failed++ ))
    fi
    
    if validate_string "" 1; then
        error "Test failed: validate_string with empty string"
        (( failed++ ))
    fi
    
    if (( failed == 0 )); then
        info "Validation function tests passed"
    fi
    
    return "$failed"
}

# Test dependency checking
# Globals: None
# Arguments: None
# Returns: 0 if all tests pass, 1 if any fail
test_dependency_check() {
    emulate -L zsh
    local -i failed=0
    
    # Test that basic commands are found
    if ! command_exists "sh"; then
        error "Test failed: command_exists with 'sh'"
        (( failed++ ))
    fi
    
    if command_exists "this_command_does_not_exist_12345"; then
        error "Test failed: command_exists with non-existent command"
        (( failed++ ))
    fi
    
    if (( failed == 0 )); then
        info "Dependency check tests passed"
    fi
    
    return "$failed"
}

# Run all self-tests
# Globals: None
# Arguments: None
# Returns: 0 if all tests pass, exits with E_SOFTWARE if any fail
run_self_test() {
    emulate -L zsh
    local -i failed=0
    
    info "Running self-tests..."
    
    test_validation_functions || (( failed++ ))
    test_dependency_check || (( failed++ ))
    
    if (( failed == 0 )); then
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
    emulate -L zsh
    debug "Starting main execution"
    
    # Example: Access positional arguments (zsh arrays are 1-indexed)
    # local input_file="${POSITIONAL_ARGS[1]:-}"
    
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
    emulate -L zsh
    init_colors
    debug "Initialization complete"
}

# Main entry point
# Globals: All
# Arguments: All command-line arguments ($@)
# Returns: Exit code from main()
_main() {
    emulate -L zsh
    
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
    
    # Run main logic with guaranteed cleanup
    {
        main
    } always {
        # Additional cleanup can go here if needed
        # TRAPEXIT will handle temp file cleanup
    }
    
    exit $?
}

# Execute main function if script is run directly (not sourced)
# In zsh, check if $ZSH_EVAL_CONTEXT contains 'toplevel'
if [[ "${ZSH_EVAL_CONTEXT:-}" == *:file:* ]] || [[ "${ZSH_EVAL_CONTEXT:-}" == *:file ]]; then
    # Script is being sourced
    :
else
    # Script is being executed
    _main "$@"
fi

# ==============================================================================
# ZSH COMPLETION FUNCTION SCAFFOLD
# ==============================================================================
# To enable completion, save this section as _script_name in your fpath
# Uncomment and customize as needed:
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
#         '--self-test[Run self-tests]'
#     )
#     
#     _arguments -s $options '*:file:_files'
# }
#
# _script_name "$@"

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
