# Cloud Storage Plugin - Functions
# Provides unified file operations across cloud storage providers.
# Supports AWS S3, Google Cloud Storage, and any S3-compatible backend
# (MinIO, Backblaze B2, Wasabi, DigitalOcean Spaces, etc.).
#
# Usage:
#   cloud_upload /tmp/backup.tar.gz backups/2026/backup.tar.gz
#   cloud_download backups/latest.tar.gz /tmp/restore.tar.gz
#   cloud_ls backups/2026/
#   cloud_sync /local/data/ remote-prefix/

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

# Build the full remote path for the active provider
# Arguments:
#   $1 - Remote key/path
# Returns: Full URI via stdout
_cloud_remote_uri() {
    local remotePath=$1

    case "$CLOUD_PROVIDER" in
        s3|s3compat)
            echo "s3://${CLOUD_S3_BUCKET}/${remotePath}"
            ;;
        gcs)
            echo "gs://${CLOUD_GCS_BUCKET}/${remotePath}"
            ;;
    esac
}

# Build provider-specific CLI args
# Returns: Space-separated extra args via stdout
_cloud_extra_args() {
    local -a args=()

    case "$CLOUD_PROVIDER" in
        s3)
            [[ -n "$CLOUD_S3_REGION" ]] && args+=(--region "$CLOUD_S3_REGION")
            ;;
        s3compat)
            [[ -n "$CLOUD_S3_REGION" ]] && args+=(--region "$CLOUD_S3_REGION")
            [[ -n "$CLOUD_S3_ENDPOINT" ]] && args+=(--endpoint-url "$CLOUD_S3_ENDPOINT")
            ;;
    esac

    echo "${args[*]}"
}

# ==============================================================================
# FILE OPERATIONS
# ==============================================================================

# Upload a local file to cloud storage
# Arguments:
#   $1 - Local file path
#   $2 - Remote key/path
#   --acl ACL        - Access control (private, public-read, etc.)
#   --content-type T - MIME type override
# Returns: 0 on success, 1 on failure
cloud_upload() {
    local localPath=""
    local remotePath=""
    local acl="$CLOUD_DEFAULT_ACL"
    local contentType=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --acl)          acl=$2; shift 2 ;;
            --content-type) contentType=$2; shift 2 ;;
            -*)             shift ;;
            *)
                if [[ -z "$localPath" ]]; then
                    localPath=$1
                else
                    remotePath=$1
                fi
                shift
                ;;
        esac
    done

    if [[ ! -r "$localPath" ]]; then
        if declare -f error >/dev/null 2>&1; then
            error "cloud_upload: Cannot read file: ${localPath}"
        fi
        return 1
    fi

    # Default remote path to filename
    [[ -z "$remotePath" ]] && remotePath=$(basename "$localPath")

    local remoteUri
    remoteUri=$(_cloud_remote_uri "$remotePath")

    if declare -f info >/dev/null 2>&1; then
        info "Uploading: ${localPath} -> ${remoteUri}"
    fi

    case "$CLOUD_PROVIDER" in
        s3|s3compat)
            local -a opts=($(_cloud_extra_args))
            [[ -n "$acl" ]] && opts+=(--acl "$acl")
            [[ -n "$contentType" ]] && opts+=(--content-type "$contentType")
            "$CLOUD_AWS_BIN" s3 cp "$localPath" "$remoteUri" "${opts[@]}" 2>&1
            ;;
        gcs)
            if [[ -n "$CLOUD_GSUTIL_BIN" ]]; then
                "$CLOUD_GSUTIL_BIN" cp "$localPath" "$remoteUri" 2>&1
            else
                "$CLOUD_GCLOUD_BIN" storage cp "$localPath" "$remoteUri" 2>&1
            fi
            ;;
    esac
}

# Download a file from cloud storage
# Arguments:
#   $1 - Remote key/path
#   $2 - Local file path
# Returns: 0 on success, 1 on failure
cloud_download() {
    local remotePath=$1
    local localPath=$2

    local remoteUri
    remoteUri=$(_cloud_remote_uri "$remotePath")

    if declare -f info >/dev/null 2>&1; then
        info "Downloading: ${remoteUri} -> ${localPath}"
    fi

    case "$CLOUD_PROVIDER" in
        s3|s3compat)
            "$CLOUD_AWS_BIN" s3 cp "$remoteUri" "$localPath" $(_cloud_extra_args) 2>&1
            ;;
        gcs)
            if [[ -n "$CLOUD_GSUTIL_BIN" ]]; then
                "$CLOUD_GSUTIL_BIN" cp "$remoteUri" "$localPath" 2>&1
            else
                "$CLOUD_GCLOUD_BIN" storage cp "$remoteUri" "$localPath" 2>&1
            fi
            ;;
    esac
}

# Delete a file from cloud storage
# Arguments:
#   $1 - Remote key/path
# Returns: 0 on success, 1 on failure
cloud_delete() {
    local remotePath=$1
    local remoteUri
    remoteUri=$(_cloud_remote_uri "$remotePath")

    case "$CLOUD_PROVIDER" in
        s3|s3compat)
            "$CLOUD_AWS_BIN" s3 rm "$remoteUri" $(_cloud_extra_args) 2>&1
            ;;
        gcs)
            if [[ -n "$CLOUD_GSUTIL_BIN" ]]; then
                "$CLOUD_GSUTIL_BIN" rm "$remoteUri" 2>&1
            else
                "$CLOUD_GCLOUD_BIN" storage rm "$remoteUri" 2>&1
            fi
            ;;
    esac
}

