# Database Plugin - Initialization
# Detects available database clients and validates the active provider

DB_READY=false
DB_SQLITE_BIN=""
DB_PG_BIN=""
DB_MY_BIN=""

# Detect available clients
if command -v sqlite3 >/dev/null 2>&1; then
    DB_SQLITE_BIN=$(command -v sqlite3)
fi

if command -v psql >/dev/null 2>&1; then
    DB_PG_BIN=$(command -v psql)
fi

# Prefer mariadb client, fall back to mysql
if command -v mariadb >/dev/null 2>&1; then
    DB_MY_BIN=$(command -v mariadb)
elif command -v mysql >/dev/null 2>&1; then
    DB_MY_BIN=$(command -v mysql)
fi

# Validate the configured provider
case "$DB_PROVIDER" in
    sqlite)
        if [[ -n "$DB_SQLITE_BIN" ]]; then
            DB_READY=true
        else
            if declare -f warn >/dev/null 2>&1; then
                warn "database: sqlite3 not found"
            fi
        fi
        ;;
    postgres)
        if [[ -n "$DB_PG_BIN" ]]; then
            DB_READY=true
        else
            if declare -f warn >/dev/null 2>&1; then
                warn "database: psql not found"
            fi
        fi
        ;;
    mysql)
        if [[ -n "$DB_MY_BIN" ]]; then
            DB_READY=true
        else
            if declare -f warn >/dev/null 2>&1; then
                warn "database: mysql/mariadb client not found"
            fi
        fi
        ;;
    *)
        if declare -f warn >/dev/null 2>&1; then
            warn "database: Unknown provider '${DB_PROVIDER}'"
        fi
        ;;
esac

if declare -f debug >/dev/null 2>&1; then
    debug "database loaded: provider=${DB_PROVIDER} ready=${DB_READY}"
    debug "  sqlite3=${DB_SQLITE_BIN:-none} psql=${DB_PG_BIN:-none} mysql=${DB_MY_BIN:-none}"
fi
