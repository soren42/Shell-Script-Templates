# Zsh Script Template - Developer's Guide

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
10. [Bash vs Zsh Comparison](#bash-vs-zsh-comparison)

---

## Overview

### What This Template Provides

This zsh template is a production-ready foundation for building robust, maintainable shell scripts that take full advantage of zsh's advanced features. It provides:

- **Strict mode execution** with comprehensive error handling via `setopt`
- **Professional logging system** with multiple verbosity levels and color support
- **Declarative argument parsing** using `zparseopts` for cleaner option handling
- **Automatic resource cleanup** via `TRAP*` functions
- **Dependency validation** using `$+commands[cmd]` syntax
- **Configuration file support** with hierarchical loading
- **Input validation helpers** for common data types
- **Dry-run mode** for safe testing
- **zcompile compatibility** for faster script loading
- **Completion system scaffold** for tab completion
- **oh-my-zsh integration** for plugin development

### Philosophy

This template follows several core principles:

1. **Fail Fast**: Use strict mode (`ERR_EXIT`, `NO_UNSET`, `PIPE_FAIL`) to catch errors immediately
2. **Clean Exit**: Always clean up resources, even on error or interrupt
3. **Explicit Over Implicit**: Validate inputs and dependencies before execution
4. **User-Friendly**: Provide helpful error messages, usage information, and dry-run support
5. **Zsh-Native**: Use zsh idioms and built-ins where they provide clear benefits over POSIX equivalents

### Requirements

- **Zsh 5.0+** (for full feature set including `zparseopts`, associative arrays, extended globbing)
- Standard POSIX utilities (`sed`, `awk`, `mktemp`)

### Compilation Support

This template is designed to be compatible with `zcompile`:

```zsh
zcompile template.zsh
# Creates template.zsh.zwc (zsh word code) for faster loading
```

Compiled scripts load faster because zsh skips parsing. The `.zwc` file is automatically used when present and newer than the source.

---

## Quick Start

### Creating a New Script

1. **Copy the template:**
   ```zsh
   cp template.zsh my-script.zsh
   chmod +x my-script.zsh
   ```

2. **Update the metadata** at the top of the file:
   ```zsh
   # my-script(1)
   #
   # Description:
   #   What your script does.
   ```

3. **Update script constants:**
   ```zsh
   typeset -gr SCRIPT_VERSION="1.0.0"
   typeset -gr SCRIPT_AUTHOR="Your Name <your@email.com>"
   ```

4. **Implement your logic** in the `main()` function:
   ```zsh
   main() {
       emulate -L zsh
       debug "Starting main execution"

       # Your code here
       local input_file="${POSITIONAL_ARGS[1]}"
       info "Processing: ${input_file}"

       return $E_SUCCESS
   }
   ```

5. **Update the help text** in `show_help()` and `usage()`

6. **Add dependencies** in `validate_dependencies()`:
   ```zsh
   validate_dependencies() {
       emulate -L zsh
       require_binary curl
       require_binary jq
       optional_binary prettier || warn "prettier not found, output won't be formatted"
   }
   ```

7. **Run your script:**
   ```zsh
   ./my-script.zsh --help
   ./my-script.zsh -v input.txt
   ./my-script.zsh --dry-run input.txt
   ```

8. **Optionally compile for faster loading:**
   ```zsh
   zcompile my-script.zsh
   ```

---

## Architecture

### Execution Flow

```
_main()
    |
    +-> init()
    |       |-> init_colors()      # Set up terminal colors
    |       +-> setup_traps()      # Confirm TRAP* handlers configured
    |
    +-> parse_arguments()          # Process options via zparseopts
    |
    +-> load_configuration()       # Load config files (hierarchical)
    |
    +-> validate_dependencies()    # Check required/optional binaries
    |
    +-> validate_arguments()       # Validate positional args
    |
    +-> main() {                   # YOUR IMPLEMENTATION
    |       ...
    |   } always {                 # Guaranteed cleanup block
    |       ...
    |   }
    |
    +-> exit $E_SUCCESS
            |
            +-> TRAPEXIT()         # Always runs on exit
```

### Code Organization

The template is organized into logical sections, each marked with a header:

| Section | Purpose |
|---------|---------|
| `ZSH STRICT MODE AND SHELL OPTIONS` | Shell configuration, `emulate -L zsh`, and version check |
| `CONSTANTS AND DEFAULTS` | Immutable values: script metadata, exit codes, verbosity levels |
| `GLOBAL VARIABLES` | Mutable state: verbosity, dry-run flag, temp files |
| `LOGGING AND OUTPUT` | Color initialization and logging functions |
| `ERROR HANDLING AND CLEANUP` | `TRAP*` functions and cleanup logic |
| `DEPENDENCY VALIDATION` | Binary checking using `$+commands` |
| `TEMP FILE MANAGEMENT` | Safe temporary file creation |
| `INPUT VALIDATION` | Data validation helpers |
| `USAGE AND HELP` | Help text and usage messages |
| `ARGUMENT PARSING` | `zparseopts`-based option processing |
| `DRY RUN SUPPORT` | Safe command execution wrapper |
| `CONFIGURATION` | Config file loading |
| `MAIN LOGIC` | User implementation area |
| `INITIALIZATION AND ENTRY POINT` | Startup sequence |
| `SOURCE GUARD AND EXECUTION` | Run vs source detection |
| `ZSH COMPLETION FUNCTION SCAFFOLD` | Tab completion template |
| `OH-MY-ZSH PLUGIN STRUCTURE` | Plugin integration guide |

### Global Variables

The template uses these key global variables:

| Variable | Type | Declaration | Description |
|----------|------|-------------|-------------|
| `VERBOSITY` | integer | `typeset -gi` | Current verbosity level (0-4) |
| `DRY_RUN` | boolean | `typeset -g` | Whether to simulate commands |
| `TEMP_FILES` | array | `typeset -ga` | Registered temp files for cleanup |
| `TEMP_DIR` | string | `typeset -g` | Registered temp directory for cleanup |
| `REQUIRED_BINARIES` | assoc array | `typeset -gA` | Map of required binary names to paths |
| `OPTIONAL_BINARIES` | assoc array | `typeset -gA` | Map of optional binary names to paths |
| `POSITIONAL_ARGS` | array | `typeset -ga` | Non-option arguments from command line |
| `COLORS` | assoc array | `typeset -gA` | Terminal color escape sequences |

### Zsh Variable Declaration Flags

| Flag | Meaning | Example |
|------|---------|---------|
| `-g` | Global scope | `typeset -g VAR=value` |
| `-r` | Read-only | `typeset -gr CONST=value` |
| `-i` | Integer | `typeset -gi COUNT=0` |
| `-a` | Indexed array | `typeset -ga ITEMS=()` |
| `-A` | Associative array | `typeset -gA MAP=()` |
| `-F` | Floating point | `typeset -F FLOAT=3.14` |

---

## Features Reference

### Strict Mode and Shell Options

The template establishes strict mode at startup using `setopt`:

```zsh
emulate -L zsh              # Reset to zsh defaults, local options

# Core strict mode (equivalent to bash set -euo pipefail)
setopt ERR_EXIT             # Exit on error (like set -e)
setopt NO_UNSET             # Error on undefined variables (like set -u)
setopt PIPE_FAIL            # Fail on first error in pipeline

# Additional safety
setopt WARN_CREATE_GLOBAL   # Warn if a global is created in a function
setopt NO_CLOBBER           # Don't overwrite files with > (use >| to override)
setopt LOCAL_OPTIONS        # Options set in functions are local
setopt LOCAL_TRAPS          # Traps set in functions are local
setopt LOCAL_PATTERNS       # Patterns set in functions are local
```

#### emulate -L zsh

Every function begins with `emulate -L zsh` which:
- Resets to zsh defaults (not ksh/sh compatibility mode)
- Makes option changes local to the function
- Ensures consistent behavior regardless of user's shell configuration

#### Handling Expected Failures

Sometimes you need commands that may fail. Use these patterns:

```zsh
# Pattern 1: Conditional execution
if ! some_command; then
    # Handle failure
fi

# Pattern 2: Explicit || true
(( counter++ )) || true  # Arithmetic returning 0 would trigger ERR_EXIT

# Pattern 3: Disable temporarily (use sparingly)
setopt LOCAL_OPTIONS NO_ERR_EXIT
risky_command
local result=$?
# ERR_EXIT automatically restored at function end
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

```zsh
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

The timestamp is generated using zsh's built-in `strftime`:

```zsh
zmodload -F zsh/datetime b:strftime
strftime -s timestamp '%Y-%m-%d %H:%M:%S'
```

#### Simple Output Functions

For non-logged output:

```zsh
msg "Plain message"     # Only if VERBOSITY >= V_NORMAL
msgn "No newline..."    # Same, without trailing newline
```

#### Color Support

Colors are automatically enabled when:
- Output is to a terminal (`[[ -t 1 ]]`)
- `NO_COLOR` environment variable is not set

To disable colors:
```zsh
NO_COLOR=1 ./my-script.zsh
```

Available colors in the `COLORS` associative array:
- `reset`, `bold`, `dim`
- `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`

Usage:
```zsh
print "${COLORS[green]}Success!${COLORS[reset]}"
```

### Argument Parsing with zparseopts

The template uses `zparseopts` from the `zsh/zutil` module for declarative argument parsing.

#### zparseopts Syntax

```zsh
zmodload zsh/zutil

zparseopts -D -E -F -K -- \
    h=opt_help     -help=opt_help \
    v+=opt_verbose -verbose+=opt_verbose \
    c:=opt_config  -config:=opt_config
```

| Flag | Meaning |
|------|---------|
| `-D` | Remove parsed options from positional parameters |
| `-E` | Don't stop at first non-option (allows mixed arguments) |
| `-F` | Fail on unknown options |
| `-K` | Keep default values in arrays |

#### Option Specifications

| Syntax | Meaning | Example |
|--------|---------|---------|
| `h` | Boolean flag | `-h` sets `opt_h` |
| `h=arr` | Store in array | `-h` adds to `arr` |
| `h+` | Repeatable | `-h -h -h` counts 3 |
| `h+=arr` | Repeatable into array | Each `-h` adds to `arr` |
| `c:` | Requires value | `-c value` |
| `c:=arr` | Value into array | `arr=(-c value)` |
| `-long` | Long option | `--long` |
| `-long:` | Long with value | `--long=value` or `--long value` |

#### Built-in Options

| Short | Long | Array | Description |
|-------|------|-------|-------------|
| `-h` | `--help` | `opt_help` | Show help and exit |
| `-V` | `--version` | `opt_version` | Show version and exit |
| `-v` | `--verbose` | `opt_verbose` | Increase verbosity (repeatable) |
| `-q` | `--quiet` | `opt_quiet` | Suppress non-error output |
| `-n` | `--dry-run` | `opt_dry_run` | Simulate without executing |
| `-d` | `--debug` | `opt_debug` | Maximum verbosity + xtrace |
| `-c` | `--config` | `opt_config` | Specify config file |
| `-o` | `--output` | `opt_output` | Specify output file |

#### Accessing Parsed Values

```zsh
# Boolean options: check array length
if (( ${#opt_help} )); then
    show_help
    exit $E_SUCCESS
fi

# Repeatable options: count occurrences
VERBOSITY=$(( V_NORMAL + ${#opt_verbose} ))

# Options with values: get last element
if (( ${#opt_config} )); then
    CONFIG_FILE=${opt_config[-1]}
fi
```

### Error Handling and TRAP Functions

Zsh uses specially-named functions for signal handling instead of the `trap` command:

| Function | Trigger | Purpose |
|----------|---------|---------|
| `TRAPEXIT` | Script exit | Clean up temp files, always runs |
| `TRAPZERR` | Non-zero exit | Log failed command details |
| `TRAPINT` | SIGINT (Ctrl+C) | Handle interrupt gracefully |
| `TRAPTERM` | SIGTERM | Handle termination signal |
| `TRAPHUP` | SIGHUP | Handle hangup signal |

#### TRAPZERR Handler

When a command fails, `TRAPZERR()` logs:
- Exit code
- Function name from `funcstack`
- Source location from `funcsourcetrace`
- Stack trace (if debug verbosity)

Example output:
```
[2026-01-24 10:30:45] [ERROR] Command failed with exit code 1
[2026-01-24 10:30:45] [ERROR]   Function: process_file
[2026-01-24 10:30:45] [ERROR]   Source: ./my-script.zsh:142
```

#### Stack Traces with funcstack and funcsourcetrace

Zsh provides built-in arrays for stack introspection:

| Array | Content |
|-------|---------|
| `funcstack` | Function names in call order |
| `funcsourcetrace` | Source file:line for each function |
| `funcfiletrace` | File:line where function was called from |
| `funcline` | Line numbers within functions |

With debug verbosity (`-vvv` or `-d`), errors include a full stack trace:
```
[2026-01-24 10:30:45] [ERROR] Stack trace:
[2026-01-24 10:30:45] [ERROR]   at process_file() in ./my-script.zsh:142
[2026-01-24 10:30:45] [ERROR]   at main() in ./my-script.zsh:200
[2026-01-24 10:30:45] [ERROR]   at _main() in ./my-script.zsh:250
```

#### TRAPEXIT Handler

The `TRAPEXIT()` function always runs on exit and:
1. Removes all registered temp files
2. Removes the temp directory if created
3. Preserves the original exit code

#### always Blocks

Zsh provides `always` blocks for guaranteed cleanup:

```zsh
{
    # Code that might fail
    risky_operation
} always {
    # This ALWAYS runs, even on error
    cleanup_resources
}
```

The template uses this pattern in `_main()` for function-specific cleanup.

### Dependency Validation

#### Command Existence with $+commands

Zsh provides the `$+commands` syntax for checking command availability:

```zsh
# Returns 1 if command exists, 0 if not
if (( $+commands[curl] )); then
    curl "$url"
fi

# The commands associative array maps names to paths
print $commands[curl]  # /usr/bin/curl
```

#### require_binary

Validates that a required binary exists. The script exits if not found.

```zsh
require_binary curl                    # Must have curl
require_binary gawk awk mawk           # Prefers gawk, falls back to awk or mawk
```

When missing, provides installation instructions:
```
[ERROR] Required binary not found: jq
[ERROR] Tried: jq
[ERROR] Please install one of these packages:
[ERROR]   - Check your distribution's package manager
```

The found binary path is stored in `REQUIRED_BINARIES`:
```zsh
require_binary awk gawk mawk
"${REQUIRED_BINARIES[awk]}" -F: '{print $1}' /etc/passwd
```

#### optional_binary

Registers a binary that enhances functionality but isn't required:

```zsh
if optional_binary prettier; then
    "${OPTIONAL_BINARIES[prettier]}" output.json
else
    cat output.json  # Fallback
fi
```

#### get_command

Finds the first available command from a list:

```zsh
SED=$(get_command gsed sed)  # Returns path to gsed or sed
```

### Temp File Management

#### create_temp_file

Creates a temporary file registered for automatic cleanup:

```zsh
temp_file=$(create_temp_file)
print "data" > "$temp_file"
# File is automatically deleted on exit
```

With suffix:
```zsh
temp_json=$(create_temp_file ".json")
```

#### create_temp_dir

Creates a temporary directory registered for cleanup:

```zsh
temp_dir=$(create_temp_dir)
cp files/* "$temp_dir/"
# Directory and contents deleted on exit
```

Note: Only one temp directory is created per script run. Subsequent calls return the same directory.

### Input Validation Helpers

#### validate_integer

```zsh
validate_integer "42"           # Returns 0 (valid)
validate_integer "-5"           # Returns 0 (valid, negative allowed)
validate_integer "3.14"         # Returns 1 (invalid)
validate_integer "10" 1 100     # Returns 0 (within range 1-100)
validate_integer "0" 1          # Returns 1 (below minimum)
```

Uses zsh's pattern matching:
```zsh
[[ $value == <-> ]] || [[ $value == -<-> ]]  # Match digits or negative digits
```

#### validate_float

Zsh natively supports floating-point arithmetic:

```zsh
validate_float "3.14"           # Returns 0 (valid)
validate_float "3.14" 0 3.2     # Returns 0 (within range)
validate_float "3.14" 0 3.0     # Returns 1 (above maximum)
```

#### validate_string

```zsh
validate_string "hello"         # Returns 0 (non-empty)
validate_string ""              # Returns 1 (empty, default min=1)
validate_string "hi" 3          # Returns 1 (too short, min=3)
validate_string "hello" 1 4     # Returns 1 (too long, max=4)
```

#### validate_file_readable

```zsh
if ! validate_file_readable "$input_file"; then
    exit $E_NOINPUT
fi
```

Checks:
- File exists
- Is a regular file (not directory/device)
- Is readable

#### validate_dir_writable

```zsh
if ! validate_dir_writable "$output_dir"; then
    exit $E_NOPERM
fi
```

Checks:
- Path exists
- Is a directory
- Is writable

#### sanitize_filename

Converts strings to safe filenames using zsh parameter expansion:

```zsh
safe_name=$(sanitize_filename "My File (v2).txt")
# Result: "My_File_v2_.txt"
```

Uses extended globbing for collapsing multiple underscores:
```zsh
sanitized=${input//[^[:alnum:]._-]/_}
sanitized=${sanitized//_(#c2,)/_}  # Collapse 2+ underscores
```

### Dry-Run Support

The `run()` function wraps command execution:

```zsh
run rm -rf "$temp_dir"
run cp "$source" "$dest"
run curl -o output.json "$url"
```

In normal mode: Executes the command
In dry-run mode (`-n`): Prints what would be done

```zsh
$ ./my-script.zsh -n input.txt
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

```zsh
# my-script.conf

# Database settings
DB_HOST="localhost"
DB_PORT=5432
DB_NAME="myapp"

# Feature flags
ENABLE_CACHE=true
MAX_RETRIES=3
```

#### Dynamic Environment Variable Lookup

The template uses zsh parameter expansion flags for dynamic variable names:

```zsh
# ${(U)var} - uppercase
# ${(P)var} - indirect expansion
local env_var="${(U)config_name//[^A-Za-z0-9]/_}_CONFIG_FILE"
if [[ -n "${(P)env_var:-}" ]]; then
    # Use the value from the environment variable
fi
```

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
```zsh
fatal "Cannot read input file" $E_NOINPUT
exit $E_SUCCESS
```

### zmodload - Loading Zsh Modules

The template uses zsh modules for enhanced functionality:

```zsh
# Load specific functions from zsh/datetime
zmodload -F zsh/datetime b:strftime

# Load zsh/zutil for zparseopts
zmodload zsh/zutil
```

Common modules:

| Module | Purpose | Functions/Features |
|--------|---------|-------------------|
| `zsh/datetime` | Date/time operations | `strftime`, `$EPOCHSECONDS` |
| `zsh/zutil` | Parsing utilities | `zparseopts`, `zformat` |
| `zsh/stat` | File statistics | `zstat` builtin |
| `zsh/mapfile` | File content as array | `$mapfile` associative array |
| `zsh/pcre` | Perl-compatible regex | `pcre_compile`, `pcre_match` |

### Extended Globbing

The template enables extended globbing with `setopt EXTENDED_GLOB`:

```zsh
# Glob qualifiers
print *.txt(.)       # Regular files only
print *(/)           # Directories only
print *(@)           # Symlinks only
print *(m-7)         # Modified in last 7 days
print *(om[1,5])     # 5 most recently modified

# Extended patterns
print file<1-10>.txt           # file1.txt through file10.txt
print *.(jpg|png|gif)          # Multiple extensions
print **/*.zsh                 # Recursive glob
print ^*.tmp                   # NOT matching *.tmp
print *(#c2,4)                 # 2-4 of preceding pattern
```

### Completion System Scaffold

The template includes a completion function scaffold:

```zsh
#compdef script_name

_script_name() {
    local -a options
    options=(
        '(-h --help)'{-h,--help}'[Show help message]'
        '(-V --version)'{-V,--version}'[Show version]'
        '*'{-v,--verbose}'[Increase verbosity]'
        '(-q --quiet)'{-q,--quiet}'[Suppress output]'
        '(-n --dry-run)'{-n,--dry-run}'[Dry run mode]'
        '(-d --debug)'{-d,--debug}'[Enable debug mode]'
        '(-c --config)'{-c,--config}'[Config file]:config file:_files'
        '(-o --output)'{-o,--output}'[Output file]:output file:_files'
    )

    _arguments -s $options '*:file:_files'
}

_script_name "$@"
```

To install: Save as `_script_name` in a directory in your `$fpath`.

### oh-my-zsh Integration

To use as an oh-my-zsh plugin:

```
~/.oh-my-zsh/custom/plugins/script_name/
    script_name.plugin.zsh    # Source script or define aliases/functions
    _script_name              # Completion function
```

Then add `script_name` to `plugins=(...)` in `~/.zshrc`.

---

## Customization Guide

### Adding New Command-Line Options with zparseopts

#### Step 1: Add option arrays and update zparseopts call

```zsh
parse_arguments() {
    emulate -L zsh
    zmodload zsh/zutil

    # Add new option arrays
    local -a opt_help opt_version opt_verbose opt_quiet opt_dry_run opt_debug
    local -a opt_config opt_output
    local -a opt_format opt_no_cache    # NEW: Custom options

    zparseopts -D -E -F -K -- \
        h=opt_help     -help=opt_help \
        V=opt_version  -version=opt_version \
        v+=opt_verbose -verbose+=opt_verbose \
        q=opt_quiet    -quiet=opt_quiet \
        n=opt_dry_run  -dry-run=opt_dry_run \
        d=opt_debug    -debug=opt_debug \
        c:=opt_config  -config:=opt_config \
        o:=opt_output  -output:=opt_output \
        f:=opt_format  -format:=opt_format \       # NEW: -f, --format (requires value)
        -no-cache=opt_no_cache \                    # NEW: --no-cache (boolean)
        || {
            usage
            exit $E_USAGE
        }

    # ... existing option processing ...

    # NEW: Process custom options
    if (( ${#opt_format} )); then
        OUTPUT_FORMAT=${opt_format[-1]}
    fi

    if (( ${#opt_no_cache} )); then
        USE_CACHE=false
    fi
}
```

#### Step 2: Initialize the variable

Add defaults in the global variables section:

```zsh
# ==============================================================================
# GLOBAL VARIABLES (mutable state)
# ==============================================================================

# ... existing variables ...

# Custom options
typeset -g OUTPUT_FORMAT="text"
typeset -g USE_CACHE=true
```

#### Step 3: Update help text

```zsh
show_help() {
    emulate -L zsh
    print -r -- "\
...existing help...

    -f, --format FORMAT     Output format: text, json, csv (default: text)
    --no-cache              Disable caching
"
}
```

#### Step 4: Validate if needed

```zsh
validate_arguments() {
    emulate -L zsh

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

```zsh
validate_dependencies() {
    emulate -L zsh
    debug "Validating dependencies..."

    # Required binaries (script will exit if any are missing)
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

```zsh
main() {
    emulate -L zsh

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

```zsh
main() {
    emulate -L zsh
    debug "Starting main execution"

    # Access positional arguments (zsh arrays are 1-indexed)
    local input_file="${POSITIONAL_ARGS[1]:-}"
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

```zsh
# ==============================================================================
# INPUT VALIDATION (add after existing validators)
# ==============================================================================

# Validate email address format
# Globals: None
# Arguments:
#   $1 - Email address to validate
# Returns: 0 if valid, 1 if invalid
validate_email() {
    emulate -L zsh
    local email=$1

    # Use zsh extended globbing pattern
    [[ $email == [[:alnum:]._%+-]##@[[:alnum:].-]##.[[:alpha:]](#c2,) ]]
}

# Validate URL format
# Globals: None
# Arguments:
#   $1 - URL to validate
#   $2 - Optional: required protocol (http, https, ftp)
# Returns: 0 if valid, 1 if invalid
validate_url() {
    emulate -L zsh
    local url=$1
    local protocol=${2:-}

    # Check basic URL structure
    [[ $url == (http|https|ftp)://* ]] || return 1

    # Check specific protocol if required
    [[ -z $protocol ]] || [[ $url == ${protocol}://* ]] || return 1

    return 0
}

# Validate IP address (IPv4)
# Globals: None
# Arguments:
#   $1 - IP address to validate
# Returns: 0 if valid, 1 if invalid
validate_ipv4() {
    emulate -L zsh
    local ip=$1

    # Use zsh pattern for basic format
    [[ $ip == <0-255>.<0-255>.<0-255>.<0-255> ]]
}
```

---

## Best Practices

### Do's

1. **Always start functions with `emulate -L zsh`**
   ```zsh
   my_function() {
       emulate -L zsh     # Good: consistent zsh behavior
       # function body
   }
   ```

2. **Always use `run()` for side effects**
   ```zsh
   run rm "$file"           # Good: supports dry-run
   rm "$file"               # Bad: no dry-run support
   ```

3. **Prefer `fatal()` over `error()` + `exit`**
   ```zsh
   fatal "Cannot continue" $E_NOINPUT    # Good: consistent pattern
   error "Cannot continue"; exit 1       # Bad: verbose, magic number
   ```

4. **Use semantic exit codes**
   ```zsh
   exit $E_NOINPUT         # Good: meaningful code
   exit 1                   # Bad: generic
   ```

5. **Register temp files immediately**
   ```zsh
   temp=$(create_temp_file)  # Good: auto-cleaned
   temp=$(mktemp)            # Bad: may leak on error
   ```

6. **Use zsh parameter expansion flags**
   ```zsh
   print "${(j:, :)array}"   # Good: join array with ", "
   print "${(U)string}"      # Good: uppercase
   print "${array[*]}" | tr ' ' ','  # Bad: external command
   ```

7. **Use `print` instead of `echo`**
   ```zsh
   print -- "$variable"      # Good: zsh native, handles -
   echo "$variable"          # Bad: inconsistent across shells
   ```

8. **Use debug logging liberally**
   ```zsh
   debug "Processing file: ${file}"
   debug "Result: ${result}"
   ```

9. **Use zsh's numeric ranges in patterns**
   ```zsh
   [[ $port == <1-65535> ]]  # Good: zsh native range
   [[ $port -ge 1 && $port -le 65535 ]]  # Bad: verbose
   ```

### Don'ts

1. **Don't use `path` as a local variable name**
   ```zsh
   local cmd_path            # Good: doesn't shadow $PATH
   local path                # Bad: shadows $PATH in subshells!
   ```

2. **Don't bypass strict mode carelessly**
   ```zsh
   setopt NO_ERR_EXIT        # Avoid unless absolutely necessary
   ```

3. **Don't use global variables without reason**
   ```zsh
   local result              # Good: scoped to function
   RESULT=                   # Bad: pollutes global namespace
   ```

4. **Don't forget `emulate -L zsh`**
   ```zsh
   my_func() {
       emulate -L zsh        # Good: consistent behavior
       local x=${1:-default}
   }
   my_func() {
       local x=${1:-default} # Bad: may behave differently based on user config
   }
   ```

5. **Don't hardcode paths**
   ```zsh
   typeset -gr CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"  # Good
   typeset -gr CONFIG_DIR="/home/user/.config"                  # Bad
   ```

6. **Don't forget documentation**
   ```zsh
   # Validate that value is a positive integer
   # Globals: None
   # Arguments:
   #   $1 - Value to validate
   # Returns: 0 if valid, 1 if invalid
   validate_positive_int() {
   ```

---

## Examples

### Example 1: Simple File Processor Using zsh Features

A script that processes text files with line numbering, using zsh-specific features:

```zsh
#!/usr/bin/env zsh
# line-number.zsh - Add line numbers to files

# ... template header ...

typeset -gr SCRIPT_VERSION="1.0.0"

# Custom options
typeset -gi START_NUMBER=1
typeset -g SEPARATOR=": "

show_help() {
    emulate -L zsh
    print -r -- "\
${SCRIPT_NAME} - Add line numbers to files

Usage:
    ${SCRIPT_NAME} [OPTIONS] <file>...

Options:
    -h, --help              Show this help message
    -s, --start NUM         Start numbering at NUM (default: 1)
    --separator SEP         Use SEP between number and line (default: \": \")
    -n, --dry-run           Show what would be done

Examples:
    ${SCRIPT_NAME} file.txt
    ${SCRIPT_NAME} -s 0 --separator=') ' file.txt
"
}

parse_arguments() {
    emulate -L zsh
    zmodload zsh/zutil

    local -a opt_help opt_dry_run opt_verbose
    local -a opt_start opt_separator

    zparseopts -D -E -F -K -- \
        h=opt_help      -help=opt_help \
        n=opt_dry_run   -dry-run=opt_dry_run \
        v+=opt_verbose  -verbose+=opt_verbose \
        s:=opt_start    -start:=opt_start \
        -separator:=opt_separator \
        || { usage; exit $E_USAGE }

    (( ${#opt_help} )) && { show_help; exit $E_SUCCESS }
    (( ${#opt_dry_run} )) && DRY_RUN=true
    (( ${#opt_verbose} )) && VERBOSITY=$(( V_NORMAL + ${#opt_verbose} ))

    (( ${#opt_start} )) && START_NUMBER=${opt_start[-1]}
    (( ${#opt_separator} )) && SEPARATOR=${opt_separator[-1]}

    POSITIONAL_ARGS=("$@")
}

validate_arguments() {
    emulate -L zsh

    if (( ${#POSITIONAL_ARGS} < 1 )); then
        error "At least one file required"
        usage
        exit $E_USAGE
    fi

    if ! validate_integer "$START_NUMBER" 0; then
        fatal "Start number must be a non-negative integer" $E_USAGE
    fi

    local file
    for file in "${POSITIONAL_ARGS[@]}"; do
        validate_file_readable "$file" || exit $E_NOINPUT
    done
}

validate_dependencies() {
    emulate -L zsh
    require_binary awk gawk mawk
}

process_file() {
    emulate -L zsh
    local file=$1
    local start=$2
    local sep=$3

    info "Processing: ${file}"

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would number lines starting at ${start}"
        return 0
    fi

    # Use zsh's native line reading for small files
    local -a lines
    lines=("${(@f)$(<$file)}")

    local i num
    for (( i = 1; i <= ${#lines}; i++ )); do
        num=$(( start + i - 1 ))
        print -- "${num}${sep}${lines[$i]}"
    done
}

main() {
    emulate -L zsh

    local file
    for file in "${POSITIONAL_ARGS[@]}"; do
        process_file "$file" "$START_NUMBER" "$SEPARATOR"
    done

    return $E_SUCCESS
}
```

### Example 2: Script with Subcommands

A script with multiple subcommands using zsh features:

```zsh
#!/usr/bin/env zsh
# project-tool.zsh - Project management utility

# ... template header ...

typeset -gr SCRIPT_VERSION="1.0.0"
typeset -g SUBCOMMAND=""
typeset -gA SUBCOMMAND_FUNCS=(
    init    cmd_init
    build   cmd_build
    clean   cmd_clean
    status  cmd_status
)

show_help() {
    emulate -L zsh
    print -r -- "\
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
"
}

show_init_help() {
    emulate -L zsh
    print -r -- "\
${SCRIPT_NAME} init - Initialize a new project

Usage:
    ${SCRIPT_NAME} init [OPTIONS] <project-name>

Options:
    --template NAME     Use template (default, minimal, full)
    -f, --force         Overwrite existing project
"
}

parse_arguments() {
    emulate -L zsh
    zmodload zsh/zutil

    # First argument should be subcommand
    if (( $# < 1 )); then
        error "No command specified"
        usage
        exit $E_USAGE
    fi

    SUBCOMMAND=$1
    shift

    case $SUBCOMMAND in
        -h|--help)
            show_help
            exit $E_SUCCESS
            ;;
        init|build|clean|status)
            parse_subcommand_args "$SUBCOMMAND" "$@"
            ;;
        *)
            error "Unknown command: ${SUBCOMMAND}"
            # Suggest similar commands using zsh's approximate matching
            local -a matches
            matches=(${(k)SUBCOMMAND_FUNCS[(R)*${SUBCOMMAND}*]})
            if (( ${#matches} )); then
                error "Did you mean: ${(j:, :)matches}?"
            fi
            usage
            exit $E_USAGE
            ;;
    esac
}

parse_subcommand_args() {
    emulate -L zsh
    local cmd=$1
    shift

    local -a opt_help opt_verbose

    zparseopts -D -E -K -- \
        h=opt_help -help=opt_help \
        v+=opt_verbose -verbose+=opt_verbose \
        || { usage; exit $E_USAGE }

    if (( ${#opt_help} )); then
        "show_${cmd}_help" 2>/dev/null || show_help
        exit $E_SUCCESS
    fi

    (( ${#opt_verbose} )) && VERBOSITY=$(( V_NORMAL + ${#opt_verbose} ))

    POSITIONAL_ARGS=("$@")
}

cmd_init() {
    emulate -L zsh
    local project_name="${POSITIONAL_ARGS[1]:-}"

    if [[ -z "$project_name" ]]; then
        fatal "Project name required" $E_USAGE
    fi

    info "Initializing project: ${project_name}"

    # Use zsh's brace expansion
    run mkdir -p "$project_name"/{src,tests,docs}
    run touch "$project_name/README.md"

    msg "Project ${project_name} initialized successfully"
}

cmd_build() {
    emulate -L zsh
    info "Building project..."
    # Build logic here
    msg "Build complete"
}

cmd_clean() {
    emulate -L zsh
    info "Cleaning build artifacts..."
    run rm -rf build/ dist/ *.o(N)  # (N) = nullglob for this pattern
    msg "Clean complete"
}

cmd_status() {
    emulate -L zsh
    info "Project status:"
    # Status logic here
    msg "All good"
}

main() {
    emulate -L zsh
    debug "Executing subcommand: ${SUBCOMMAND}"

    # Use associative array to dispatch
    if (( ${+SUBCOMMAND_FUNCS[$SUBCOMMAND]} )); then
        ${SUBCOMMAND_FUNCS[$SUBCOMMAND]}
    fi

    return $E_SUCCESS
}
```

### Example 3: Using zsh Parameter Expansion and Modules

A script demonstrating zsh-specific features:

```zsh
#!/usr/bin/env zsh
# file-stats.zsh - Display file statistics using zsh modules

# ... template header ...

typeset -gr SCRIPT_VERSION="1.0.0"
typeset -g OUTPUT_FORMAT="text"

validate_dependencies() {
    emulate -L zsh

    # Load zsh modules instead of external commands
    zmodload zsh/stat || fatal "Failed to load zsh/stat module" $E_SOFTWARE
    zmodload zsh/datetime || fatal "Failed to load zsh/datetime module" $E_SOFTWARE
}

# Format file size using zsh arithmetic
format_size() {
    emulate -L zsh
    local -i bytes=$1
    local -a units=(B KB MB GB TB)
    local -i unit_idx=0
    local -F2 size=$bytes

    while (( size >= 1024 && unit_idx < ${#units} - 1 )); do
        (( size /= 1024.0 ))
        (( unit_idx++ ))
    done

    printf "%.2f %s" $size ${units[$unit_idx + 1]}
}

# Format timestamp using zsh strftime
format_time() {
    emulate -L zsh
    local -i timestamp=$1
    strftime '%Y-%m-%d %H:%M:%S' $timestamp
}

process_file() {
    emulate -L zsh
    local file=$1

    # Use zsh's stat builtin
    local -A stat_info
    zstat -H stat_info "$file" || {
        error "Cannot stat file: ${file}"
        return 1
    }

    # Extract info using associative array
    local size=$(format_size ${stat_info[size]})
    local mtime=$(format_time ${stat_info[mtime]})
    local mode=${stat_info[mode]}
    local -i nlink=${stat_info[nlink]}

    case $OUTPUT_FORMAT in
        text)
            print "File: ${file}"
            print "  Size: ${size}"
            print "  Modified: ${mtime}"
            print "  Mode: ${mode}"
            print "  Links: ${nlink}"
            ;;
        json)
            # Use zsh parameter expansion for JSON escaping
            local escaped_file=${file//\\/\\\\}
            escaped_file=${escaped_file//\"/\\\"}
            print "{"
            print "  \"file\": \"${escaped_file}\","
            print "  \"size\": ${stat_info[size]},"
            print "  \"size_human\": \"${size}\","
            print "  \"mtime\": ${stat_info[mtime]},"
            print "  \"mtime_human\": \"${mtime}\","
            print "  \"mode\": \"${mode}\","
            print "  \"nlink\": ${nlink}"
            print "}"
            ;;
        csv)
            # Use zsh's join for CSV output
            print "${(j:,:)${(@qq):-$file $size $mtime $mode $nlink}}"
            ;;
    esac
}

main() {
    emulate -L zsh

    # Process files using zsh's glob qualifiers
    local file
    for file in "${POSITIONAL_ARGS[@]}"; do
        # Check if it's a glob pattern
        if [[ "$file" == *[\*\?\[]* ]]; then
            # Expand glob with qualifiers: . = regular files, N = nullglob
            local -a matches
            matches=( ${~file}(.N) )

            if (( ${#matches} == 0 )); then
                warn "No files match pattern: ${file}"
                continue
            fi

            local match
            for match in "${matches[@]}"; do
                process_file "$match"
            done
        else
            process_file "$file"
        fi
    done

    return $E_SUCCESS
}
```

---

## Troubleshooting

### Common Issues

#### "This script requires zsh 5.0 or later"

**Cause:** Running on an older zsh version.

**Solution:**
```zsh
# Check your version
zsh --version

# macOS: Install newer zsh
brew install zsh

# Linux: Use package manager
sudo apt install zsh  # Debian/Ubuntu
```

#### "unset variable" or "parameter not set" errors

**Cause:** Accessing undefined variable with `setopt NO_UNSET`.

**Solutions:**
```zsh
# Use default values
print "${UNDEFINED_VAR:-default}"

# Check if set
if (( ${+SOME_VAR} )); then
    print "$SOME_VAR"
fi

# For arrays
for item in "${(@)ARRAY:-}"; do
```

#### "unknown option" from zparseopts

**Cause:** `-F` flag makes zparseopts strict about unknown options.

**Solutions:**
```zsh
# Remove -F to allow unknown options (passed to POSITIONAL_ARGS)
zparseopts -D -E -K -- ...

# Or handle unknown options explicitly
zparseopts -D -E -F -K -- ... 2>/dev/null || {
    local unknown=${1:-}
    error "Unknown option: ${unknown}"
    # Suggest similar options
    usage
    exit $E_USAGE
}
```

#### Command fails in subshell with "command not found"

**Cause:** Using `local path` which shadows the global `$PATH` in zsh.

**Solution:**
```zsh
# DON'T use 'path' as a variable name
local path=$(get_command ...)   # BAD: shadows $PATH

# Use a different name
local cmd_path=$(get_command ...)  # GOOD
local bin_path=$(get_command ...)  # GOOD
```

#### Cleanup not running

**Cause:** Script was killed with `SIGKILL` (kill -9) which cannot be caught.

**Solution:** Use regular termination (kill, Ctrl+C) instead of kill -9.

#### Colors not appearing

**Cause:** Output is redirected or `NO_COLOR` is set.

**Diagnosis:**
```zsh
# Check if stdout is a terminal
[[ -t 1 ]] && print "Is terminal" || print "Not terminal"

# Check NO_COLOR
print "${NO_COLOR:-not set}"
```

#### Config file not loading

**Cause:** Config file has syntax errors or wrong permissions.

**Diagnosis:**
```zsh
# Check syntax
zsh -n my-script.conf

# Check permissions
ls -la my-script.conf
```

#### zcompile fails or compiled script misbehaves

**Cause:** Script has syntax that cannot be compiled or compiled file is stale.

**Solutions:**
```zsh
# Remove existing compiled file
rm -f script.zsh.zwc

# Check for syntax errors
zsh -n script.zsh

# Recompile
zcompile script.zsh
```

### Debugging Tips

1. **Enable debug output:**
   ```zsh
   ./my-script.zsh -d args...    # Maximum verbosity + xtrace
   ./my-script.zsh -vvv args...  # Maximum verbosity
   ```

2. **Trace specific sections:**
   ```zsh
   setopt XTRACE   # Enable trace
   problematic_code_here
   unsetopt XTRACE # Disable trace
   ```

3. **Check variable state:**
   ```zsh
   debug "VAR=${VAR:-unset} ARRAY=(${(@)ARRAY:-empty})"
   ```

4. **Inspect funcstack:**
   ```zsh
   debug "Call stack: ${(j: -> :)funcstack}"
   ```

5. **Test cleanup:**
   ```zsh
   # Add to TRAPEXIT()
   debug "Cleanup called with exit code: $exit_code"
   debug "Temp files: ${(@)TEMP_FILES:-none}"
   ```

6. **Check loaded modules:**
   ```zsh
   zmodload  # List all loaded modules
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
| `validate_float` | `value [min] [max]` | 0/1 | Check if float, optionally in range |
| `validate_string` | `value [min_len] [max_len]` | 0/1 | Check string length |
| `validate_file_readable` | `path` | 0/1 | Check file exists and is readable |
| `validate_dir_writable` | `path` | 0/1 | Check directory exists and is writable |
| `sanitize_filename` | `string` | stdout | Convert to safe filename |

### Dependency Functions

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `command_exists` | `name` | 0/1 | Check if command exists (uses `$+commands`) |
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

### TRAP Functions

| Function | Trigger | Description |
|----------|---------|-------------|
| `TRAPEXIT` | Script exit | Remove temp files, restore state |
| `TRAPZERR` | Non-zero exit | Log failed command details |
| `TRAPINT` | SIGINT (Ctrl+C) | Log signal, return 130 |
| `TRAPTERM` | SIGTERM | Log signal, return 143 |
| `TRAPHUP` | SIGHUP | Log signal, return 129 |
| `print_stack_trace` | Called by TRAPZERR | Print function call stack |

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

## Bash vs Zsh Comparison

This section helps users familiar with the bash template understand zsh equivalents.

### Shell Initialization

| Bash | Zsh | Notes |
|------|-----|-------|
| `set -e` | `setopt ERR_EXIT` | Exit on error |
| `set -u` | `setopt NO_UNSET` | Error on undefined |
| `set -o pipefail` | `setopt PIPE_FAIL` | Pipeline error handling |
| N/A | `emulate -L zsh` | Reset to zsh defaults |
| N/A | `setopt LOCAL_OPTIONS` | Options local to function |

### Variable Declaration

| Bash | Zsh | Notes |
|------|-----|-------|
| `declare -r VAR=x` | `typeset -gr VAR=x` | Read-only global |
| `declare -i VAR=0` | `typeset -gi VAR=0` | Integer global |
| `declare -a ARR=()` | `typeset -ga ARR=()` | Array global |
| `declare -A MAP=()` | `typeset -gA MAP=()` | Associative array global |
| `readonly VAR=x` | `typeset -gr VAR=x` | Alternative |
| `local var` | `local var` | Same |

### Script Path

| Bash | Zsh | Notes |
|------|-----|-------|
| `${BASH_SOURCE[0]}` | `${(%):-%x}` | Current script path |
| `$(dirname ...)` | `${var:h}` | Parent directory |
| `$(basename ...)` | `${var:t}` | Filename only |
| `$(realpath ...)` | `${var:A}` | Absolute path |

### Argument Parsing

| Bash | Zsh | Notes |
|------|-----|-------|
| `while [[ $# -gt 0 ]]; do case...` | `zparseopts -D -E -F` | Declarative parsing |
| Manual shift logic | Automatic with `-D` | zparseopts removes parsed |
| `getopts` | `zparseopts` | More powerful |

### Command Existence

| Bash | Zsh | Notes |
|------|-----|-------|
| `command -v cmd` | `$+commands[cmd]` | Returns 1 if exists |
| `type cmd` | `whence cmd` | With output |
| `hash cmd` | `(( $+commands[cmd] ))` | For conditionals |

### Trap Handling

| Bash | Zsh | Notes |
|------|-----|-------|
| `trap cleanup EXIT` | `TRAPEXIT() { ... }` | Exit handler |
| `trap on_error ERR` | `TRAPZERR() { ... }` | Error handler |
| `trap on_int INT` | `TRAPINT() { ... }` | Interrupt handler |
| `trap on_term TERM` | `TRAPTERM() { ... }` | Termination handler |
| `trap on_hup HUP` | `TRAPHUP() { ... }` | Hangup handler |

### Stack Traces

| Bash | Zsh | Notes |
|------|-----|-------|
| `${FUNCNAME[@]}` | `$funcstack` | Function names |
| `${BASH_SOURCE[@]}` | `$funcsourcetrace` | Source locations |
| `${BASH_LINENO[@]}` | `$funcfiletrace` | Call locations |

### Array Operations

| Bash | Zsh | Notes |
|------|-----|-------|
| `${arr[0]}` | `${arr[1]}` | Zsh is 1-indexed by default |
| `${arr[@]}` | `${(@)arr}` | Quote each element |
| `${#arr[@]}` | `${#arr}` | Array length |
| `${!arr[@]}` | `${(k)arr}` | Keys (associative) |

### Parameter Expansion

| Bash | Zsh | Notes |
|------|-----|-------|
| `${var^^}` | `${(U)var}` | Uppercase |
| `${var,,}` | `${(L)var}` | Lowercase |
| `IFS=, read -ra arr <<< "$str"` | `arr=(${(s:,:)str})` | Split string |
| `$(IFS=,; echo "${arr[*]}")` | `${(j:,:)arr}` | Join array |
| `${!varname}` | `${(P)varname}` | Indirect expansion |

### Pattern Matching

| Bash | Zsh | Notes |
|------|-----|-------|
| `shopt -s extglob; @(a|b)` | `setopt EXTENDED_GLOB; (a|b)` | Extended patterns |
| `shopt -s globstar; **/*.txt` | `**/*.txt` | Recursive glob (default) |
| `shopt -s nullglob` | `setopt NULL_GLOB` or `*(N)` | No matches = empty |

### Arithmetic

| Bash | Zsh | Notes |
|------|-----|-------|
| `(( x++ ))` | `(( x++ ))` | Same |
| `$((x + y))` | `$((x + y))` | Same |
| N/A | `typeset -F num; num=3.14` | Native float support |
| `bc <<< "3.14 * 2"` | `(( result = 3.14 * 2 ))` | Float arithmetic |

### Output

| Bash | Zsh | Notes |
|------|-----|-------|
| `echo "$msg"` | `print -- "$msg"` | Use print in zsh |
| `echo -n "$msg"` | `print -n -- "$msg"` | No newline |
| `echo "$msg" >&2` | `print -u2 -- "$msg"` | To stderr |
| `printf '%s' "$msg"` | `printf '%s' "$msg"` | Same |

### Always Block (Guaranteed Cleanup)

| Bash | Zsh |
|------|-----|
| `trap cleanup EXIT; risky_code; cleanup` | `{ risky_code } always { cleanup }` |

### Modules vs External Commands

| Bash | Zsh | Notes |
|------|-----|-------|
| `date +%Y` | `zmodload zsh/datetime; strftime` | Date formatting |
| `stat file` | `zmodload zsh/stat; zstat` | File stats |
| `cat file` | `$(<file)` or `zmodload zsh/mapfile` | Read file |

---

## License

This template is licensed under the Creative Commons Attribution-ShareAlike 4.0 International License.

See: http://creativecommons.org/licenses/by-sa/4.0/
