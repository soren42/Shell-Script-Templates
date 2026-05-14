# TUI Plugin - Functions
# Provides a unified Text User Interface abstraction layer.
# All tui_* functions automatically route to the active backend.
#
# Supported backends (in preference order):
#   gum       - Modern, beautiful prompts from Charm (https://github.com/charmbracelet/gum)
#   dialog    - Classic ncurses dialog boxes (most Linux distros)
#   whiptail  - Lightweight ncurses alternative (Debian/Ubuntu default)
#   fallback  - Pure ANSI escape codes (always available, no dependencies)

# ==============================================================================
# TEXT INPUT
# ==============================================================================

# Prompt user for a single line of text
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Prompt message
#   $2 - Default value (optional)
#   $3 - Placeholder text (optional, gum only)
# Returns: User input via stdout
tui_input() {
    local prompt=${1:-"Enter value"}
    local defaultVal=${2:-""}
    local placeholder=${3:-""}

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            gum input \
                --prompt "${prompt}: " \
                --value "$defaultVal" \
                --placeholder "$placeholder" \
                --prompt.foreground "$TUI_GUM_PROMPT_COLOR"
            ;;
        dialog)
            local result
            result=$(dialog --inputbox "$prompt" \
                "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" \
                "$defaultVal" 3>&1 1>&2 2>&3) || true
            echo "$result"
            ;;
        whiptail)
            local result
            result=$(whiptail --inputbox "$prompt" \
                "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" \
                "$defaultVal" 3>&1 1>&2 2>&3) || true
            echo "$result"
            ;;
        fallback)
            local userInput
            if [[ -n "$defaultVal" ]]; then
                printf '\033[36m?\033[0m %s [%s]: ' "$prompt" "$defaultVal" >&2
            else
                printf '\033[36m?\033[0m %s: ' "$prompt" >&2
            fi
            read -r userInput
            echo "${userInput:-$defaultVal}"
            ;;
    esac
}

# Prompt user for multi-line text (e.g., description, notes)
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Prompt message
#   $2 - Default value (optional)
# Returns: User input via stdout
tui_text() {
    local prompt=${1:-"Enter text"}
    local defaultVal=${2:-""}

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            gum write \
                --header "$prompt" \
                --value "$defaultVal" \
                --header.foreground "$TUI_GUM_HEADER_COLOR"
            ;;
        dialog)
            local tmpFile
            tmpFile=$(mktemp)
            echo "$defaultVal" > "$tmpFile"
            dialog --editbox "$tmpFile" \
                "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" 3>&1 1>&2 2>&3 || true
            rm -f "$tmpFile"
            ;;
        whiptail|fallback)
            # whiptail lacks editbox; fall through to basic input
            printf '\033[36m?\033[0m %s (end with empty line):\n' "$prompt" >&2
            local line
            local result=""
            while IFS= read -r line; do
                [[ -z "$line" ]] && break
                result="${result}${line}\n"
            done
            echo -e "$result"
            ;;
    esac
}

# Prompt for a password (hidden input)
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Prompt message
# Returns: Password via stdout
tui_password() {
    local prompt=${1:-"Enter password"}

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            gum input \
                --password \
                --prompt "${prompt}: " \
                --prompt.foreground "$TUI_GUM_PROMPT_COLOR"
            ;;
        dialog)
            dialog --insecure --passwordbox "$prompt" \
                "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" 3>&1 1>&2 2>&3 || true
            ;;
        whiptail)
            whiptail --passwordbox "$prompt" \
                "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" 3>&1 1>&2 2>&3 || true
            ;;
        fallback)
            local password
            printf '\033[36m?\033[0m %s: ' "$prompt" >&2
            read -rs password
            echo "" >&2
            echo "$password"
            ;;
    esac
}

# ==============================================================================
# SELECTION
# ==============================================================================

# Present a list of options for single selection
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Prompt message
#   $2...$N - Options to choose from
# Returns: Selected option via stdout
tui_choose() {
    local prompt=$1
    shift
    local -a options=("$@")

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            printf '%s\n' "${options[@]}" | gum choose \
                --header "$prompt" \
                --header.foreground "$TUI_GUM_HEADER_COLOR" \
                --selected.foreground "$TUI_GUM_SELECTED_COLOR"
            ;;
        dialog)
            local -a menuItems=()
            local i=1
            for opt in "${options[@]}"; do
                menuItems+=("$i" "$opt")
                ((i++))
            done
            local selection
            selection=$(dialog --menu "$prompt" \
                "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" "$TUI_DEFAULT_LIST_HEIGHT" \
                "${menuItems[@]}" 3>&1 1>&2 2>&3) || true
            if [[ -n "$selection" ]]; then
                echo "${options[$((selection - 1))]}"
            fi
            ;;
        whiptail)
            local -a menuItems=()
            local i=1
            for opt in "${options[@]}"; do
                menuItems+=("$i" "$opt")
                ((i++))
            done
            local selection
            selection=$(whiptail --menu "$prompt" \
                "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" "$TUI_DEFAULT_LIST_HEIGHT" \
                "${menuItems[@]}" 3>&1 1>&2 2>&3) || true
            if [[ -n "$selection" ]]; then
                echo "${options[$((selection - 1))]}"
            fi
            ;;
        fallback)
            printf '\033[36m?\033[0m %s\n' "$prompt" >&2
            local i=1
            for opt in "${options[@]}"; do
                printf '  \033[36m%d\033[0m) %s\n' "$i" "$opt" >&2
                ((i++))
            done
            printf '  Selection: ' >&2
            local choice
            read -r choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
                echo "${options[$((choice - 1))]}"
            else
                echo "${options[0]}"
            fi
            ;;
    esac
}

