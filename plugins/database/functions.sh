# Database Plugin - Functions
# Provides a unified interface for database operations across
# SQLite, PostgreSQL, and MySQL/MariaDB.
#
# Usage:
#   db_set_provider sqlite
#   db_query "SELECT * FROM users WHERE active = 1"
#   count=$(db_scalar "SELECT COUNT(*) FROM orders")
#   db_exec "INSERT INTO logs (msg) VALUES ('started')"
#   db_export "SELECT * FROM report" > report.csv

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Switch the active database provider
# Arguments:
#   $1 - Provider name (sqlite, postgres, mysql)
# Returns: 0 on success, 1 on invalid provider
db_set_provider() {
    local provider=$1
    case "$provider" in
        sqlite|postgres|mysql) DB_PROVIDER="$provider" ;;
        *)
            if declare -f error >/dev/null 2>&1; then
                error "database: Unknown provider: ${provider}"
            fi
            return 1
            ;;
    esac
}

# Set the database connection target
# Arguments vary by provider:
#   sqlite:   db_set_target "/path/to/file.db"
#   postgres: db_set_target "dbname" ["host"] ["port"] ["user"]
#   mysql:    db_set_target "dbname" ["host"] ["port"] ["user"]
db_set_target() {
    case "$DB_PROVIDER" in
        sqlite)
            DB_SQLITE_FILE="${1:?database file required}"
            ;;
        postgres)
            DB_PG_DATABASE="${1:?database name required}"
            [[ -n "${2:-}" ]] && DB_PG_HOST="$2"
            [[ -n "${3:-}" ]] && DB_PG_PORT="$3"
            [[ -n "${4:-}" ]] && DB_PG_USER="$4"
            ;;
        mysql)
            DB_MY_DATABASE="${1:?database name required}"
            [[ -n "${2:-}" ]] && DB_MY_HOST="$2"
            [[ -n "${3:-}" ]] && DB_MY_PORT="$3"
            [[ -n "${4:-}" ]] && DB_MY_USER="$4"
            ;;
    esac
}

# ==============================================================================
# CORE OPERATIONS
# ==============================================================================

# Execute a SQL query and return results
# Arguments:
#   $1 - SQL query string
#   $2 - Output format: "table" (default), "csv", "tsv", "json" (postgres only)
# Returns: Query results via stdout
db_query() {
    local sql=$1
    local format=${2:-"table"}

    case "$DB_PROVIDER" in
        sqlite)  _db_sqlite_query "$sql" "$format" ;;
        postgres) _db_pg_query "$sql" "$format" ;;
        mysql)   _db_my_query "$sql" "$format" ;;
    esac
}

# Execute a SQL statement that returns no results (INSERT, UPDATE, DELETE, DDL)
# Arguments:
#   $1 - SQL statement
# Returns: 0 on success, 1 on failure
db_exec() {
    local sql=$1

    case "$DB_PROVIDER" in
        sqlite)
            "$DB_SQLITE_BIN" "$DB_SQLITE_FILE" "$sql" 2>&1
            ;;
        postgres)
            PGPASSWORD="$DB_PG_PASSWORD" "$DB_PG_BIN" \
                -h "$DB_PG_HOST" -p "$DB_PG_PORT" -U "$DB_PG_USER" \
                -d "$DB_PG_DATABASE" -c "$sql" --no-align -q 2>&1
            ;;
        mysql)
            "$DB_MY_BIN" \
                -h "$DB_MY_HOST" -P "$DB_MY_PORT" -u "$DB_MY_USER" \
                ${DB_MY_PASSWORD:+-p"$DB_MY_PASSWORD"} \
                "$DB_MY_DATABASE" -e "$sql" 2>&1
            ;;
    esac
}

# Execute a query that returns a single scalar value
# Arguments:
#   $1 - SQL query (should return exactly one row, one column)
# Returns: Scalar value via stdout
db_scalar() {
    local sql=$1

    case "$DB_PROVIDER" in
        sqlite)
            "$DB_SQLITE_BIN" -noheader "$DB_SQLITE_FILE" "$sql" 2>/dev/null | head -1
            ;;
        postgres)
            PGPASSWORD="$DB_PG_PASSWORD" "$DB_PG_BIN" \
                -h "$DB_PG_HOST" -p "$DB_PG_PORT" -U "$DB_PG_USER" \
                -d "$DB_PG_DATABASE" -t -A -c "$sql" 2>/dev/null | head -1
            ;;
        mysql)
            "$DB_MY_BIN" \
                -h "$DB_MY_HOST" -P "$DB_MY_PORT" -u "$DB_MY_USER" \
                ${DB_MY_PASSWORD:+-p"$DB_MY_PASSWORD"} \
                -N "$DB_MY_DATABASE" -e "$sql" 2>/dev/null | head -1
            ;;
    esac
}

