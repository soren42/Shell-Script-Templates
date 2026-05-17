# Shell Script Templates

Production-ready templates for building robust, maintainable bash and zsh scripts with professional engineering standards.

[![License: CC BY-SA 4.0](https://img.shields.io/badge/License-CC%20BY--SA%204.0-lightgrey.svg)](http://creativecommons.org/licenses/by-sa/4.0/)
[![Version](https://img.shields.io/badge/version-4.1.0-blue.svg)](https://github.com/soren42/Shell-Script-Templates/releases)
[![Shell](https://img.shields.io/badge/shell-bash%204.0%2B%20%7C%20zsh%205.0%2B-green.svg)]()

## What's New in v4

**Version 4.1.0** is a major release introducing three key innovations:

- **Feature Flags** — Configurable behavior flags at the top of every script control execution requirements, capability toggles, and runtime validation
- **Initialization Wizard** — An interactive tool (`init-script.sh`) that generates customized scripts through guided prompts, with support for porting v1–v3 scripts
- **Plugin System** — A modular architecture for extending scripts with reusable functionality, shipping with four core plugins

## Overview

This repository provides comprehensive templates for bash and zsh shell scripting that embody best practices for error handling, logging, dependency management, and user experience. Whether you're building CLI tools, automation scripts, or system utilities, these templates give you a solid foundation to start from.

### Key Features

- **Strict Mode Execution** — Built-in error handling with `set -euo pipefail` (bash) or `setopt ERR_EXIT NO_UNSET PIPE_FAIL` (zsh)
- **Feature Flag System** — 15+ configurable flags controlling script behavior, validated at startup
- **Professional Logging** — Five-level verbosity system with color support and timestamps
- **Flexible Argument Parsing** — POSIX/GNU options (bash) or declarative `zparseopts` (zsh)
- **Plugin Architecture** — Extend scripts with modular, reusable functionality
- **Automatic Cleanup** — Trap handlers ensure resources are freed even on errors
- **Dependency Validation** — Required/optional binary checking with fallback chains
- **Configuration Management** — Hierarchical config file loading (7-level precedence)
- **Input Validation** — Built-in helpers for integers, floats, strings, files, and more
- **Dry-Run Support** — Safe testing mode via `run()` wrapper
- **Self-Test Framework** — Built-in testing with `--self-test` flag
- **AI/CI Integration** — `--non-interactive` mode for programmatic script generation

## Quick Start

### Using the Initialization Wizard (Recommended)

```bash
# Run the interactive wizard
./init-script.sh

# Pre-fill shell type and name
./init-script.sh --shell bash --name deploy-tool

# Port an existing script to v4
./init-script.sh --port my-old-script.sh

# Fully automated (for CI/AI integration)
./init-script.sh --non-interactive --shell zsh --name backup
```

The wizard walks you through shell selection, metadata, feature flags, dependencies, argument definitions, plugin selection, and test scaffolding — then generates a ready-to-implement script.

### Manual Setup

```bash
# Copy the template
cp templates/template.sh my-script.sh
chmod +x my-script.sh

# Edit metadata, feature flags, and implement main()
vim my-script.sh

# Run it
./my-script.sh --help
```

## Feature Flags

Every script starts with a feature flag section that controls behavior:

```bash
# Execution Requirements
readonly REQUIRE_ROOT=false
readonly REQUIRES_NETWORK=false
readonly REQUIRES_DISK_SPACE=false

# Capabilities
readonly SUPPORTS_DRY_RUN=true
readonly IDEMPOTENT=false
readonly INTERACTIVE=false

# Feature Toggles
readonly HAS_EXTERNAL_DEPENDENCIES=true
readonly USES_CONFIG_FILES=true
readonly VERBOSE_BY_DEFAULT=false
readonly INCLUDES_SELF_TEST=false

# Plugin System
readonly ENABLED_PLUGINS="ai-integration,http-client"
```

Flags trigger automatic pre-flight validation: root privilege checks, network connectivity tests, disk space verification, and environment validation all happen before your `main()` function runs.

Command-line arguments always override internal flag values, giving the user closest to runtime the final say.

## Plugin System

Plugins extend script functionality through a simple, file-based architecture:

```
~/.shell-script-templates/plugins/
  plugin-name/
    plugin.conf      # Metadata and configuration
    functions.sh     # Shell functions
    init.sh          # Initialization code
```

### Core Plugins (Included)

| Plugin | Description |
|--------|-------------|
| **ai-integration** | Unified LLM API interface for Claude, GPT, and Gemini |
| **cloud-storage** | S3, GCS, and S3-compatible storage operations |
| **completions** | Generate and install bash/zsh tab-completion scripts |
| **config-advanced** | INI/TOML parsing, dotenv loading, environment validation |
| **database** | Unified helpers for SQLite, PostgreSQL, and MySQL/MariaDB |
| **http-client** | HTTP operations with retry logic, auth, and error handling |
| **json-parser** | jq wrapper for JSON parsing, validation, and generation |
| **logging-extended** | Syslog, journald integration, and log file rotation |
| **notification** | Send alerts via ntfy, email, and Slack/Discord webhooks |
| **parallel** | Concurrent execution via GNU parallel, xargs, or job control |
| **tui** | Text UI with gum/dialog/whiptail backends and ANSI fallback |
| **yaml** | YAML parsing and manipulation via yq |

### Plugin Usage

Enable plugins in the feature flags:
```bash
readonly ENABLED_PLUGINS="ai-integration,json-parser"
```

Then use plugin functions in your `main()`:
```bash
main() {
    # AI integration
    response=$(ai_query "Summarize this log" --input "$(cat /var/log/app.log)")

    # HTTP client
    data=$(http_get "https://api.example.com/status" --bearer "$TOKEN")

    # JSON parser
    version=$(json_get "$data" '.version')

    # TUI
    choice=$(tui_choose "Select environment" "dev" "staging" "production")
}
```

See [PLUGIN_DEVELOPMENT.md](docs/PLUGIN_DEVELOPMENT.md) for creating custom plugins.

## Template Comparison

| Feature | Bash Template | Zsh Template |
|---------|---------------|--------------|
| **Argument Parsing** | Manual case/while loop | Declarative `zparseopts` |
| **Array Indexing** | 0-based | 1-based |
| **Command Checking** | `command -v` | `$+commands[cmd]` |
| **Trap Handling** | `trap cmd SIGNAL` | `TRAPSIGNAL()` functions |
| **Stack Traces** | `BASH_SOURCE`, `FUNCNAME` | `funcsourcetrace`, `funcstack` |
| **Compilation** | Not supported | `zcompile` for faster loading |
| **Floats** | External (`bc`) | Native `typeset -F` |
| **Completion** | Manual setup | Built-in scaffold |

## Repository Structure

```
Shell-Script-Templates/
├── templates/
│   ├── template.sh          # Bash v4 template
│   └── template.zsh         # Zsh v4 template
├── init-script.sh           # Interactive wizard
├── plugins/
│   ├── ai-integration/      # LLM API plugin
│   ├── cloud-storage/       # S3/GCS operations
│   ├── completions/         # Tab-completion generator
│   │   └── shipped/         # Pre-built completions for init-script
│   ├── config-advanced/     # INI/TOML/dotenv parsing
│   ├── database/            # SQLite/PostgreSQL/MySQL helpers
│   ├── http-client/         # HTTP operations plugin
│   ├── json-parser/         # JSON utilities plugin
│   ├── logging-extended/    # Syslog/journald/log rotation
│   ├── notification/        # ntfy/email/webhook alerts
│   ├── parallel/            # Concurrent execution
│   ├── tui/                 # Text UI plugin
│   └── yaml/                # YAML parsing via yq
├── docs/
│   ├── README-bash.md       # Bash template guide
│   ├── README-zsh.md        # Zsh template guide
│   └── PLUGIN_DEVELOPMENT.md
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Built-in Options

Both templates include these standard command-line options:

| Short | Long | Description |
|-------|------|-------------|
| `-h` | `--help` | Show help message and exit |
| `-V` | `--version` | Show version and exit |
| `-v` | `--verbose` | Increase verbosity (repeatable: `-vvv`) |
| `-q` | `--quiet` | Suppress non-error output |
| `-n` | `--dry-run` | Show what would be done without executing |
| `-d` | `--debug` | Maximum verbosity plus xtrace |
| `-c` | `--config` | Specify config file path |
| `-o` | `--output` | Specify output file |
| | `--self-test` | Run internal self-tests and exit |

## Self-Test Framework

Scripts include built-in test functions that verify core functionality:

```bash
# Run self-tests
./my-script.sh --self-test

# Output:
# [INFO] Running self-tests...
# [INFO] Validation function tests passed
# [INFO] Dependency check tests passed
# All self-tests passed
```

The initialization wizard can also generate standalone test files with assertion helpers for more comprehensive testing.

## Tab Completion

The initialization wizard automatically generates both bash and zsh completion scripts when creating a new script. These provide tab-completion for all built-in and custom CLI options.

```bash
# Install bash completions
cp my-script.bash-completion ~/.local/share/bash-completion/completions/my-script

# Install zsh completions
cp _my-script ~/.zsh/completions/
autoload -Uz compinit && compinit
```

Pre-built completions for `init-script.sh` itself ship in `plugins/completions/shipped/`. The completions plugin also provides a programmatic API for generating and installing completions at any time:

```bash
# Generate completions for an existing script (reads its --help output)
completions_generate /path/to/my-script.sh

# Install to detected default directory
completions_install my-script.bash-completion bash
completions_install _my-script zsh

# List installed completions
completions_list
```

## AI and CI Integration

The `--non-interactive` flag enables fully automated script generation:

```bash
# Generate a script programmatically
./init-script.sh \
    --non-interactive \
    --shell bash \
    --name deploy-service \
    --output /path/to/project/
```

This makes the templates accessible to AI coding assistants (Claude, Codex, Gemini) and CI/CD pipelines that need to scaffold shell scripts without human interaction.

## Requirements

### Bash Template
- Bash 4.0 or later
- Standard POSIX utilities (sed, awk, tr, mktemp)

### Zsh Template
- Zsh 5.0 or later
- Standard POSIX utilities (sed, awk, mktemp)

### Plugins
- **ai-integration**: curl, jq, and an API key for your chosen provider
- **cloud-storage**: aws CLI (for S3/S3-compatible) or gsutil/gcloud (for GCS)
- **completions**: No external dependencies
- **config-advanced**: yq (for TOML; INI/dotenv/env validation are pure shell)
- **database**: sqlite3, psql, or mysql/mariadb client (per provider)
- **http-client**: curl
- **json-parser**: jq
- **logging-extended**: logger (syslog), systemd-cat (journald); file logging is pure shell
- **notification**: curl (for ntfy/webhooks); sendmail or msmtp (for email)
- **parallel**: GNU parallel (preferred), xargs, or none (built-in job control fallback)
- **tui**: gum (preferred), dialog, or whiptail (fallback to ANSI if none available)
- **yaml**: yq (Mike Farah's Go implementation)

## Documentation

- **[README-bash.md](docs/README-bash.md)** — Comprehensive bash template developer guide
- **[README-zsh.md](docs/README-zsh.md)** — Comprehensive zsh template developer guide
- **[PLUGIN_DEVELOPMENT.md](docs/PLUGIN_DEVELOPMENT.md)** — Guide to creating custom plugins
- **[CHANGELOG.md](CHANGELOG.md)** — Version history

## Contributing

Contributions are welcome. Please follow the existing code style (camelCase, modular functions, comprehensive comments) and update documentation for any changes.

## License

Licensed under the [Creative Commons Attribution-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-sa/4.0/).

You are free to share and adapt this material under the terms of attribution and share-alike.

## Author

**jason c. kay**

---

*Shell Script Templates v4.1.0 — Build better shell scripts.*