# List files in a cloud storage path
# Arguments:
#   $1 - Remote prefix/path (optional, default: root)
#   --recursive     - List recursively
# Returns: One path per line via stdout
cloud_ls() {
    local prefix=${1:-""}
    local recursive=false

    [[ "$1" == "--recursive" ]] && { recursive=true; prefix=${2:-""}; }
    [[ "${2:-}" == "--recursive" ]] && recursive=true

    local remoteUri
    remoteUri=$(_cloud_remote_uri "$prefix")

    case "$CLOUD_PROVIDER" in
        s3|s3compat)
            local -a opts=($(_cloud_extra_args))
            [[ "$recursive" == "true" ]] && opts+=(--recursive)
            "$CLOUD_AWS_BIN" s3 ls "$remoteUri" "${opts[@]}" 2>/dev/null
            ;;
        gcs)
            if [[ -n "$CLOUD_GSUTIL_BIN" ]]; then
                if [[ "$recursive" == "true" ]]; then
                    "$CLOUD_GSUTIL_BIN" ls -r "$remoteUri" 2>/dev/null
                else
                    "$CLOUD_GSUTIL_BIN" ls "$remoteUri" 2>/dev/null
                fi
            else
                "$CLOUD_GCLOUD_BIN" storage ls "$remoteUri" 2>/dev/null
            fi
            ;;
    esac
}

# Sync a local directory to cloud storage
# Arguments:
#   $1 - Local directory path
#   $2 - Remote prefix
#   --delete        - Remove remote files not in local
# Returns: 0 on success, 1 on failure
cloud_sync() {
    local localDir=""
    local remotePath=""
    local deleteExtra=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --delete) deleteExtra=true; shift ;;
            -*)       shift ;;
            *)
                if [[ -z "$localDir" ]]; then
                    localDir=$1
                else
                    remotePath=$1
                fi
                shift
                ;;
        esac
    done

    local remoteUri
    remoteUri=$(_cloud_remote_uri "$remotePath")

    if declare -f info >/dev/null 2>&1; then
        info "Syncing: ${localDir} -> ${remoteUri}"
    fi

    case "$CLOUD_PROVIDER" in
        s3|s3compat)
            local -a opts=($(_cloud_extra_args))
            [[ "$deleteExtra" == "true" ]] && opts+=(--delete)
            "$CLOUD_AWS_BIN" s3 sync "$localDir" "$remoteUri" "${opts[@]}" 2>&1
            ;;
        gcs)
            local -a opts=()
            [[ "$deleteExtra" == "true" ]] && opts+=(-d)
            if [[ -n "$CLOUD_GSUTIL_BIN" ]]; then
                "$CLOUD_GSUTIL_BIN" -m rsync "${opts[@]}" -r "$localDir" "$remoteUri" 2>&1
            else
                "$CLOUD_GCLOUD_BIN" storage rsync "${opts[@]}" -r "$localDir" "$remoteUri" 2>&1
            fi
            ;;
    esac
}

# Check if a remote file exists
# Arguments:
#   $1 - Remote key/path
# Returns: 0 if exists, 1 if not
cloud_exists() {
    local remotePath=$1
    local remoteUri
    remoteUri=$(_cloud_remote_uri "$remotePath")

    case "$CLOUD_PROVIDER" in
        s3|s3compat)
            "$CLOUD_AWS_BIN" s3 ls "$remoteUri" $(_cloud_extra_args) >/dev/null 2>&1
            ;;
        gcs)
            if [[ -n "$CLOUD_GSUTIL_BIN" ]]; then
                "$CLOUD_GSUTIL_BIN" stat "$remoteUri" >/dev/null 2>&1
            else
                "$CLOUD_GCLOUD_BIN" storage ls "$remoteUri" >/dev/null 2>&1
            fi
            ;;
    esac
}

# ==============================================================================
# DIAGNOSTICS
# ==============================================================================

# Print cloud storage configuration status
cloud_status() {
    printf 'Cloud Storage Plugin Status:\n'
    printf '  Provider:  %s\n' "$CLOUD_PROVIDER"
    printf '  Ready:     %s\n' "$CLOUD_READY"
    case "$CLOUD_PROVIDER" in
        s3)
            printf '  Bucket:    %s\n' "${CLOUD_S3_BUCKET:-not set}"
            printf '  Region:    %s\n' "$CLOUD_S3_REGION"
            printf '  AWS CLI:   %s\n' "${CLOUD_AWS_BIN:-not found}"
            ;;
        s3compat)
            printf '  Bucket:    %s\n' "${CLOUD_S3_BUCKET:-not set}"
            printf '  Endpoint:  %s\n' "${CLOUD_S3_ENDPOINT:-default}"
            printf '  AWS CLI:   %s\n' "${CLOUD_AWS_BIN:-not found}"
            ;;
        gcs)
            printf '  Bucket:    %s\n' "${CLOUD_GCS_BUCKET:-not set}"
            printf '  Project:   %s\n' "${CLOUD_GCS_PROJECT:-not set}"
            printf '  gsutil:    %s\n' "${CLOUD_GSUTIL_BIN:-not found}"
            printf '  gcloud:    %s\n' "${CLOUD_GCLOUD_BIN:-not found}"
            ;;
    esac
}
