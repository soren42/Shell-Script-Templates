# TUI Plugin - Initialization
# Detects the best available TUI backend and sets TUI_ACTIVE_BACKEND

TUI_ACTIVE_BACKEND="fallback"

# Detect the best available backend in preference order
for candidate in $TUI_BACKEND_PREFERENCE; do
    case "$candidate" in
        gum)
            if command -v gum >/dev/null 2>&1; then
                TUI_ACTIVE_BACKEND="gum"
                break
            fi
            ;;
        dialog)
            if command -v dialog >/dev/null 2>&1; then
                TUI_ACTIVE_BACKEND="dialog"
                break
            fi
            ;;
        whiptail)
            if command -v whiptail >/dev/null 2>&1; then
                TUI_ACTIVE_BACKEND="whiptail"
                break
            fi
            ;;
        fallback)
            TUI_ACTIVE_BACKEND="fallback"
            break
            ;;
    esac
done

# Report backend selection if debug verbosity is available
if declare -f debug >/dev/null 2>&1; then
    debug "TUI plugin loaded, backend: ${TUI_ACTIVE_BACKEND}"
fi
