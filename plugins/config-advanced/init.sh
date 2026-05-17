# Config Advanced Plugin - Initialization
# Detects available config format parsers

CONFIG_ADV_READY=true
CONFIG_TOML_BIN=""

# Detect TOML parser (yq supports TOML via -p=toml)
if command -v yq >/dev/null 2>&1; then
    # Mike Farah's yq v4.25+ supports TOML
    CONFIG_TOML_BIN=$(command -v yq)
elif command -v tomlq >/dev/null 2>&1; then
    CONFIG_TOML_BIN=$(command -v tomlq)
elif command -v dasel >/dev/null 2>&1; then
    CONFIG_TOML_BIN=$(command -v dasel)
fi

if declare -f debug >/dev/null 2>&1; then
    debug "config-advanced loaded: toml_parser=${CONFIG_TOML_BIN:-pure-shell}"
fi