# Execute a query and return results as CSV
# Arguments:
#   $1 - SQL query
#   $2 - Include header row (true/false, default: true)
# Returns: CSV output via stdout
db_export() {
    local sql=$1
    local header=${2:-$DB_HEADER}

    case "$DB_PROVIDER" in
        sqlite)
            if [[ "$header" == "true" ]]; then
                "$DB_SQLITE_BIN" -header -csv "$DB_SQLITE_FILE" "$sql"
            else
                "$DB_SQLITE_BIN" -csv "$DB_SQLITE_FILE" "$sql"
            fi
            ;;
        postgres)
            local copyCmd="COPY (${sql}) TO STDOUT WITH CSV"
            [[ "$header" == "true" ]] && copyCmd="${copyCmd} HEADER"
            PGPASSWORD="$DB_PG_PASSWORD" "$DB_PG_BIN" \
                -h "$DB_PG_HOST" -p "$DB_PG_PORT" -U "$DB_PG_USER" \
                -d "$DB_PG_DATABASE" -c "$copyCmd" 2>/dev/null
            ;;
        mysql)
            # MySQL doesn't have native CSV; use sed to convert tab-separated
            if [[ "$header" == "true" ]]; then
                "$DB_MY_BIN" \
                    -h "$DB_MY_HOST" -P "$DB_MY_PORT" -u "$DB_MY_USER" \
                    ${DB_MY_PASSWORD:+-p"$DB_MY_PASSWORD"} \
                    "$DB_MY_DATABASE" -e "$sql" 2>/dev/null | \
                    sed 's/\t/,/g'
            else
                "$DB_MY_BIN" \
                    -h "$DB_MY_HOST" -P "$DB_MY_PORT" -u "$DB_MY_USER" \
                    ${DB_MY_PASSWORD:+-p"$DB_MY_PASSWORD"} \
                    -N "$DB_MY_DATABASE" -e "$sql" 2>/dev/null | \
                    sed 's/\t/,/g'
            fi
            ;;
    esac
}

# Execute a SQL file
# Arguments:
#   $1 - Path to SQL file
# Returns: 0 on success, 1 on failure
db_exec_file() {
    local sqlFile=$1

    if [[ ! -r "$sqlFile" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "database: Cannot read SQL file: ${sqlFile}"
        fi
        return 1
    fi

    case "$DB_PROVIDER" in
        sqlite)
            "$DB_SQLITE_BIN" "$DB_SQLITE_FILE" < "$sqlFile"
            ;;
        postgres)
            PGPASSWORD="$DB_PG_PASSWORD" "$DB_PG_BIN" \
                -h "$DB_PG_HOST" -p "$DB_PG_PORT" -U "$DB_PG_USER" \
                -d "$DB_PG_DATABASE" -f "$sqlFile" 2>&1
            ;;
        mysql)
            "$DB_MY_BIN" \
                -h "$DB_MY_HOST" -P "$DB_MY_PORT" -u "$DB_MY_USER" \
                ${DB_MY_PASSWORD:+-p"$DB_MY_PASSWORD"} \
                "$DB_MY_DATABASE" < "$sqlFile" 2>&1
            ;;
    esac
}

# ==============================================================================
# SCHEMA HELPERS
# ==============================================================================

# List all tables in the database
# Arguments: None
# Returns: One table name per line via stdout
db_tables() {
    case "$DB_PROVIDER" in
        sqlite)
            "$DB_SQLITE_BIN" "$DB_SQLITE_FILE" \
                ".tables" 2>/dev/null | tr -s ' ' '\n' | sort
            ;;
        postgres)
            db_query "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename" "plain"
            ;;
        mysql)
            db_scalar "SHOW TABLES" 2>/dev/null || \
            db_query "SHOW TABLES" "plain"
            ;;
    esac
}

# Describe a table's schema
# Arguments:
#   $1 - Table name
# Returns: Column definitions via stdout
db_describe() {
    local table=$1

    case "$DB_PROVIDER" in
        sqlite)
            "$DB_SQLITE_BIN" "$DB_SQLITE_FILE" ".schema ${table}" 2>/dev/null
            ;;
        postgres)
            db_query "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_name = '${table}' ORDER BY ordinal_position"
            ;;
        mysql)
            db_query "DESCRIBE ${table}"
            ;;
    esac
}