# Present a list of options for multi-selection (checkboxes)
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Prompt message
#   $2...$N - Options to choose from
# Returns: Space-separated selected options via stdout
tui_multi_choose() {
    local prompt=$1
    shift
    local -a options=("$@")

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            printf '%s\n' "${options[@]}" | gum choose \
                --no-limit \
                --header "$prompt" \
                --header.foreground "$TUI_GUM_HEADER_COLOR" \
                --selected.foreground "$TUI_GUM_SELECTED_COLOR"
            ;;
        dialog)
            local -a checkItems=()
            for opt in "${options[@]}"; do
                checkItems+=("$opt" "" "off")
            done
            dialog --checklist "$prompt" \
                "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" "$TUI_DEFAULT_LIST_HEIGHT" \
                "${checkItems[@]}" 3>&1 1>&2 2>&3 || true
            ;;
        whiptail)
            local -a checkItems=()
            for opt in "${options[@]}"; do
                checkItems+=("$opt" "" "OFF")
            done
            whiptail --checklist "$prompt" \
                "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" "$TUI_DEFAULT_LIST_HEIGHT" \
                "${checkItems[@]}" 3>&1 1>&2 2>&3 || true
            ;;
        fallback)
            printf '\033[36m?\033[0m %s (enter numbers separated by spaces)\n' "$prompt" >&2
            local i=1
            for opt in "${options[@]}"; do
                printf '  \033[36m%d\033[0m) %s\n' "$i" "$opt" >&2
                ((i++))
            done
            printf '  Selection(s): ' >&2
            local choices
            read -r choices
            for num in $choices; do
                if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 1 && num <= ${#options[@]})); then
                    echo "${options[$((num - 1))]}"
                fi
            done
            ;;
    esac
}

# ==============================================================================
# CONFIRMATION
# ==============================================================================

# Ask a yes/no confirmation question
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Question text
#   $2 - Default answer (true/false, default: true)
# Returns: 0 for yes, 1 for no
tui_confirm() {
    local prompt=${1:-"Continue?"}
    local defaultYes=${2:-true}

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            local affirmative="Yes"
            local negative="No"
            local defaultFlag="--affirmative=${affirmative}"
            if [[ "$defaultYes" == "false" ]]; then
                defaultFlag="--default=No"
            fi
            gum confirm "$prompt" $defaultFlag
            return $?
            ;;
        dialog)
            if [[ "$defaultYes" == "true" ]]; then
                dialog --yesno "$prompt" "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" 3>&1 1>&2 2>&3
            else
                dialog --defaultno --yesno "$prompt" "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" 3>&1 1>&2 2>&3
            fi
            return $?
            ;;
        whiptail)
            if [[ "$defaultYes" == "true" ]]; then
                whiptail --yesno "$prompt" "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" 3>&1 1>&2 2>&3
            else
                whiptail --defaultno --yesno "$prompt" "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" 3>&1 1>&2 2>&3
            fi
            return $?
            ;;
        fallback)
            local hint
            [[ "$defaultYes" == "true" ]] && hint="Y/n" || hint="y/N"
            printf '\033[36m?\033[0m %s [%s]: ' "$prompt" "$hint" >&2
            local answer
            read -r answer
            case "${answer,,}" in
                y|yes) return 0 ;;
                n|no)  return 1 ;;
                "")
                    [[ "$defaultYes" == "true" ]] && return 0 || return 1
                    ;;
                *)
                    [[ "$defaultYes" == "true" ]] && return 0 || return 1
                    ;;
            esac
            ;;
    esac
}

# ==============================================================================
# FEEDBACK AND PROGRESS
# ==============================================================================

# Display a spinner while a command runs
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Title/message to display
#   $2...$N - Command and arguments to execute
# Returns: Exit code of the executed command
tui_spin() {
    local title=$1
    shift

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            gum spin \
                --title "$title" \
                --spinner dot \
                --spinner.foreground "$TUI_GUM_PROMPT_COLOR" \
                -- "$@"
            return $?
            ;;
        dialog|whiptail|fallback)
            # For non-gum backends, show a simple progress indicator
            printf '\033[36m⠋\033[0m %s...' "$title" >&2
            "$@"
            local exitCode=$?
            if [[ $exitCode -eq 0 ]]; then
                printf '\r\033[32m✓\033[0m %s    \n' "$title" >&2
            else
                printf '\r\033[31m✗\033[0m %s    \n' "$title" >&2
            fi
            return $exitCode
            ;;
    esac
}

