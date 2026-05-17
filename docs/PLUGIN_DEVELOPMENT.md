# Plugin Development Guide

**Version:** 4.1.0
**Author:** jason c. kay

---

## Overview

The Shell Script Templates v4 plugin system provides a simple, file-based mechanism for extending script functionality with reusable modules. Plugins are loaded at runtime based on the `ENABLED_PLUGINS` feature flag.

This guide covers how to create, structure, test, and distribute your own plugins.

## Plugin Structure

Every plugin lives in its own directory under the plugin path:

```
~/.shell-script-templates/plugins/your-plugin-name/
├── plugin.conf      # Required: Metadata and configuration
├── functions.sh     # Required: Shell functions
├── init.sh          # Optional: Initialization and validation
└── README.md        # Optional: Documentation
```

The plugin directory name is the plugin identifier used in `ENABLED_PLUGINS`.

## Creating a Plugin

### Step 1: Create the Directory

```bash
mkdir -p ~/.shell-script-templates/plugins/my-plugin
```

### Step 2: Create plugin.conf

This file defines metadata and default configuration values. It is sourced first when the plugin loads.

```bash
# My Plugin for Shell Script Templates v4
# Brief description of what this plugin does

PLUGIN_NAME="my-plugin"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Brief description of the plugin"
PLUGIN_AUTHOR="Your Name"
PLUGIN_LICENSE="CC BY-SA 4.0"
PLUGIN_DEPENDENCIES="curl jq"     # Space-separated binary names

# Plugin-specific configuration with sensible defaults
MY_PLUGIN_TIMEOUT=${MY_PLUGIN_TIMEOUT:-30}
MY_PLUGIN_RETRIES=${MY_PLUGIN_RETRIES:-3}
MY_PLUGIN_VERBOSE=${MY_PLUGIN_VERBOSE:-false}
```

**Important conventions:**
- Prefix all plugin-specific variables with a unique prefix (e.g., `MY_PLUGIN_`)
- Use `${VAR:-default}` syntax so users can override via environment variables
- Document each configuration variable

### Step 3: Create init.sh (Optional)

This file runs once when the plugin loads. Use it to validate dependencies, detect capabilities, and set up state.

```bash
# My Plugin - Initialization

MY_PLUGIN_READY=false

# Validate dependencies
for dep in $PLUGIN_DEPENDENCIES; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        if declare -f warn >/dev/null 2>&1; then
            warn "my-plugin: ${dep} not found, plugin disabled"
        fi
        return 0
    fi
done

MY_PLUGIN_READY=true

# Report initialization if debug logging is available
if declare -f debug >/dev/null 2>&1; then
    debug "my-plugin loaded successfully"
fi
```

**Key patterns:**
- Check for host script logging functions with `declare -f debug >/dev/null 2>&1`
- Use `return 0` (not `exit`) when disabling — the host script should continue
- Set a `*_READY` flag so functions can check initialization state

### Step 4: Create functions.sh

This file contains all the functions your plugin exposes. Follow these conventions:

```bash
# My Plugin - Functions
# Provides [description of what the plugin does].
#
# Usage:
#   result=$(my_plugin_action "input")
#   my_plugin_configure --timeout 60

# ==============================================================================
# PUBLIC API
# ==============================================================================

# Perform the primary action of this plugin
# Globals: MY_PLUGIN_TIMEOUT, MY_PLUGIN_READY
# Arguments:
#   $1 - Input value
#   $2 - Optional modifier
# Returns: Result via stdout, 0 on success, 1 on failure
my_plugin_action() {
    local input=$1
    local modifier=${2:-""}

    # Check initialization state
    if [[ "$MY_PLUGIN_READY" != "true" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "my-plugin: Not initialized (missing dependencies?)"
        fi
        return 1
    fi

    # Your implementation here
    echo "processed: ${input}"
    return 0
}

# ==============================================================================
# INTERNAL HELPERS (prefix with underscore)
# ==============================================================================

# Internal helper function
# Arguments: $1 - data to process
# Returns: Processed data via stdout
_my_plugin_helper() {
    local data=$1
    # Internal logic
    echo "$data"
}
```

**Naming conventions:**
- All public functions: `pluginname_functionname()` (e.g., `my_plugin_action`)
- All internal functions: `_pluginname_functionname()` (e.g., `_my_plugin_helper`)
- All global variables: `PLUGINNAME_VARNAME` (e.g., `MY_PLUGIN_TIMEOUT`)

## Function Documentation

Every function should include a header comment block:

```bash
# Brief description of what this function does
# Globals: List of global variables read or modified
# Arguments:
#   $1 - Description of first argument
#   $2 - Description of second argument (optional)
# Returns: What it returns via stdout, and exit code meaning
function_name() {
    ...
}
```

## Interacting with the Host Script

Plugins are sourced into the host script's environment, so they have access to all host script functions and variables. However, plugins should be defensive about this:

### Using Host Logging Functions

```bash
# Always check if the function exists before calling
if declare -f info >/dev/null 2>&1; then
    info "my-plugin: Operation complete"
else
    echo "my-plugin: Operation complete"
fi
```

### Using Host Validation Functions

```bash
# These are available if the host uses the template
if declare -f validate_file_readable >/dev/null 2>&1; then
    validate_file_readable "$filePath" || return 1
fi
```

### Respecting Dry-Run Mode

```bash
if declare -f run >/dev/null 2>&1; then
    run rm -f "$tempFile"
else
    rm -f "$tempFile"
fi
```

## Backend Pattern (TUI Plugin Example)

For plugins that support multiple backends (like the TUI plugin), use a dispatcher pattern:

