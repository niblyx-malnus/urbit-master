#!/bin/bash
# Core library for urbit-master CLI
# Provides: authentication, config management, HTTP helpers, logging
# Security: Never logs/echoes secrets, uses secure temp files, cleans up on exit

# Prevent multiple sourcing
if [[ -n "${_URBIT_MASTER_CORE_LOADED:-}" ]]; then
    return 0
fi
_URBIT_MASTER_CORE_LOADED=1

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Get script directory (where config.json lives)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.json}"
readonly ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"

# Secure temp file for cookies
COOKIE_FILE=$(mktemp -t urbit-cookies.XXXXXX)
chmod 600 "$COOKIE_FILE"

# Cleanup on exit
cleanup() {
    rm -f "$COOKIE_FILE"
}
trap cleanup EXIT INT TERM

# Logging helpers (NEVER log secrets)
log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${CYAN}DEBUG:${NC} $*" >&2
    fi
}

# Validate config file exists
check_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        log_info "Create it from config.example.json"
        log_info "See URBIT-MASTER.md for setup instructions"
        exit 1
    fi
}

# Load config field (never echo the value)
# Usage: get_config '.field.subfield' [required=true]
get_config() {
    local field="$1"
    local required="${2:-true}"

    check_config

    local value
    value=$(jq -r "$field" "$CONFIG_FILE" 2>/dev/null)

    if [[ "$value" == "null" || -z "$value" ]]; then
        if [[ "$required" == "true" ]]; then
            log_error "Required config field missing: $field"
            log_info "Check your config.json file"
            exit 1
        fi
        echo ""
        return 1
    fi

    # Return value (caller must handle securely)
    echo "$value"
}

# Load environment variable from .env file if it exists
# Usage: get_env 'VAR_NAME' [required=false]
get_env() {
    local var_name="$1"
    local required="${2:-false}"

    # First check if it's already in environment
    if [[ -n "${!var_name:-}" ]]; then
        echo "${!var_name}"
        return 0
    fi

    # Then check .env file
    if [[ -f "$ENV_FILE" ]]; then
        local value
        value=$(grep "^${var_name}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    if [[ "$required" == "true" ]]; then
        log_error "Required environment variable missing: $var_name"
        log_info "Set it in .env file or environment"
        exit 1
    fi

    echo ""
    return 1
}

# Authenticate with ship (securely, no logging of credentials)
urbit_auth() {
    local ship_url access_code

    ship_url=$(get_config '.ship_url')
    access_code=$(get_config '.access_code')

    log_info "Authenticating with ship at $ship_url..."

    # POST login (do NOT use -v flag, it would leak password in logs)
    if curl -s -f -c "$COOKIE_FILE" -X POST "$ship_url/~/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "password=$access_code" > /dev/null 2>&1; then
        log_success "Authenticated"
        return 0
    else
        log_error "Authentication failed"
        log_warn "Check ship_url and access_code in config.json"
        log_warn "Ensure your ship is running at $ship_url"
        return 1
    fi
}

# POST request to ship (authenticated)
# Usage: urbit_post '/endpoint' --data-urlencode "key=value" ...
urbit_post() {
    local endpoint="$1"
    shift
    local ship_url

    ship_url=$(get_config '.ship_url')

    # Build curl command with form data args
    local curl_args=(
        -s -f
        -b "$COOKIE_FILE"
        -X POST
        "$ship_url$endpoint"
        -H "Content-Type: application/x-www-form-urlencoded"
    )

    # Add data args (each should be --data-urlencode "key=value")
    for arg in "$@"; do
        curl_args+=("$arg")
    done

    curl "${curl_args[@]}"
}

# POST JSON request to ship (authenticated)
# Usage: urbit_post_json '/endpoint' '{"json":"data"}'
urbit_post_json() {
    local endpoint="$1"
    local json_body="$2"
    local ship_url

    ship_url=$(get_config '.ship_url')

    curl -s -f \
        -b "$COOKIE_FILE" \
        -X POST \
        "$ship_url$endpoint" \
        -H "Content-Type: application/json" \
        -d "$json_body"
}

# GET request to ship (authenticated)
# Usage: urbit_get '/endpoint'
urbit_get() {
    local endpoint="$1"
    local ship_url

    ship_url=$(get_config '.ship_url')

    curl -s -f -b "$COOKIE_FILE" -X GET "$ship_url$endpoint"
}

# Verbose POST for debugging (still doesn't leak auth, just shows request/response)
urbit_post_verbose() {
    local endpoint="$1"
    shift
    local ship_url

    ship_url=$(get_config '.ship_url')

    local curl_args=(
        -v
        -b "$COOKIE_FILE"
        -X POST
        "$ship_url$endpoint"
        -H "Content-Type: application/x-www-form-urlencoded"
    )

    for arg in "$@"; do
        curl_args+=("$arg")
    done

    curl "${curl_args[@]}"
}

# Verbose POST JSON for debugging
urbit_post_json_verbose() {
    local endpoint="$1"
    local json_body="$2"
    local ship_url

    ship_url=$(get_config '.ship_url')

    curl -v \
        -b "$COOKIE_FILE" \
        -X POST \
        "$ship_url$endpoint" \
        -H "Content-Type: application/json" \
        -d "$json_body"
}

# Update credentials helper (secure - never logs secret values)
# Usage: update_creds "Credential Type" "/endpoint" --data-urlencode "key=value" ...
update_creds() {
    local cred_type="$1"
    local endpoint="$2"
    shift 2

    log_info "Updating ${cred_type} credentials..."

    if urbit_post "$endpoint" "$@"; then
        log_success "${cred_type} credentials updated successfully"
        return 0
    else
        log_error "Failed to update ${cred_type} credentials"
        log_warn "Check that your ship is running and the endpoint is correct"
        return 1
    fi
}

# Validate required command exists
require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command not found: $cmd"
        if [[ -n "$install_hint" ]]; then
            log_info "$install_hint"
        fi
        exit 1
    fi
}

# Check if ship is running
check_ship_running() {
    local ship_url
    ship_url=$(get_config '.ship_url')

    if curl -s -f "$ship_url" > /dev/null 2>&1; then
        return 0
    else
        log_warn "Ship does not appear to be running at $ship_url"
        return 1
    fi
}

# Validate jq is installed
require_command jq "Install with: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