# Check if a table exists
# Arguments:
#   $1 - Table name
# Returns: 0 if exists, 1 if not
db_table_exists() {
    local table=$1
    local count

    case "$DB_PROVIDER" in
        sqlite)
            count=$(db_scalar "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='${table}'")
            ;;
        postgres)
            count=$(db_scalar "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='${table}'")
            ;;
        mysql)
            count=$(db_scalar "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='${table}'")
            ;;
    esac

    [[ "${count:-0}" -gt 0 ]]
}

# ==============================================================================
# TRANSACTION HELPERS
# ==============================================================================

# Execute multiple statements in a transaction
# Arguments:
#   $1 - Newline-separated SQL statements
# Returns: 0 on success (committed), 1 on failure (rolled back)
db_transaction() {
    local statements=$1
    local wrappedSql
    wrappedSql="BEGIN TRANSACTION;
${statements}
COMMIT;"

    if ! db_exec "$wrappedSql" 2>/dev/null; then
        db_exec "ROLLBACK;" 2>/dev/null || true
        if declare -f error >/dev/null 2>&1; then
            error "database: Transaction failed and was rolled back"
        fi
        return 1
    fi

    return 0
}

# ==============================================================================
# PROVIDER-SPECIFIC INTERNALS
# ==============================================================================

# SQLite query implementation
_db_sqlite_query() {
    local sql=$1
    local format=$2
    local -a opts=()

    case "$format" in
        csv)   opts+=(-csv) ;;
        tsv)   opts+=(-separator "	") ;;
        table) opts+=(-column) ;;
        *)     opts+=(-separator "$DB_SEPARATOR") ;;
    esac

    [[ "$DB_HEADER" == "true" ]] && opts+=(-header)

    "$DB_SQLITE_BIN" "${opts[@]}" "$DB_SQLITE_FILE" "$sql" 2>/dev/null
}

# PostgreSQL query implementation
_db_pg_query() {
    local sql=$1
    local format=$2
    local -a opts=(
        -h "$DB_PG_HOST" -p "$DB_PG_PORT" -U "$DB_PG_USER"
        -d "$DB_PG_DATABASE"
    )

    case "$format" in
        csv)
            local copyCmd="COPY (${sql}) TO STDOUT WITH CSV"
            [[ "$DB_HEADER" == "true" ]] && copyCmd="${copyCmd} HEADER"
            PGPASSWORD="$DB_PG_PASSWORD" "$DB_PG_BIN" "${opts[@]}" -c "$copyCmd" 2>/dev/null
            return
            ;;
        plain) opts+=(-t -A) ;;
        table) ;;  # default psql format
        *)     opts+=(--no-align -F "$DB_SEPARATOR") ;;
    esac

    PGPASSWORD="$DB_PG_PASSWORD" "$DB_PG_BIN" "${opts[@]}" -c "$sql" 2>/dev/null
}

# MySQL query implementation
_db_my_query() {
    local sql=$1
    local format=$2
    local -a opts=(
        -h "$DB_MY_HOST" -P "$DB_MY_PORT" -u "$DB_MY_USER"
        ${DB_MY_PASSWORD:+-p"$DB_MY_PASSWORD"}
        "$DB_MY_DATABASE"
    )

    case "$format" in
        table) opts+=(--table) ;;
        plain) opts+=(-N) ;;
    esac

    [[ "$DB_HEADER" == "false" ]] && opts+=(-N)

    "$DB_MY_BIN" "${opts[@]}" -e "$sql" 2>/dev/null
}

# ==============================================================================
# DIAGNOSTICS
# ==============================================================================

# Print current database configuration
db_status() {
    printf 'Database Plugin Status:\n'
    printf '  Provider:  %s\n' "$DB_PROVIDER"
    printf '  Ready:     %s\n' "$DB_READY"
    case "$DB_PROVIDER" in
        sqlite)
            printf '  File:      %s\n' "$DB_SQLITE_FILE"
            printf '  Client:    %s\n' "${DB_SQLITE_BIN:-not found}"
            ;;
        postgres)
            printf '  Host:      %s:%s\n' "$DB_PG_HOST" "$DB_PG_PORT"
            printf '  Database:  %s\n' "$DB_PG_DATABASE"
            printf '  User:      %s\n' "$DB_PG_USER"
            printf '  Client:    %s\n' "${DB_PG_BIN:-not found}"
            ;;
        mysql)
            printf '  Host:      %s:%s\n' "$DB_MY_HOST" "$DB_MY_PORT"
            printf '  Database:  %s\n' "$DB_MY_DATABASE"
            printf '  User:      %s\n' "$DB_MY_USER"
            printf '  Client:    %s\n' "${DB_MY_BIN:-not found}"
            ;;
    esac
}
