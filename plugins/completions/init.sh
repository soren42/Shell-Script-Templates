# Completions Plugin - Initialization
# Detects the appropriate completion installation directories for the
# current shell and privilege level.

COMP_READY=false

# Detect current shell
if [[ -n "${ZSH_VERSION:-}" ]]; then
    COMP_SHELL="zsh"
elif [[ -n "${BASH_VERSION:-}" ]]; then
    COMP_SHELL="bash"
else
    COMP_SHELL="unknown"
fi

# Detect bash completion directories
if [[ "$COMP_INSTALL_SCOPE" == "system" ]] && [[ $EUID -eq 0 ]]; then
    # System-wide installation (root)
    COMP_BASH_DIR="/etc/bash_completion.d"
    COMP_ZSH_DIR="/usr/local/share/zsh/site-functions"
else
    # Per-user installation
    COMP_BASH_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/bash-completion/completions"
    
    # For zsh, prefer XDG, fall back to ~/.zsh/completions
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # Check if any fpath entry is user-writable
        COMP_ZSH_DIR=""
        for fpathDir in "${fpath[@]:-}"; do
            if [[ -d "$fpathDir" ]] && [[ -w "$fpathDir" ]]; then
                COMP_ZSH_DIR="$fpathDir"
                break
            fi
        done
        # Default to a conventional user completions directory
        [[ -z "$COMP_ZSH_DIR" ]] && COMP_ZSH_DIR="${HOME}/.zsh/completions"
    else
        COMP_ZSH_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/zsh/site-functions"
    fi
fi

COMP_READY=true

if declare -f debug >/dev/null 2>&1; then
    debug "completions loaded: shell=${COMP_SHELL} bash_dir=${COMP_BASH_DIR} zsh_dir=${COMP_ZSH_DIR}"
fi