```bash
# In init.sh: detect the best available backend
MY_BACKEND="fallback"
if command -v preferred_tool >/dev/null 2>&1; then
    MY_BACKEND="preferred_tool"
elif command -v alternative_tool >/dev/null 2>&1; then
    MY_BACKEND="alternative_tool"
fi

# In functions.sh: dispatch based on backend
my_plugin_action() {
    case "$MY_BACKEND" in
        preferred_tool)  _action_preferred "$@" ;;
        alternative_tool) _action_alternative "$@" ;;
        fallback)        _action_fallback "$@" ;;
    esac
}
```

## Testing Your Plugin

### Manual Testing

```bash
# Source the plugin files directly
source ~/.shell-script-templates/plugins/my-plugin/plugin.conf
source ~/.shell-script-templates/plugins/my-plugin/init.sh
source ~/.shell-script-templates/plugins/my-plugin/functions.sh

# Test functions
result=$(my_plugin_action "test input")
echo "Result: $result"
```

### Integration Testing

Create a test script using the template with your plugin enabled:

```bash
readonly ENABLED_PLUGINS="my-plugin"

main() {
    # Test plugin functions
    result=$(my_plugin_action "test")
    info "Plugin returned: ${result}"
}
```

## Distribution

### Bundled with the Repository

Core plugins ship in the `plugins/` directory of the repository. To add a plugin to the core distribution, submit a pull request.

### Standalone Repository

Third-party plugins can be distributed as separate repositories. Users install them by cloning into their plugin directory:

```bash
cd ~/.shell-script-templates/plugins/
git clone https://github.com/author/sst-my-plugin.git my-plugin
```

Convention: prefix standalone plugin repos with `sst-` (Shell Script Templates).

### Installation Script

Plugins can include an install script:

```bash
#!/usr/bin/env bash
# install.sh - Install my-plugin for Shell Script Templates v4

PLUGIN_DIR="${HOME}/.shell-script-templates/plugins/my-plugin"
mkdir -p "$PLUGIN_DIR"
cp plugin.conf functions.sh init.sh "$PLUGIN_DIR/"
echo "Plugin installed to ${PLUGIN_DIR}"
```

## Core Plugin Reference

| Plugin | Functions | Description |
|--------|-----------|-------------|
| **ai-integration** | `ai_query`, `ai_set_provider`, `ai_set_model`, `ai_query_as`, `ai_summarize_file`, `ai_analyze`, `ai_json`, `ai_status` | LLM API calls to Claude, GPT, Gemini |
| **cloud-storage** | `cloud_upload`, `cloud_download`, `cloud_delete`, `cloud_ls`, `cloud_sync`, `cloud_exists`, `cloud_status` | S3, GCS, and S3-compatible storage |
| **completions** | `completions_generate`, `completions_generate_bash`, `completions_generate_zsh`, `completions_from_args`, `completions_install`, `completions_uninstall`, `completions_list`, `completions_status` | Tab-completion generation and installation |
| **config-advanced** | `ini_get`, `ini_set`, `ini_sections`, `ini_keys`, `toml_get`, `toml_to_json`, `toml_validate`, `dotenv_load`, `env_require`, `env_check`, `env_validate`, `env_list` | INI/TOML parsing, dotenv, env validation |
| **database** | `db_query`, `db_exec`, `db_scalar`, `db_export`, `db_exec_file`, `db_tables`, `db_describe`, `db_table_exists`, `db_transaction`, `db_status` | SQLite, PostgreSQL, MySQL/MariaDB |
| **http-client** | `http_get`, `http_post`, `http_put`, `http_delete`, `http_download`, `http_upload`, `http_status`, `http_ok`, `http_reachable` | HTTP operations with retries and auth |
| **json-parser** | `json_get`, `json_set`, `json_delete`, `json_merge`, `json_validate`, `json_pretty`, `json_compact`, `json_object`, `json_array`, `json_read_file`, `json_write_file` | JSON manipulation via jq |
| **logging-extended** | `log_to_syslog`, `log_to_journal`, `log_to_file`, `log_rotate`, `log_extended`, `log_tail`, `log_search`, `log_file_status` | Syslog, journald, file logging with rotation |
| **notification** | `notify_ntfy`, `notify_email`, `notify_webhook`, `notify_all`, `notify_success`, `notify_failure`, `notify_warning`, `notify_status` | ntfy, email, Slack/Discord webhooks |
| **parallel** | `parallel_run`, `parallel_map`, `parallel_for_each`, `parallel_background`, `parallel_wait`, `parallel_active_count`, `parallel_status` | Concurrent execution with multiple backends |
| **tui** | `tui_input`, `tui_choose`, `tui_confirm`, `tui_spin`, `tui_message`, `tui_filter`, `tui_table`, `tui_file`, `tui_password`, `tui_multi_choose` | Text UI with automatic backend detection |
| **yaml** | `yaml_get`, `yaml_set`, `yaml_delete`, `yaml_merge`, `yaml_validate`, `yaml_to_json`, `yaml_from_json`, `yaml_keys`, `yaml_count`, `yaml_create_file` | YAML parsing and manipulation via yq |

## Checklist for New Plugins

Before releasing a plugin, verify:

- [ ] `plugin.conf` has all required fields (NAME, VERSION, DESCRIPTION, AUTHOR, LICENSE)
- [ ] All public functions have documentation headers
- [ ] Variable and function names use the plugin prefix
- [ ] Plugin handles missing dependencies gracefully (warn and disable, don't crash)
- [ ] Plugin works when host logging functions aren't available
- [ ] Plugin respects dry-run mode where applicable
- [ ] Plugin includes a README.md
- [ ] Plugin has been tested with both bash and zsh templates

## License

Plugins distributed with the Shell Script Templates repository are licensed under CC BY-SA 4.0. Third-party plugins may use any compatible license.
