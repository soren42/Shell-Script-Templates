# Shell Script Templates

Production-ready templates for building robust, maintainable bash and zsh scripts with professional engineering standards.

[![License: CC BY-SA 4.0](https://img.shields.io/badge/License-CC%20BY--SA%204.0-lightgrey.svg)](http://creativecommons.org/licenses/by-sa/4.0/)
[![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)](https://github.com/yourusername/shell-templates/releases)

## Overview

This repository provides comprehensive templates for bash and zsh shell scripting that embody best practices for error handling, logging, dependency management, and user experience. Whether you’re building CLI tools, automation scripts, or system utilities, these templates give you a solid foundation to start from.

### Key Features

- **Strict Mode Execution** - Built-in error handling with `set -euo pipefail` (bash) or `setopt ERR_EXIT NO_UNSET PIPE_FAIL` (zsh)
- **Professional Logging** - Multi-level verbosity system with color support and timestamps
- **Flexible Argument Parsing** - POSIX, GNU, and combined short options (bash) or declarative `zparseopts` (zsh)
- **Automatic Cleanup** - Trap handlers ensure resources are freed even on errors or interrupts
- **Dependency Validation** - Check for required/optional binaries with helpful installation messages
- **Configuration Management** - Hierarchical config file loading from system to user to local
- **Input Validation** - Built-in helpers for integers, strings, files, and custom validation
- **Dry-Run Support** - Safe testing mode that shows what would be done without executing
- **Extensive Documentation** - Comprehensive developer guides with examples and API reference

## Quick Start

### Bash Template

```bash
# Copy the template
cp template.sh my-script.sh
chmod +x my-script.sh

# Update metadata
vim my-script.sh  # Edit SCRIPT_VERSION, SCRIPT_AUTHOR

# Implement your logic in main()
# Run it
./my-script.sh --help
./my-script.sh -vv input.txt
```

**Requirements:** Bash 4.0+

### Zsh Template

```bash
# Copy the template
cp template.zsh my-script.zsh
chmod +x my-script.zsh

# Update metadata
vim my-script.zsh  # Edit SCRIPT_VERSION, SCRIPT_AUTHOR

# Implement your logic in main()
# Optionally compile for faster loading
zcompile my-script.zsh

# Run it
./my-script.zsh --help
./my-script.zsh -vv input.txt
```

**Requirements:** Zsh 5.0+

## Template Comparison

|Feature             |Bash Template            |Zsh Template                  |
|--------------------|-------------------------|------------------------------|
|**Argument Parsing**|Manual case/while loop   |Declarative `zparseopts`      |
|**Array Indexing**  |0-based                  |1-based (default)             |
|**Command Checking**|`command -v`             |`$+commands[cmd]`             |
|**Trap Handling**   |`trap cmd SIGNAL`        |`TRAPSIGNAL() { }` functions  |
|**Stack Traces**    |`BASH_SOURCE`, `FUNCNAME`|`funcsourcetrace`, `funcstack`|
|**Compilation**     |Not supported            |`zcompile` for faster loading |
|**Floats**          |External (`bc`)          |Native `typeset -F`           |
|**Completion**      |Manual setup             |Built-in completion scaffold  |

## Core Capabilities

### Logging System

Five verbosity levels with color-coded output:

```bash
trace "Very detailed info"      # V_TRACE (4) - Dim
debug "Internal state: x=$x"    # V_DEBUG (3) - Cyan
info "Processing file..."       # V_NORMAL (1) - Green
warn "Deprecated feature"       # V_NORMAL (1) - Yellow
error "Something went wrong"    # V_QUIET (0) - Red
fatal "Cannot continue" $code   # V_QUIET (0) - Bold red, exits
```

Control verbosity with `-v` (repeatable), `-q` (quiet), or `-d` (debug with xtrace).

### Dependency Management

```bash
validate_dependencies() {
    # Required - script exits if missing
    require_binary curl
    require_binary jq
    
    # Optional - script continues with fallback
    optional_binary bat cat
    if ! optional_binary pandoc; then
        warn "pandoc not found, PDF export disabled"
    fi
}
```

Binaries are registered in associative arrays for easy access:

```bash
"${REQUIRED_BINARIES[curl]}" -s "$url" | "${REQUIRED_BINARIES[jq]}" '.data'
```

### Input Validation

Built-in validators for common types:

```bash
validate_integer "42" 1 100     # Integer in range
validate_string "hello" 1 50    # String length
validate_file_readable "$file"  # File exists and readable
validate_dir_writable "$dir"    # Directory exists and writable
sanitize_filename "My File!"    # Safe filename: "My_File_"
```

### Dry-Run Mode

Wrap commands with `run()` for automatic dry-run support:

```bash
run rm -rf "$temp_dir"
run cp "$source" "$dest"
```

When invoked with `--dry-run` or `-n`:

```
[INFO] [DRY-RUN] Would execute: rm -rf /tmp/work
[INFO] [DRY-RUN] Would execute: cp input.txt /tmp/work/
```

### Configuration Files

Hierarchical loading from multiple locations:

1. `/etc/{script_name}/{script_name}.conf`
2. `/etc/{script_name}.conf`
3. `~/.config/{script_name}/{script_name}.conf`
4. `~/.{script_name}.conf`
5. `./{script_name}.conf`
6. `${SCRIPT_NAME}_CONFIG_FILE` environment variable
7. `--config` command-line argument

Files are shell-sourceable:

```bash
# my-script.conf
DB_HOST="localhost"
DB_PORT=5432
ENABLE_CACHE=true
```

## Built-in Options

Both templates include these standard options:

|Short|Long       |Description                              |
|-----|-----------|-----------------------------------------|
|`-h` |`--help`   |Show help message and exit               |
|`-V` |`--version`|Show version and exit                    |
|`-v` |`--verbose`|Increase verbosity (repeatable: `-vvv`)  |
|`-q` |`--quiet`  |Suppress non-error output                |
|`-n` |`--dry-run`|Show what would be done without executing|
|`-d` |`--debug`  |Maximum verbosity plus xtrace            |
|`-c` |`--config` |Specify config file path                 |
|`-o` |`--output` |Specify output file                      |

## Documentation

Each template includes a comprehensive developer’s guide:

- **README-bash.md** - Complete documentation for the bash template
- **README-zsh.md** - Complete documentation for the zsh template including bash comparison

Topics covered:

- Architecture and execution flow
- Feature reference with examples
- Customization guide
- Best practices (do’s and don’ts)
- Real-world examples
- Troubleshooting guide
- Complete API reference

## Examples

### Simple File Processor

```bash
#!/usr/bin/env bash
# line-number.sh - Add line numbers to files

validate_dependencies() {
    require_binary awk gawk mawk
}

main() {
    local file="${POSITIONAL_ARGS[0]}"
    
    if ! validate_file_readable "$file"; then
        exit $E_NOINPUT
    fi
    
    info "Processing: ${file}"
    "${REQUIRED_BINARIES[awk]}" '{print NR": "$0}' "$file"
}
```

### Multi-Command Tool

```bash
#!/usr/bin/env bash
# project-tool.sh - Project management utility

parse_arguments() {
    SUBCOMMAND="$1"
    shift
    
    case "$SUBCOMMAND" in
        init|build|clean|status)
            parse_subcommand_args "$SUBCOMMAND" "$@"
            ;;
        *)
            error "Unknown command: ${SUBCOMMAND}"
            exit $E_USAGE
            ;;
    esac
}

main() {
    case "$SUBCOMMAND" in
        init)   cmd_init ;;
        build)  cmd_build ;;
        clean)  cmd_clean ;;
        status) cmd_status ;;
    esac
}
```

See the full developer guides for complete examples with validation, error handling, and more.

## Exit Codes

Both templates use semantic exit codes based on BSD sysexits:

|Code|Constant   |Meaning             |
|----|-----------|--------------------|
|0   |`E_SUCCESS`|Success             |
|2   |`E_USAGE`  |Command syntax error|
|66  |`E_NOINPUT`|Input file not found|
|77  |`E_NOPERM` |Permission denied   |
|78  |`E_CONFIG` |Configuration error |

Plus additional codes for software errors, I/O errors, network issues, and more.

## Error Handling

Comprehensive error handling with automatic cleanup:

```bash
# Automatic cleanup on exit
cleanup() {
    local exit_code=$?
    # Remove temp files
    # Restore state
    exit $exit_code
}

# Detailed error reporting
on_error() {
    local exit_code=$?
    error "Command failed with exit code ${exit_code}"
    error "  Line: ${BASH_LINENO[0]}"
    error "  Command: ${BASH_COMMAND}"
    # Stack trace in debug mode
}
```

## Customization

### Adding New Options

Both templates make it easy to add custom options:

**Bash:**

```bash
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            # ... other options
        esac
    done
}
```

**Zsh:**

```bash
parse_arguments() {
    zparseopts -D -E -F -K -- \
        f:=opt_format -format:=opt_format
    
    (( ${#opt_format} )) && OUTPUT_FORMAT=${opt_format[-1]}
}
```

### Custom Validation

Add domain-specific validators:

```bash
validate_email() {
    local email="$1"
    [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

validate_url() {
    local url="$1"
    [[ "$url" =~ ^(https?|ftp)://[A-Za-z0-9.-]+(/.*)?$ ]]
}
```

## Best Practices

### Do’s ✓

- Always use `run()` for commands with side effects
- Prefer `fatal()` over `error()` + `exit`
- Use semantic exit codes from constants
- Register temp files immediately after creation
- Validate inputs early in the script
- Quote all variables to prevent word splitting
- Use debug logging liberally

### Don’ts ✗

- Don’t bypass strict mode without good reason
- Don’t use global variables unnecessarily
- Don’t hardcode paths (use XDG_CONFIG_HOME, etc.)
- Don’t forget to document functions
- Don’t ignore return values
- Don’t use `path` as a variable name (shadows $PATH in zsh)

## Zsh-Specific Features

The zsh template includes features not available in bash:

- **zparseopts** - Declarative argument parsing
- **Native floats** - `typeset -F num=3.14`
- **Extended globbing** - `*.txt(.)` (regular files), `**/` (recursive)
- **TRAP functions** - `TRAPEXIT()`, `TRAPZERR()` instead of `trap`
- **Parameter flags** - `${(U)var}` (uppercase), `${(j:,:)arr}` (join)
- **Modules** - `zsh/datetime`, `zsh/stat` for performance
- **Compilation** - `zcompile` for faster loading
- **Completion scaffold** - Built-in tab completion support
- **oh-my-zsh integration** - Plugin structure included

## Requirements

### Bash Template

- Bash 4.0 or later
- Standard POSIX utilities (sed, awk, tr, mktemp)
- Works on Linux and macOS (with Homebrew bash on macOS)

### Zsh Template

- Zsh 5.0 or later
- Standard POSIX utilities (sed, awk, mktemp)
- Works on Linux and macOS

## Contributing

Contributions are welcome! Please:

1. Follow the existing code style and structure
2. Add tests for new functionality
3. Update documentation for changes
4. Use semantic commit messages

## License

These templates are licensed under the [Creative Commons Attribution-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-sa/4.0/).

You are free to:

- **Share** - Copy and redistribute the material
- **Adapt** - Remix, transform, and build upon the material

Under the following terms:

- **Attribution** - Give appropriate credit
- **ShareAlike** - Distribute derivatives under the same license

## Author

**jason c. kay**

Template Version: 3.0.0

-----

## Getting Started

1. **Choose your shell**: Pick the bash or zsh template based on your target environment
2. **Read the guide**: Review README-bash.md or README-zsh.md for comprehensive documentation
3. **Copy and customize**: Start with the template and adapt to your needs
4. **Test thoroughly**: Use `-n` (dry-run) and `-d` (debug) modes during development

For questions, issues, or suggestions, please open an issue on GitHub.