# Display styled informational text
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Text style (info, warn, error, success, header)
#   $2 - Message text
# Returns: None
tui_message() {
    local style=${1:-"info"}
    local message=$2

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            case "$style" in
                header)
                    gum style \
                        --foreground "$TUI_GUM_HEADER_COLOR" \
                        --bold \
                        --border double \
                        --padding "0 2" \
                        "$message"
                    ;;
                success)
                    gum style --foreground "#00FF88" "✓ ${message}"
                    ;;
                warn)
                    gum style --foreground "#FFAA00" "! ${message}"
                    ;;
                error)
                    gum style --foreground "#FF4444" --bold "✗ ${message}"
                    ;;
                *)
                    gum style --foreground "$TUI_GUM_PROMPT_COLOR" "→ ${message}"
                    ;;
            esac
            ;;
        *)
            # ANSI fallback works for all non-gum backends
            case "$style" in
                header)
                    printf '\n\033[1m\033[33m══ %s ══\033[0m\n\n' "$message"
                    ;;
                success) printf '\033[32m✓\033[0m %s\n' "$message" ;;
                warn)    printf '\033[33m!\033[0m %s\n' "$message" >&2 ;;
                error)   printf '\033[31m✗\033[0m %s\n' "$message" >&2 ;;
                *)       printf '\033[36m→\033[0m %s\n' "$message" ;;
            esac
            ;;
    esac
}

# Display a filterable/searchable list
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Prompt message
#   $2...$N - Items to filter through
# Returns: Selected item via stdout
tui_filter() {
    local prompt=$1
    shift
    local -a items=("$@")

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            printf '%s\n' "${items[@]}" | gum filter \
                --header "$prompt" \
                --header.foreground "$TUI_GUM_HEADER_COLOR" \
                --indicator.foreground "$TUI_GUM_SELECTED_COLOR"
            ;;
        *)
            # Fall back to basic selection for non-gum backends
            tui_choose "$prompt" "${items[@]}"
            ;;
    esac
}

# Display a formatted table
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Comma-separated header row
#   $2...$N - Comma-separated data rows
# Returns: None (output to stdout)
tui_table() {
    local header=$1
    shift
    local -a rows=("$@")

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            (echo "$header"; printf '%s\n' "${rows[@]}") | gum table
            ;;
        *)
            # Simple column-aligned output
            printf '\033[1m%s\033[0m\n' "$header"
            printf '%s\n' "$(echo "$header" | sed 's/[^,]/-/g; s/,/+-/g')"
            printf '%s\n' "${rows[@]}"
            ;;
    esac
}

# ==============================================================================
# FILE SELECTION
# ==============================================================================

# Browse and select a file
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Starting directory (optional, default: .)
# Returns: Selected file path via stdout
tui_file() {
    local startDir=${1:-.}

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            gum file "$startDir"
            ;;
        dialog)
            dialog --fselect "$startDir/" \
                "$TUI_DEFAULT_HEIGHT" "$TUI_DEFAULT_WIDTH" 3>&1 1>&2 2>&3 || true
            ;;
        whiptail|fallback)
            # List files and let user choose
            local -a files
            mapfile -t files < <(find "$startDir" -maxdepth 2 -type f 2>/dev/null | sort | head -50)
            if [[ ${#files[@]} -eq 0 ]]; then
                printf '\033[31mNo files found in %s\033[0m\n' "$startDir" >&2
                return 1
            fi
            tui_choose "Select a file:" "${files[@]}"
            ;;
    esac
}

# ==============================================================================
# UTILITY
# ==============================================================================

# Get the name of the active TUI backend
# Globals: TUI_ACTIVE_BACKEND
# Arguments: None
# Returns: Backend name via stdout
tui_backend() {
    echo "$TUI_ACTIVE_BACKEND"
}

# Check if the current backend supports a specific feature
# Globals: TUI_ACTIVE_BACKEND
# Arguments:
#   $1 - Feature name (spinner, filter, table, file, password, multiline)
# Returns: 0 if supported, 1 if not
tui_supports() {
    local feature=$1

    case "$TUI_ACTIVE_BACKEND" in
        gum)
            # Gum supports everything
            return 0
            ;;
        dialog)
            case "$feature" in
                spinner|filter|table) return 1 ;;
                *) return 0 ;;
            esac
            ;;
        whiptail)
            case "$feature" in
                spinner|filter|table|multiline) return 1 ;;
                *) return 0 ;;
            esac
            ;;
        fallback)
            case "$feature" in
                spinner|filter|table) return 1 ;;
                *) return 0 ;;
            esac
            ;;
    esac
}
