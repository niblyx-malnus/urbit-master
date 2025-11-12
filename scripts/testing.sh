#!/bin/bash
# Testing library for urbit-master CLI
# Provides functions to test various endpoints in the Urbit ship

# Source core library (SCRIPT_DIR may already be set by core.sh)
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$SCRIPT_DIR/scripts/core.sh"

# Test S3 upload
# Usage: test_s3_upload [text] [filename]
test_s3_upload() {
    local text="${1:-Hello from Urbit!}"
    local filename="${2:-test-from-urbit.txt}"

    urbit_auth || return 1

    log_info "Testing S3 upload..."
    log_info "File: $filename"
    log_info "Text: $text"

    if urbit_post_verbose "/master/s3-upload" \
        --data-urlencode "text=$text" \
        --data-urlencode "filename=$filename"; then
        echo ""
        log_success "S3 upload test completed"
        return 0
    else
        echo ""
        log_error "S3 upload test failed"
        return 1
    fi
}

# Test S3 upload directory
# Usage: test_s3_upload_directory [directory] [prefix]
test_s3_upload_directory() {
    local directory="${1:-/tmp/test-dir}"
    local prefix="${2:-test/}"

    urbit_auth || return 1

    log_info "Testing S3 directory upload..."
    log_info "Directory: $directory"
    log_info "Prefix: $prefix"

    if urbit_post_verbose "/master/s3-upload-directory" \
        --data-urlencode "directory=$directory" \
        --data-urlencode "prefix=$prefix"; then
        echo ""
        log_success "S3 directory upload test completed"
        return 0
    else
        echo ""
        log_error "S3 directory upload test failed"
        return 1
    fi
}

# Test S3 get file
# Usage: test_s3_get [filename]
test_s3_get() {
    local filename="${1:-test-from-urbit.txt}"

    urbit_auth || return 1

    log_info "Testing S3 get file..."
    log_info "File: $filename"

    if urbit_post_verbose "/master/s3-get" \
        --data-urlencode "filename=$filename"; then
        echo ""
        log_success "S3 get test completed"
        return 0
    else
        echo ""
        log_error "S3 get test failed"
        return 1
    fi
}

# Test S3 get directory
# Usage: test_s3_get_directory [prefix]
test_s3_get_directory() {
    local prefix="${1:-test/}"

    urbit_auth || return 1

    log_info "Testing S3 get directory..."
    log_info "Prefix: $prefix"

    if urbit_post_verbose "/master/s3-get-directory" \
        --data-urlencode "prefix=$prefix"; then
        echo ""
        log_success "S3 get directory test completed"
        return 0
    else
        echo ""
        log_error "S3 get directory test failed"
        return 1
    fi
}

# Test S3 list files
# Usage: test_s3_list [prefix]
test_s3_list() {
    local prefix="${1:-}"

    urbit_auth || return 1

    log_info "Testing S3 list files..."
    if [[ -n "$prefix" ]]; then
        log_info "Prefix: $prefix"
    else
        log_info "Listing all files"
    fi

    if [[ -n "$prefix" ]]; then
        urbit_post_verbose "/master/s3-list" \
            --data-urlencode "prefix=$prefix"
    else
        urbit_post_verbose "/master/s3-list"
    fi

    local result=$?
    echo ""
    if [[ $result -eq 0 ]]; then
        log_success "S3 list test completed"
        return 0
    else
        log_error "S3 list test failed"
        return 1
    fi
}

# Test S3 delete file
# Usage: test_s3_delete [filename]
test_s3_delete() {
    local filename="${1:-test-from-urbit.txt}"

    urbit_auth || return 1

    log_info "Testing S3 delete file..."
    log_info "File: $filename"

    if urbit_post_verbose "/master/s3-delete" \
        --data-urlencode "filename=$filename"; then
        echo ""
        log_success "S3 delete test completed"
        return 0
    else
        echo ""
        log_error "S3 delete test failed"
        return 1
    fi
}

# Test Claude API
# Usage: test_claude [prompt]
test_claude() {
    local prompt="${1:-What is the meaning of life?}"

    urbit_auth || return 1

    log_info "Testing Claude API..."
    log_info "Prompt: $prompt"

    if urbit_post_verbose "/master/claude" \
        --data-urlencode "prompt=$prompt"; then
        echo ""
        log_success "Claude API test completed"
        return 0
    else
        echo ""
        log_error "Claude API test failed"
        return 1
    fi
}

# Test Claude with MCP
# Usage: test_claude_mcp [prompt]
test_claude_mcp() {
    local prompt="${1:-Send a telegram message saying 'Hello from MCP test!'}"

    urbit_auth || return 1

    log_info "Testing Claude with MCP..."
    log_info "Prompt: $prompt"

    # Get Claude API key
    local api_key
    api_key=$(get_config '.claude.api_key')

    # Get auth cookie for MCP authorization
    local cookie_value
    cookie_value=$(grep -o 'urbauth-.*' "$COOKIE_FILE" | cut -d$'\t' -f2)

    # Build JSON request
    local json_body
    json_body=$(jq -n \
        --arg model "claude-3-5-sonnet-20241022" \
        --arg prompt "$prompt" \
        --arg token "$cookie_value" \
        --arg ship_url "$(get_config '.ship_url')" \
        '{
            "model": $model,
            "max_tokens": 1024,
            "messages": [{
                "role": "user",
                "content": $prompt
            }],
            "tools": [{
                "type": "custom",
                "name": "mcp",
                "mcp_server": {
                    "url": ($ship_url + "/master/mcp"),
                    "authorization_token": $token
                }
            }]
        }')

    log_debug "Request body: $json_body"

    if curl -v \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -H "x-api-key: $api_key" \
        -d "$json_body" \
        https://api.anthropic.com/v1/messages; then
        echo ""
        log_success "Claude MCP test completed"
        return 0
    else
        echo ""
        log_error "Claude MCP test failed"
        return 1
    fi
}

# Test MCP endpoint
# Usage: test_mcp [method] [args...]
#   method: initialize, tools/list, send_telegram
test_mcp() {
    local method="${1:-initialize}"
    shift

    urbit_auth || return 1

    local json_body

    case "$method" in
        "initialize")
            log_info "Testing MCP initialize..."
            json_body='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"urbit-master-cli","version":"1.0.0"}}}'
            ;;
        "tools/list")
            log_info "Testing MCP tools/list..."
            json_body='{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
            ;;
        "send_telegram")
            local message="${1:-Hello from MCP test!}"
            log_info "Testing MCP send_telegram..."
            log_info "Message: $message"
            json_body=$(jq -n --arg msg "$message" \
                '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"send_telegram","arguments":{"message":$msg}}}')
            ;;
        *)
            log_error "Unknown MCP test method: $method"
            log_info "Available methods: initialize, tools/list, send_telegram"
            return 1
            ;;
    esac

    if urbit_post_json_verbose "/master/mcp" "$json_body"; then
        echo ""
        log_success "MCP test completed"
        return 0
    else
        echo ""
        log_error "MCP test failed"
        return 1
    fi
}

# Test web search
# Usage: test_web_search [query]
test_web_search() {
    local query="${1:-urbit}"

    urbit_auth || return 1

    log_info "Testing web search..."
    log_info "Query: $query"

    if urbit_post_verbose "/master/web-search" \
        --data-urlencode "query=$query"; then
        echo ""
        log_success "Web search test completed"
        return 0
    else
        echo ""
        log_error "Web search test failed"
        return 1
    fi
}
