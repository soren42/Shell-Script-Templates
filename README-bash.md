# Bash Script Template - Developer's Guide

**Version:** 3.0.0
**Author:** jason c. kay
**License:** CC BY-SA 4.0

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Architecture](#architecture)
4. [Features Reference](#features-reference)
5. [Customization Guide](#customization-guide)
6. [Best Practices](#best-practices)
7. [Examples](#examples)
8. [Troubleshooting](#troubleshooting)
9. [API Reference](#api-reference)

---

## Overview

### What This Template Provides

This bash template is a production-ready foundation for building robust, maintainable shell scripts. It embodies professional engineering standards and provides:

- **Strict mode execution** with comprehensive error handling
- **Professional logging system** with multiple verbosity levels and color support
- **Flexible argument parsing** supporting POSIX, GNU, and combined short options
- **Automatic resource cleanup** via trap handlers
- **Dependency validation** with helpful installation instructions
- **Configuration file support** with hierarchical loading
- **Input validation helpers** for common data types
- **Dry-run mode** for safe testing

### Philosophy

This template follows several core principles:

1. **Fail Fast**: Use strict mode (`set -euo pipefail`) to catch errors immediately
2. **Clean Exit**: Always clean up resources, even on error or interrupt
3. **Explicit Over Implicit**: Validate inputs and dependencies before execution
4. **User-Friendly**: Provide helpful error messages, usage information, and dry-run support
5. **Portable**: Target bash 4.0+ while maintaining cross-platform compatibility (Linux/macOS)

### Requirements

- **Bash 4.0+** (for associative arrays and other features)
- Standard POSIX utilities (`sed`, `awk`, `tr`, `mktemp`)

---

## Quick Start

### Creating a New Script

1. **Copy the template:**
   ```bash
   cp template.sh my-script.sh
   chmod +x my-script.sh
   ```

2. **Update the metadata** at the top of the file:
   ```bash
   # my-script(1)
   #
   # Description:
   #   What your script does.
   ```

3. **Update script constants:**
   ```bash
   readonly SCRIPT_VERSION="1.0.0"
   readonly SCRIPT_AUTHOR="Your Name <your@email.com>"
   ```

4. **Implement your logic** in the `main()` function:
   ```bash
   main() {
       debug "Starting main execution"

       # Your code here
       local input_file="${POSITIONAL_ARGS[0]}"
       info "Processing: ${input_file}"

       return $E_SUCCESS
   }
   ```

5. **Update the help text** in `show_help()` and `usage()`

6. **Add dependencies** in `validate_dependencies()`:
   ```bash
   validate_dependencies() {
       require_binary curl
       require_binary jq
       optional_binary prettier || warn "prettier not found, output won't be formatted"
   }
   ```

7. **Run your script:**
   ```bash
   ./my-script.sh --help
   ./my-script.sh -v input.txt
   ./my-script.sh --dry-run input.txt
   ```

---

## Architecture

### Execution Flow

```
_main()
    |
    +-> init()
    |       |-> init_colors()      # Set up terminal colors
    |       +-> setup_traps()      # Register EXIT, ERR, INT, TERM, HUP handlers
    |
    +-> parse_arguments()          # Process command-line options
    |
    +-> load_configuration()       # Load config files (hierarchical)
    |
    +-> validate_dependencies()    # Check required/optional binaries
    |
    +-> validate_arguments()       # Validate positional args
    |
    +-> main()                     # YOUR IMPLEMENTATION
    |
    +-> exit $E_SUCCESS
            |
            +-> cleanup()          # Via EXIT trap - always runs
```

### Code Organization

The template is organized into logical sections, each marked with a header:

| Section | Purpose |
|---------|---------|
| `STRICT MODE AND SHELL OPTIONS` | Shell configuration and bash version check |
| `CONSTANTS AND DEFAULTS` | Immutable values: script metadata, exit codes, verbosity levels |
| `GLOBAL VARIABLES` | Mutable state: verbosity, dry-run flag, temp files |
| `LOGGING AND OUTPUT` | Color initialization and logging functions |
| `ERROR HANDLING AND CLEANUP` | Trap handlers and cleanup logic |
| `DEPENDENCY VALIDATION` | Binary checking and registration |
| `TEMP FILE MANAGEMENT` | Safe temporary file creation |
| `INPUT VALIDATION` | Data validation helpers |
| `USAGE AND HELP` | Help text and usage messages |
| `ARGUMENT PARSING` | Command-line option processing |
| `DRY RUN SUPPORT` | Safe command execution wrapper |
| `CONFIGURATION` | Config file loading |
| `MAIN LOGIC` | User implementation area |
| `INITIALIZATION AND ENTRY POINT` | Startup sequence |

### Global Variables

The template uses these key global variables:

| Variable | Type | Description |
|----------|------|-------------|
| `VERBOSITY` | integer | Current verbosity level (0-4) |
| `DRY_RUN` | boolean | Whether to simulate commands |
| `TEMP_FILES` | array | Registered temp files for cleanup |
| `TEMP_DIR` | string | Registered temp directory for cleanup |
| `REQUIRED_BINARIES` | assoc array | Map of required binary names to paths |
| `OPTIONAL_BINARIES` | assoc array | Map of optional binary names to paths |
| `POSITIONAL_ARGS` | array | Non-option arguments from command line |
| `COLORS` | assoc array | Terminal color escape sequences |

---

## Features Reference

### Strict Mode and Shell Options

The template enables strict mode at startup:

```bash
set -o errexit   # Exit on any command failure (set -e)
set -o nounset   # Error on undefined variables (set -u)
set -o pipefail  # Pipeline fails if any command fails
```

**errexit** causes the script to exit immediately when any command returns a non-zero exit code. This prevents cascading errors.

**nounset** catches typos and undefined variables by treating them as errors:
```bash
echo "$UNDEFINED_VAR"  # Error: unbound variable
```

**pipefail** ensures that pipeline failures are detected:
```bash
false | true  # Without pipefail: succeeds. With pipefail: fails
```

#### Handling Expected Failures

Sometimes you need commands that may fail. Use these patterns:

```bash
# Pattern 1: Explicit || true
((counter++)) || true  # Arithmetic returning 0 would trigger errexit

# Pattern 2: Conditional execution
if ! some_command; then
    # Handle failure
fi

# Pattern 3: Disable temporarily (use sparingly)
set +e
risky_command
result=$?
set -e
```

### Logging System

#### Verbosity Levels

| Level | Constant | Value | What's Shown |
|-------|----------|-------|--------------|
| Quiet | `V_QUIET` | 0 | Errors and fatal messages only |
| Normal | `V_NORMAL` | 1 | Standard output (info, warnings, errors) |
| Verbose | `V_VERBOSE` | 2 | Additional progress information |
| Debug | `V_DEBUG` | 3 | Detailed debugging output |
| Trace | `V_TRACE` | 4 | Full execution trace |

#### Logging Functions

```bash
trace "Very detailed info"      # V_TRACE (4) - Dim text
debug "Internal state: x=$x"    # V_DEBUG (3) - Cyan
info "Processing file..."       # V_NORMAL (1) - Green
warn "Deprecated feature"       # V_NORMAL (1) - Yellow, to stderr
error "Something went wrong"    # V_QUIET (0) - Red, to stderr
fatal "Cannot continue" $code   # V_QUIET (0) - Bold red, exits
```

#### Output Format

Log messages include timestamp, level, and message:
```
[2026-01-24 10:30:45] [INFO] Processing file...
[2026-01-24 10:30:45] [WARN] Deprecated feature
[2026-01-24 10:30:46] [ERROR] Something went wrong
```

#### Simple Output Functions

For non-logged output:

```bash
msg "Plain message"     # Only if VERBOSITY >= V_NORMAL
msgn "No newline..."    # Same, without trailing newline
```

#### Color Support

Colors are automatically enabled when:
- Output is to a terminal (`[[ -t 1 ]]`)
- `NO_COLOR` environment variable is not set

To disable colors:
```bash
NO_COLOR=1 ./my-script.sh
```

Available colors in the `COLORS` associative array:
- `reset`, `bold`, `dim`
- `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`

Usage:
```bash
printf '%b%s%b\n' "${COLORS[green]}" "Success!" "${COLORS[reset]}"
```

### Argument Parsing

The template supports multiple argument styles:

#### Supported Formats

| Style | Example | Description |
|-------|---------|-------------|
| Short option | `-v` | Single character |
| Short with value | `-c file.conf` | Value as next argument |
| Combined short | `-vvv` | Multiple verbosity |
| Long option | `--verbose` | Full word |
| Long with `=` | `--config=file.conf` | Value after equals |
| Long with space | `--config file.conf` | Value as next argument |
| End of options | `--` | Everything after is positional |

#### Built-in Options

| Short | Long | Description |
|-------|------|-------------|
| `-h` | `--help` | Show help and exit |
| `-V` | `--version` | Show version and exit |
| `-v` | `--verbose` | Increase verbosity (repeatable) |
| `-q` | `--quiet` | Suppress non-error output |
| `-n` | `--dry-run` | Simulate without executing |
| `-d` | `--debug` | Maximum verbosity + xtrace |
| `-c` | `--config` | Specify config file |
| `-o` | `--output` | Specify output file |

#### Adding New Options

See [Customization Guide - Adding Command-Line Options](#adding-new-command-line-options).

### Error Handling and Traps

The template sets up handlers for multiple signals:

| Signal | Handler | Purpose |
|--------|---------|---------|
| `EXIT` | `cleanup()` | Clean up temp files, always runs |
| `ERR` | `on_error()` | Log failed command details |
| `INT` | `on_signal()` | Handle Ctrl+C gracefully |
| `TERM` | `on_signal()` | Handle termination signal |
| `HUP` | `on_signal()` | Handle hangup signal |

#### Error Handler

When a command fails, `on_error()` logs:
- Exit code
- Line number
- Failed command
- Stack trace (if debug verbosity)

Example output:
```
[2026-01-24 10:30:45] [ERROR] Command failed with exit code 1
[2026-01-24 10:30:45] [ERROR]   Line: 42
[2026-01-24 10:30:45] [ERROR]   Command: grep "pattern" nonexistent.txt
```

#### Stack Traces

With debug verbosity (`-vvv` or `-d`), errors include a full stack trace:
```
[2026-01-24 10:30:45] [ERROR] Stack trace:
[2026-01-24 10:30:45] [ERROR]   at process_file() in ./my-script.sh:142
[2026-01-24 10:30:45] [ERROR]   at main() in ./my-script.sh:200
[2026-01-24 10:30:45] [ERROR]   at _main() in ./my-script.sh:250
```

#### Cleanup Handler

The `cleanup()` function always runs on exit and:
1. Removes all registered temp files
2. Removes the temp directory if created
3. Preserves the original exit code

### Dependency Validation

#### require_binary

Validates that a required binary exists. The script exits if not found.

```bash
require_binary curl                    # Must have curl
require_binary gawk awk mawk          # Prefers gawk, falls back to awk or mawk
```

When missing, provides installation instructions:
```
[ERROR] Required binary not found: jq
[ERROR] Tried: jq
[ERROR] Please install one of these packages:
[ERROR]   - Check your distribution's package manager
```

The found binary path is stored in `REQUIRED_BINARIES`:
```bash
require_binary awk gawk mawk
"${REQUIRED_BINARIES[awk]}" -F: '{print $1}' /etc/passwd
```

#### optional_binary

Registers a binary that enhances functionality but isn't required:

```bash
if optional_binary prettier; then
    "${OPTIONAL_BINARIES[prettier]}" output.json
else
    cat output.json  # Fallback
fi
```

#### get_command

Finds the first available command from a list:

```bash
SED=$(get_command gsed sed)  # Returns path to gsed or sed
```

#### command_exists

Simple existence check:

```bash
if command_exists docker; then
    # Docker is available
fi
```

### Temp File Management

#### create_temp_file

Creates a temporary file registered for automatic cleanup:

```bash
temp_file=$(create_temp_file)
echo "data" > "$temp_file"
# File is automatically deleted on exit
```

With suffix:
```bash
temp_json=$(create_temp_file ".json")
```

#### create_temp_dir

Creates a temporary directory registered for cleanup:

```bash
temp_dir=$(create_temp_dir)
cp files/* "$temp_dir/"
# Directory and contents deleted on exit
```

Note: Only one temp directory is created per script run. Subsequent calls return the same directory.

### Input Validation Helpers

#### validate_integer

```bash
validate_integer "42"           # Returns 0 (valid)
validate_integer "-5"           # Returns 0 (valid, negative allowed)
validate_integer "3.14"         # Returns 1 (invalid)
validate_integer "10" 1 100     # Returns 0 (within range 1-100)
validate_integer "0" 1          # Returns 1 (below minimum)
```

Usage pattern:
```bash
if ! validate_integer "$port" 1 65535; then
    fatal "Invalid port number: $port" $E_USAGE
fi
```

#### validate_string

```bash
validate_string "hello"         # Returns 0 (non-empty)
validate_string ""              # Returns 1 (empty, default min=1)
validate_string "hi" 3          # Returns 1 (too short, min=3)
validate_string "hello" 1 4     # Returns 1 (too long, max=4)
```

#### validate_file_readable

```bash
if ! validate_file_readable "$input_file"; then
    exit $E_NOINPUT
fi
```

Checks:
- File exists
- Is a regular file (not directory/device)
- Is readable

#### validate_dir_writable

```bash
if ! validate_dir_writable "$output_dir"; then
    exit $E_NOPERM
fi
```

Checks:
- Path exists
- Is a directory
- Is writable

#### sanitize_filename

Converts strings to safe filenames:

```bash
safe_name=$(sanitize_filename "My File (v2).txt")
# Result: "My_File_v2_.txt"
```

Replaces non-alphanumeric characters (except `.`, `_`, `-`) with underscores.

### Dry-Run Support

The `run()` function wraps command execution:

```bash
run rm -rf "$temp_dir"
run cp "$source" "$dest"
run curl -o output.json "$url"
```

In normal mode: Executes the command
In dry-run mode (`-n`): Prints what would be done

```bash
$ ./my-script.sh -n input.txt
[2026-01-24 10:30:45] [INFO] [DRY-RUN] Would execute: rm -rf /tmp/work
[2026-01-24 10:30:45] [INFO] [DRY-RUN] Would execute: cp input.txt /tmp/work/
```

### Configuration File Loading

#### Hierarchy

Configuration files are loaded in order (later files override earlier):

1. `/etc/{script_name}/{script_name}.conf`
2. `/etc/{script_name}.conf`
3. `~/.config/{script_name}/{script_name}.conf`
4. `~/.{script_name}.conf`
5. `./{script_name}.conf`
6. `${SCRIPT_NAME}_CONFIG_FILE` environment variable
7. `--config` command-line argument (highest priority)

#### Config File Format

Configuration files are shell-sourceable:

```bash
# my-script.conf

# Database settings
DB_HOST="localhost"
DB_PORT=5432
DB_NAME="myapp"

# Feature flags
ENABLE_CACHE=true
MAX_RETRIES=3
```

#### Accessing Config Values

After `load_configuration()`, variables are available globally:

```bash
main() {
    debug "Connecting to ${DB_HOST:-localhost}:${DB_PORT:-5432}"
}
```

Use `${VAR:-default}` for optional settings with fallbacks.

### Exit Codes

The template defines semantic exit codes based on BSD sysexits:

| Code | Constant | Meaning |
|------|----------|---------|
| 0 | `E_SUCCESS` | Success |
| 1 | `E_GENERAL` | General error |
| 2 | `E_USAGE` | Command syntax error |
| 66 | `E_NOINPUT` | Input file not found |
| 67 | `E_NOUSER` | User not found |
| 68 | `E_NOHOST` | Host not found |
| 69 | `E_UNAVAILABLE` | Service unavailable |
| 70 | `E_SOFTWARE` | Internal software error |
| 71 | `E_OSERR` | Operating system error |
| 72 | `E_OSFILE` | OS file missing |
| 73 | `E_CANTCREAT` | Cannot create file |
| 74 | `E_IOERR` | I/O error |
| 75 | `E_TEMPFAIL` | Temporary failure |
| 76 | `E_PROTOCOL` | Protocol error |
| 77 | `E_NOPERM` | Permission denied |
| 78 | `E_CONFIG` | Configuration error |

Usage:
```bash
fatal "Cannot read input file" $E_NOINPUT
exit $E_SUCCESS
```

---

## Customization Guide

### Adding New Command-Line Options

#### Step 1: Add to parse_arguments()

```bash
parse_arguments() {
    # ... existing code ...

    while [[ $# -gt 0 ]]; do
        case "$1" in
            # ... existing cases ...

            # Add your new option
            -f|--format)
                if [[ -z "${2:-}" ]]; then
                    error "Option --format requires an argument"
                    usage
                    exit $E_USAGE
                fi
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --format=*)
                OUTPUT_FORMAT="${1#*=}"
                shift
                ;;

            # Boolean flag
            --no-cache)
                USE_CACHE=false
                shift
                ;;
```

#### Step 2: Initialize the variable

Add defaults at the top of the script:

```bash
# ==============================================================================
# GLOBAL VARIABLES (mutable state)
# ==============================================================================

# ... existing variables ...

# Custom options
OUTPUT_FORMAT="text"
USE_CACHE=true
```

#### Step 3: Update help text

```bash
show_help() {
    cat <<EOF
# ... existing help ...

    -f, --format FORMAT     Output format: text, json, csv (default: text)
    --no-cache              Disable caching
EOF
}
```

#### Step 4: Validate if needed

```bash
validate_arguments() {
    # Validate format option
    case "${OUTPUT_FORMAT}" in
        text|json|csv) ;;
        *)
            error "Invalid format: ${OUTPUT_FORMAT}"
            error "Valid formats: text, json, csv"
            exit $E_USAGE
            ;;
    esac
}
```

### Adding New Required/Optional Dependencies

Edit `validate_dependencies()`:

```bash
validate_dependencies() {
    debug "Validating dependencies..."

    # Required binaries (script exits if missing)
    require_binary sed gsed
    require_binary awk gawk mawk
    require_binary curl                    # NEW: Required for API calls
    require_binary jq                      # NEW: Required for JSON parsing

    # Optional binaries (script continues if missing)
    optional_binary bat cat               # Prefer bat for syntax highlighting
    optional_binary rg grep               # Prefer ripgrep for searching

    if ! optional_binary pandoc; then
        warn "pandoc not found, PDF export disabled"
        ENABLE_PDF_EXPORT=false
    fi

    debug "All required dependencies satisfied"
}
```

To use the registered binaries:

```bash
main() {
    # Use required binary (guaranteed to exist)
    "${REQUIRED_BINARIES[curl]}" -s "$API_URL" | "${REQUIRED_BINARIES[jq]}" '.data'

    # Use optional binary with fallback
    if [[ -n "${OPTIONAL_BINARIES[bat]}" ]]; then
        "${OPTIONAL_BINARIES[bat]}" --style=plain "$file"
    else
        cat "$file"
    fi
}
```

### Implementing the main() Function

The `main()` function is where your script's core logic goes:

```bash
main() {
    debug "Starting main execution"

    # Access positional arguments
    local input_file="${POSITIONAL_ARGS[0]:-}"
    local output_file="${OUTPUT_FILE:-/dev/stdout}"

    # Validate inputs
    if [[ -z "$input_file" ]]; then
        error "No input file specified"
        usage
        exit $E_USAGE
    fi

    if ! validate_file_readable "$input_file"; then
        exit $E_NOINPUT
    fi

    # Create working directory
    local work_dir
    work_dir=$(create_temp_dir)

    # Process with dry-run support
    info "Processing ${input_file}..."
    run cp "$input_file" "$work_dir/input"

    # Your processing logic
    if [[ "$DRY_RUN" != true ]]; then
        "${REQUIRED_BINARIES[awk]}" '{print NR": "$0}' "$work_dir/input" > "$output_file"
    fi

    info "Output written to ${output_file}"
    return $E_SUCCESS
}
```

### Adding Custom Validation

Add new validation functions following the existing pattern:

```bash
# ==============================================================================
# INPUT VALIDATION (add after existing validators)
# ==============================================================================

# Validate email address format
# Globals: None
# Arguments:
#   $1 - Email address to validate
# Returns: 0 if valid, 1 if invalid
validate_email() {
    local email="$1"
    local pattern='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'

    if [[ ! "$email" =~ $pattern ]]; then
        return 1
    fi
    return 0
}

# Validate URL format
# Globals: None
# Arguments:
#   $1 - URL to validate
#   $2 - Optional: required protocol (http, https, ftp)
# Returns: 0 if valid, 1 if invalid
validate_url() {
    local url="$1"
    local protocol="${2:-}"
    local pattern='^(https?|ftp)://[A-Za-z0-9.-]+(/.*)?$'

    if [[ ! "$url" =~ $pattern ]]; then
        return 1
    fi

    if [[ -n "$protocol" ]] && [[ ! "$url" =~ ^${protocol}:// ]]; then
        return 1
    fi

    return 0
}

# Validate IP address (IPv4)
# Globals: None
# Arguments:
#   $1 - IP address to validate
# Returns: 0 if valid, 1 if invalid
validate_ipv4() {
    local ip="$1"
    local pattern='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ ! "$ip" =~ $pattern ]]; then
        return 1
    fi

    # Validate each octet is 0-255
    local IFS='.'
    read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if ((octet > 255)); then
            return 1
        fi
    done

    return 0
}
```

---

## Best Practices

### Do's

1. **Always use `run()` for side effects**
   ```bash
   run rm "$file"           # Good: supports dry-run
   rm "$file"               # Bad: no dry-run support
   ```

2. **Prefer `fatal()` over `error()` + `exit`**
   ```bash
   fatal "Cannot continue" $E_NOINPUT    # Good: consistent pattern
   error "Cannot continue"; exit 1       # Bad: verbose, magic number
   ```

3. **Use semantic exit codes**
   ```bash
   exit $E_NOINPUT         # Good: meaningful code
   exit 1                   # Bad: generic
   ```

4. **Register temp files immediately**
   ```bash
   temp=$(create_temp_file)  # Good: auto-cleaned
   temp=$(mktemp)            # Bad: may leak on error
   ```

5. **Validate early**
   ```bash
   validate_arguments() {
       # Check all inputs before doing any work
   }
   ```

6. **Use debug logging liberally**
   ```bash
   debug "Processing file: ${file}"
   debug "Result: ${result}"
   ```

7. **Quote all variables**
   ```bash
   echo "$variable"          # Good
   echo $variable            # Bad: word splitting
   ```

### Don'ts

1. **Don't bypass strict mode carelessly**
   ```bash
   set +e                    # Avoid unless absolutely necessary
   ```

2. **Don't use global variables without reason**
   ```bash
   local result              # Good: scoped to function
   RESULT=                   # Bad: pollutes global namespace
   ```

3. **Don't ignore return values**
   ```bash
   if ! some_command; then   # Good: handle failure
       handle_error
   fi
   some_command              # Bad: might fail silently (errexit aside)
   ```

4. **Don't hardcode paths**
   ```bash
   readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"  # Good
   readonly CONFIG_DIR="/home/user/.config"                  # Bad
   ```

5. **Don't forget documentation**
   ```bash
   # Validate that value is a positive integer
   # Globals: None
   # Arguments:
   #   $1 - Value to validate
   # Returns: 0 if valid, 1 if invalid
   validate_positive_int() {
   ```

---

## Examples

### Example 1: Simple File Processor

A script that processes text files with line numbering:

```bash
#!/usr/bin/env bash
# line-number.sh - Add line numbers to files

# ... template header ...

readonly SCRIPT_VERSION="1.0.0"

# Custom options
START_NUMBER=1
SEPARATOR=": "

show_help() {
    cat <<EOF
${SCRIPT_NAME} - Add line numbers to files

Usage:
    ${SCRIPT_NAME} [OPTIONS] <file>...

Options:
    -h, --help              Show this help message
    -s, --start NUM         Start numbering at NUM (default: 1)
    --separator SEP         Use SEP between number and line (default: ": ")
    -n, --dry-run           Show what would be done

Examples:
    ${SCRIPT_NAME} file.txt
    ${SCRIPT_NAME} -s 0 --separator=") " file.txt
EOF
}

parse_arguments() {
    local positional_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help; exit $E_SUCCESS ;;
            -s|--start)
                START_NUMBER="$2"
                shift 2
                ;;
            --start=*)
                START_NUMBER="${1#*=}"
                shift
                ;;
            --separator)
                SEPARATOR="$2"
                shift 2
                ;;
            --separator=*)
                SEPARATOR="${1#*=}"
                shift
                ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            -v|--verbose) ((VERBOSITY++)) || true; shift ;;
            --) shift; positional_args+=("$@"); break ;;
            -*) error "Unknown option: $1"; usage; exit $E_USAGE ;;
            *) positional_args+=("$1"); shift ;;
        esac
    done

    POSITIONAL_ARGS=("${positional_args[@]}")
}

validate_arguments() {
    if [[ ${#POSITIONAL_ARGS[@]} -lt 1 ]]; then
        error "At least one file required"
        usage
        exit $E_USAGE
    fi

    if ! validate_integer "$START_NUMBER" 0; then
        fatal "Start number must be a non-negative integer" $E_USAGE
    fi

    for file in "${POSITIONAL_ARGS[@]}"; do
        validate_file_readable "$file" || exit $E_NOINPUT
    done
}

validate_dependencies() {
    require_binary awk gawk mawk
}

process_file() {
    local file="$1"
    local start="$2"
    local sep="$3"

    info "Processing: ${file}"

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would number lines starting at ${start}"
        return 0
    fi

    "${REQUIRED_BINARIES[awk]}" -v start="$start" -v sep="$sep" \
        '{printf "%d%s%s\n", NR + start - 1, sep, $0}' "$file"
}

main() {
    for file in "${POSITIONAL_ARGS[@]}"; do
        process_file "$file" "$START_NUMBER" "$SEPARATOR"
    done

    return $E_SUCCESS
}
```

### Example 2: Script with Subcommands

A script with multiple subcommands like `git`:

```bash
#!/usr/bin/env bash
# project-tool.sh - Project management utility

# ... template header ...

readonly SCRIPT_VERSION="1.0.0"

# Subcommand
SUBCOMMAND=""

show_help() {
    cat <<EOF
${SCRIPT_NAME} - Project management utility

Usage:
    ${SCRIPT_NAME} <command> [OPTIONS] [ARGS]

Commands:
    init        Initialize a new project
    build       Build the project
    clean       Clean build artifacts
    status      Show project status

Options:
    -h, --help      Show this help (or command help)
    -v, --verbose   Increase verbosity

Run '${SCRIPT_NAME} <command> --help' for command-specific help.
EOF
}

show_init_help() {
    cat <<EOF
${SCRIPT_NAME} init - Initialize a new project

Usage:
    ${SCRIPT_NAME} init [OPTIONS] <project-name>

Options:
    --template NAME     Use template (default, minimal, full)
    -f, --force         Overwrite existing project
EOF
}

parse_arguments() {
    # First argument should be subcommand
    if [[ $# -lt 1 ]]; then
        error "No command specified"
        usage
        exit $E_USAGE
    fi

    SUBCOMMAND="$1"
    shift

    case "$SUBCOMMAND" in
        -h|--help)
            show_help
            exit $E_SUCCESS
            ;;
        init|build|clean|status)
            # Parse subcommand-specific arguments
            parse_subcommand_args "$SUBCOMMAND" "$@"
            ;;
        *)
            error "Unknown command: ${SUBCOMMAND}"
            usage
            exit $E_USAGE
            ;;
    esac
}

parse_subcommand_args() {
    local cmd="$1"
    shift
    local positional_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                "show_${cmd}_help" 2>/dev/null || show_help
                exit $E_SUCCESS
                ;;
            -v|--verbose)
                ((VERBOSITY++)) || true
                shift
                ;;
            --)
                shift
                positional_args+=("$@")
                break
                ;;
            -*)
                # Subcommand-specific options can be handled here
                error "Unknown option for ${cmd}: $1"
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

cmd_init() {
    local project_name="${POSITIONAL_ARGS[0]:-}"

    if [[ -z "$project_name" ]]; then
        fatal "Project name required" $E_USAGE
    fi

    info "Initializing project: ${project_name}"
    run mkdir -p "$project_name"/{src,tests,docs}
    run touch "$project_name/README.md"

    msg "Project ${project_name} initialized successfully"
}

cmd_build() {
    info "Building project..."
    # Build logic here
    msg "Build complete"
}

cmd_clean() {
    info "Cleaning build artifacts..."
    run rm -rf build/ dist/ *.o
    msg "Clean complete"
}

cmd_status() {
    info "Project status:"
    # Status logic here
    msg "All good"
}

main() {
    debug "Executing subcommand: ${SUBCOMMAND}"

    case "$SUBCOMMAND" in
        init)   cmd_init ;;
        build)  cmd_build ;;
        clean)  cmd_clean ;;
        status) cmd_status ;;
    esac

    return $E_SUCCESS
}
```

### Example 3: Using Validation Helpers

Comprehensive input validation:

```bash
#!/usr/bin/env bash
# deploy.sh - Deploy application to server

# ... template header ...

# Options
SERVER=""
PORT=22
USER=""
APP_DIR=""

validate_arguments() {
    # Validate server (required)
    if [[ -z "$SERVER" ]]; then
        fatal "Server address required (--server)" $E_USAGE
    fi

    # Validate server is hostname or IP
    if ! validate_hostname "$SERVER" && ! validate_ipv4 "$SERVER"; then
        fatal "Invalid server address: ${SERVER}" $E_USAGE
    fi

    # Validate port
    if ! validate_integer "$PORT" 1 65535; then
        fatal "Invalid port: ${PORT} (must be 1-65535)" $E_USAGE
    fi

    # Validate user (required, alphanumeric)
    if [[ -z "$USER" ]]; then
        fatal "Username required (--user)" $E_USAGE
    fi
    if ! [[ "$USER" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        fatal "Invalid username: ${USER}" $E_USAGE
    fi

    # Validate app directory (required, must exist locally)
    if [[ -z "$APP_DIR" ]]; then
        fatal "Application directory required (--app-dir)" $E_USAGE
    fi
    if ! validate_dir_writable "$(dirname "$APP_DIR")"; then
        fatal "Cannot write to parent of: ${APP_DIR}" $E_NOPERM
    fi

    # Validate deployment files exist
    for file in "${POSITIONAL_ARGS[@]}"; do
        if ! validate_file_readable "$file"; then
            exit $E_NOINPUT
        fi
    done

    debug "All arguments validated"
}

# Custom validator for hostnames
validate_hostname() {
    local hostname="$1"
    local pattern='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'

    [[ "$hostname" =~ $pattern ]]
}

main() {
    info "Deploying to ${USER}@${SERVER}:${PORT}"

    for file in "${POSITIONAL_ARGS[@]}"; do
        info "Uploading: ${file}"
        run scp -P "$PORT" "$file" "${USER}@${SERVER}:${APP_DIR}/"
    done

    info "Deployment complete"
    return $E_SUCCESS
}
```

---

## Troubleshooting

### Common Issues

#### "This script requires bash 4.0 or later"

**Cause:** Running on an older bash version (common on macOS).

**Solution:**
```bash
# Check your version
bash --version

# macOS: Install newer bash
brew install bash

# Run with explicit bash path
/opt/homebrew/bin/bash ./my-script.sh
```

#### "unbound variable" errors

**Cause:** Accessing undefined variable with `set -o nounset`.

**Solutions:**
```bash
# Use default values
echo "${UNDEFINED_VAR:-default}"

# Check if set
if [[ -v SOME_VAR ]]; then
    echo "$SOME_VAR"
fi

# For arrays
for item in "${ARRAY[@]:-}"; do
```

#### Cleanup not running

**Cause:** Script was killed with `SIGKILL` (kill -9) which cannot be caught.

**Solution:** Use regular termination (kill, Ctrl+C) instead of kill -9.

#### Colors not appearing

**Cause:** Output is redirected or `NO_COLOR` is set.

**Diagnosis:**
```bash
# Check if stdout is a terminal
[[ -t 1 ]] && echo "Is terminal" || echo "Not terminal"

# Check NO_COLOR
echo "${NO_COLOR:-not set}"
```

#### Config file not loading

**Cause:** Config file has syntax errors or wrong permissions.

**Diagnosis:**
```bash
# Check syntax
bash -n my-script.conf

# Check permissions
ls -la my-script.conf
```

#### Dry-run not working

**Cause:** Commands not wrapped with `run()`.

**Solution:** Wrap all side-effect commands:
```bash
run rm "$file"          # Respects --dry-run
rm "$file"              # Does NOT respect --dry-run
```

### Debugging Tips

1. **Enable debug output:**
   ```bash
   ./my-script.sh -d args...    # Maximum verbosity + xtrace
   ./my-script.sh -vvv args...  # Maximum verbosity
   ```

2. **Trace specific sections:**
   ```bash
   set -x  # Enable trace
   problematic_code_here
   set +x  # Disable trace
   ```

3. **Check variable state:**
   ```bash
   debug "VAR=${VAR:-unset} ARRAY=(${ARRAY[*]:-empty})"
   ```

4. **Test cleanup:**
   ```bash
   # Add to cleanup()
   debug "Cleanup called with exit code: $exit_code"
   ls -la "${TEMP_FILES[@]:-}"
   ```

---

## API Reference

### Logging Functions

| Function | Parameters | Output | Description |
|----------|------------|--------|-------------|
| `trace` | `message` | stdout | Trace-level message (verbosity 4+) |
| `debug` | `message` | stdout | Debug message (verbosity 3+) |
| `info` | `message` | stdout | Info message (verbosity 1+) |
| `warn` | `message` | stderr | Warning message (verbosity 1+) |
| `error` | `message` | stderr | Error message (always shown) |
| `fatal` | `message [exit_code]` | stderr | Error + exit (default code: 1) |
| `msg` | `message` | stdout | Plain message (verbosity 1+) |
| `msgn` | `message` | stdout | Plain message, no newline |

### Validation Functions

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `validate_integer` | `value [min] [max]` | 0/1 | Check if integer, optionally in range |
| `validate_string` | `value [min_len] [max_len]` | 0/1 | Check string length |
| `validate_file_readable` | `path` | 0/1 | Check file exists and is readable |
| `validate_dir_writable` | `path` | 0/1 | Check directory exists and is writable |
| `sanitize_filename` | `string` | stdout | Convert to safe filename |

### Dependency Functions

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `command_exists` | `name` | 0/1 | Check if command exists |
| `get_command` | `name [alternatives...]` | stdout, 0/1 | Get path to first available command |
| `require_binary` | `name [alternatives...]` | - | Register required binary (exits if missing) |
| `optional_binary` | `name [alternatives...]` | 0/1 | Register optional binary |

### Temp File Functions

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `create_temp_file` | `[suffix]` | stdout | Create registered temp file |
| `create_temp_dir` | - | stdout | Create registered temp directory |

### Utility Functions

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `run` | `command [args...]` | varies | Execute or simulate command |
| `load_config` | `path` | 0/1 | Load single config file |
| `load_configuration` | - | - | Load all config files |

### Trap Handlers

| Function | Trigger | Description |
|----------|---------|-------------|
| `cleanup` | EXIT | Remove temp files, restore state |
| `on_error` | ERR | Log failed command details |
| `on_signal` | INT/TERM/HUP | Log signal, exit with 128+signal |
| `print_stack_trace` | Called by on_error | Print function call stack |

### Constants

#### Exit Codes

| Constant | Value | Meaning |
|----------|-------|---------|
| `E_SUCCESS` | 0 | Success |
| `E_GENERAL` | 1 | General error |
| `E_USAGE` | 2 | Usage/syntax error |
| `E_NOINPUT` | 66 | Input not found |
| `E_NOUSER` | 67 | User not found |
| `E_NOHOST` | 68 | Host not found |
| `E_UNAVAILABLE` | 69 | Service unavailable |
| `E_SOFTWARE` | 70 | Internal error |
| `E_OSERR` | 71 | OS error |
| `E_OSFILE` | 72 | OS file missing |
| `E_CANTCREAT` | 73 | Cannot create file |
| `E_IOERR` | 74 | I/O error |
| `E_TEMPFAIL` | 75 | Temporary failure |
| `E_PROTOCOL` | 76 | Protocol error |
| `E_NOPERM` | 77 | Permission denied |
| `E_CONFIG` | 78 | Configuration error |

#### Verbosity Levels

| Constant | Value | Description |
|----------|-------|-------------|
| `V_QUIET` | 0 | Errors only |
| `V_NORMAL` | 1 | Standard output |
| `V_VERBOSE` | 2 | Detailed progress |
| `V_DEBUG` | 3 | Debug output |
| `V_TRACE` | 4 | Execution trace |

---

## License

This template is licensed under the Creative Commons Attribution-ShareAlike 4.0 International License.

See: http://creativecommons.org/licenses/by-sa/4.0/
