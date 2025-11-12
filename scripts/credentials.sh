#!/bin/bash
# Credential management library for urbit-master CLI
# Provides functions to update various service credentials in the Urbit ship
# Security: Never logs or echoes credential values

# Source core library (SCRIPT_DIR may already be set by core.sh)
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$SCRIPT_DIR/scripts/core.sh"

# Update Telegram credentials
# Usage: update_telegram [bot_token] [chat_id]
#   No args: Read from config.json
#   With args: Use provided values
update_telegram() {
    local bot_token chat_id

    if [[ "$#" -eq 2 ]]; then
        bot_token="$1"
        chat_id="$2"
    elif [[ "$#" -eq 0 ]]; then
        bot_token=$(get_config '.telegram.bot_token')
        chat_id=$(get_config '.telegram.chat_id')
    else
        log_error "Usage: update telegram [bot_token chat_id]"
        return 1
    fi

    urbit_auth || return 1

    update_creds "Telegram" "/master/update-creds" \
        --data-urlencode "bot-token=$bot_token" \
        --data-urlencode "chat-id=$chat_id"
}

# Update S3 credentials
# Usage: update_s3 [access_key] [secret_key] [region] [bucket] [endpoint]
#   No args: Read from config.json
#   With args: Use provided values
update_s3() {
    local access_key secret_key region bucket endpoint

    if [[ "$#" -eq 5 ]]; then
        access_key="$1"
        secret_key="$2"
        region="$3"
        bucket="$4"
        endpoint="$5"
    elif [[ "$#" -eq 0 ]]; then
        access_key=$(get_config '.s3.access_key')
        secret_key=$(get_config '.s3.secret_key')
        region=$(get_config '.s3.region')
        bucket=$(get_config '.s3.bucket')
        endpoint=$(get_config '.s3.endpoint')
    else
        log_error "Usage: update s3 [access_key secret_key region bucket endpoint]"
        return 1
    fi

    urbit_auth || return 1

    # Note: NOT logging any credential values
    log_info "Updating S3 credentials for bucket: $bucket"

    update_creds "S3" "/master/update-s3-creds" \
        --data-urlencode "access-key=$access_key" \
        --data-urlencode "secret-key=$secret_key" \
        --data-urlencode "region=$region" \
        --data-urlencode "bucket=$bucket" \
        --data-urlencode "endpoint=$endpoint"
}

# Update Claude API credentials
# Usage: update_claude [api_key]
#   No args: Read from config.json
#   With args: Use provided value
update_claude() {
    local api_key

    if [[ "$#" -eq 1 ]]; then
        api_key="$1"
    elif [[ "$#" -eq 0 ]]; then
        api_key=$(get_config '.claude.api_key')
    else
        log_error "Usage: update claude [api_key]"
        return 1
    fi

    urbit_auth || return 1

    update_creds "Claude API" "/master/update-claude-creds" \
        --data-urlencode "api-key=$api_key"
}

# Update Brave Search API credentials
# Usage: update_brave [api_key]
#   No args: Read from config.json
#   With args: Use provided value
update_brave() {
    local api_key

    if [[ "$#" -eq 1 ]]; then
        api_key="$1"
    elif [[ "$#" -eq 0 ]]; then
        api_key=$(get_config '.brave.api_key')
    else
        log_error "Usage: update brave [api_key]"
        return 1
    fi

    urbit_auth || return 1

    update_creds "Brave Search API" "/master/update-brave-creds" \
        --data-urlencode "api-key=$api_key"
}

# Update all credentials from config.json
update_all() {
    log_info "Updating all credentials from config.json..."
    echo ""

    local failed=0

    # Update Telegram if configured
    if get_config '.telegram.bot_token' false > /dev/null 2>&1; then
        if update_telegram; then
            echo ""
        else
            ((failed++))
        fi
    else
        log_warn "Skipping Telegram (not configured)"
        echo ""
    fi

    # Update S3 if configured
    if get_config '.s3.access_key' false > /dev/null 2>&1; then
        if update_s3; then
            echo ""
        else
            ((failed++))
        fi
    else
        log_warn "Skipping S3 (not configured)"
        echo ""
    fi

    # Update Claude if configured
    if get_config '.claude.api_key' false > /dev/null 2>&1; then
        if update_claude; then
            echo ""
        else
            ((failed++))
        fi
    else
        log_warn "Skipping Claude (not configured)"
        echo ""
    fi

    # Update Brave if configured
    if get_config '.brave.api_key' false > /dev/null 2>&1; then
        if update_brave; then
            echo ""
        else
            ((failed++))
        fi
    else
        log_warn "Skipping Brave Search (not configured)"
        echo ""
    fi

    if [[ $failed -eq 0 ]]; then
        log_success "All configured credentials updated successfully"
        return 0
    else
        log_error "$failed credential update(s) failed"
        return 1
    fi
}
