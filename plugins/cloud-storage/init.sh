# Cloud Storage Plugin - Initialization
# Detects available cloud storage CLI tools

CLOUD_READY=false
CLOUD_AWS_BIN=""
CLOUD_GCLOUD_BIN=""
CLOUD_GSUTIL_BIN=""

# Detect AWS CLI
if command -v aws >/dev/null 2>&1; then
    CLOUD_AWS_BIN=$(command -v aws)
fi

# Detect Google Cloud SDK
if command -v gcloud >/dev/null 2>&1; then
    CLOUD_GCLOUD_BIN=$(command -v gcloud)
fi

if command -v gsutil >/dev/null 2>&1; then
    CLOUD_GSUTIL_BIN=$(command -v gsutil)
fi

# Validate provider
case "$CLOUD_PROVIDER" in
    s3|s3compat)
        if [[ -n "$CLOUD_AWS_BIN" ]]; then
            CLOUD_READY=true
        else
            if declare -f warn >/dev/null 2>&1; then
                warn "cloud-storage: aws CLI not found for provider '${CLOUD_PROVIDER}'"
            fi
        fi
        ;;
    gcs)
        if [[ -n "$CLOUD_GSUTIL_BIN" ]]; then
            CLOUD_READY=true
        elif [[ -n "$CLOUD_GCLOUD_BIN" ]]; then
            CLOUD_READY=true
        else
            if declare -f warn >/dev/null 2>&1; then
                warn "cloud-storage: gsutil/gcloud not found for provider 'gcs'"
            fi
        fi
        ;;
esac

if declare -f debug >/dev/null 2>&1; then
    debug "cloud-storage loaded: provider=${CLOUD_PROVIDER} aws=${CLOUD_AWS_BIN:-none} gsutil=${CLOUD_GSUTIL_BIN:-none}"
fi
