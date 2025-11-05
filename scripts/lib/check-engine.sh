#!/usr/bin/env bash
# Generic Check Engine - Data-Driven Check Executor
# This engine can run ANY check defined in YAML config
# NO HARDCODED CHECKS - completely config-driven for maximum modularity

set -euo pipefail

# Source core library (DRY - reuse utilities)
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./core.sh
source "${LIB_DIR}/core.sh"

# =============================================================================
# CHECK RESULT STRUCTURE (DRY - standardized output format)
# =============================================================================

# Result format:
# name|status|message|severity|elapsed_ms
# status: PASS, FAIL, WARN, SKIP
# severity: critical, warning, info

declare -a CHECK_RESULTS=()

add_result() {
    local name="$1"
    local status="$2"      # PASS, FAIL, WARN, SKIP
    local message="$3"
    local severity="${4:-info}"
    local elapsed="${5:-0}"

    CHECK_RESULTS+=("${name}|${status}|${message}|${severity}|${elapsed}")
}

get_results() {
    printf '%s\n' "${CHECK_RESULTS[@]}"
}

clear_results() {
    CHECK_RESULTS=()
}

# =============================================================================
# CHECK TYPES (DRY - generic check executors)
# =============================================================================

# Execute command-based check
check_command() {
    local name="$1"
    local command="$2"
    local expect="${3:-}"
    local severity="${4:-info}"
    local timeout="${5:-30}"

    log_debug "Running command check: $name"
    timer_start "$name"

    local output
    local exit_code=0

    output=$(safe_exec "$timeout" bash -c "$command") || exit_code=$?

    local elapsed
    elapsed=$(timer_elapsed "$name")

    # Check exit code
    if [[ $exit_code -ne 0 ]]; then
        add_result "$name" "FAIL" "Command failed (exit $exit_code): $command" "$severity" "$elapsed"
        return 1
    fi

    # Check expected output if specified
    if [[ -n "$expect" ]]; then
        if string_contains "$output" "$expect"; then
            add_result "$name" "PASS" "Check passed" "$severity" "$elapsed"
            return 0
        else
            add_result "$name" "FAIL" "Expected '$expect' not found in output" "$severity" "$elapsed"
            return 1
        fi
    fi

    add_result "$name" "PASS" "Command executed successfully" "$severity" "$elapsed"
    return 0
}

# Check if file exists
check_file_exists() {
    local name="$1"
    local filepath="$2"
    local severity="${3:-info}"

    log_debug "Running file check: $name"
    timer_start "$name"

    # Expand environment variables in filepath
    filepath=$(eval echo "$filepath")

    if file_exists "$filepath"; then
        local elapsed
        elapsed=$(timer_elapsed "$name")
        add_result "$name" "PASS" "File exists: $filepath" "$severity" "$elapsed"
        return 0
    else
        local elapsed
        elapsed=$(timer_elapsed "$name")
        add_result "$name" "FAIL" "File not found: $filepath" "$severity" "$elapsed"
        return 1
    fi
}

# Check URL is reachable
check_url_reachable() {
    local name="$1"
    local url="$2"
    local severity="${3:-info}"
    local timeout="${4:-10}"

    log_debug "Running URL check: $name"
    timer_start "$name"

    # Expand environment variables in URL
    url=$(eval echo "$url")

    if ! is_valid_url "$url"; then
        local elapsed
        elapsed=$(timer_elapsed "$name")
        add_result "$name" "FAIL" "Invalid URL format: $url" "$severity" "$elapsed"
        return 1
    fi

    local http_code
    http_code=$(curl -sf -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null) || http_code="000"

    local elapsed
    elapsed=$(timer_elapsed "$name")

    if [[ "$http_code" =~ ^2 ]]; then
        add_result "$name" "PASS" "URL reachable (HTTP $http_code): $url" "$severity" "$elapsed"
        return 0
    else
        add_result "$name" "FAIL" "URL not reachable (HTTP $http_code): $url" "$severity" "$elapsed"
        return 1
    fi
}

# Check port is available (not in use)
check_port_available() {
    local name="$1"
    local port="$2"
    local severity="${3:-info}"

    log_debug "Running port check: $name"
    timer_start "$name"

    if ! is_valid_port "$port"; then
        local elapsed
        elapsed=$(timer_elapsed "$name")
        add_result "$name" "FAIL" "Invalid port number: $port" "$severity" "$elapsed"
        return 1
    fi

    # Platform-specific port check
    local in_use=false
    case "$PLATFORM" in
        macos|linux)
            if lsof -i ":$port" -sTCP:LISTEN -t >/dev/null 2>&1 || \
               netstat -an 2>/dev/null | grep -E "[:.]$port[[:space:]]" | grep -q LISTEN; then
                in_use=true
            fi
            ;;
        *)
            # Fallback: try to connect
            if timeout 1 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
                in_use=true
            fi
            ;;
    esac

    local elapsed
    elapsed=$(timer_elapsed "$name")

    if $in_use; then
        add_result "$name" "FAIL" "Port $port is already in use" "$severity" "$elapsed"
        return 1
    else
        add_result "$name" "PASS" "Port $port is available" "$severity" "$elapsed"
        return 0
    fi
}

# Check environment variable is set
check_env_var() {
    local name="$1"
    local var_name="$2"
    local expected_value="${3:-}"  # Optional: check specific value
    local severity="${4:-info}"

    log_debug "Running env var check: $name"
    timer_start "$name"

    local actual_value="${!var_name:-}"

    if [[ -z "$actual_value" ]]; then
        local elapsed
        elapsed=$(timer_elapsed "$name")
        add_result "$name" "FAIL" "Environment variable not set: $var_name" "$severity" "$elapsed"
        return 1
    fi

    # If expected value specified, check it matches
    if [[ -n "$expected_value" ]] && [[ "$actual_value" != "$expected_value" ]]; then
        local elapsed
        elapsed=$(timer_elapsed "$name")
        add_result "$name" "FAIL" "$var_name=$actual_value (expected: $expected_value)" "$severity" "$elapsed"
        return 1
    fi

    local elapsed
    elapsed=$(timer_elapsed "$name")
    add_result "$name" "PASS" "$var_name is set" "$severity" "$elapsed"
    return 0
}

# =============================================================================
# GENERIC CHECK DISPATCHER (DRY - route to appropriate check type)
# =============================================================================

execute_check() {
    local check_type="$1"
    shift

    case "$check_type" in
        command)
            check_command "$@"
            ;;
        file_exists)
            check_file_exists "$@"
            ;;
        url_reachable)
            check_url_reachable "$@"
            ;;
        port_available)
            check_port_available "$@"
            ;;
        env_var)
            check_env_var "$@"
            ;;
        *)
            log_error "Unknown check type: $check_type"
            return 1
            ;;
    esac
}

# =============================================================================
# PLATFORM FILTERING (DRY - skip checks not for current platform)
# =============================================================================

should_run_on_platform() {
    local platforms="$1"  # Comma-separated list or "all"

    [[ "$platforms" == "all" ]] && return 0
    [[ "$platforms" == "$PLATFORM" ]] && return 0

    # Check if current platform in comma-separated list
    IFS=',' read -ra PLATFORM_LIST <<< "$platforms"
    array_contains "$PLATFORM" "${PLATFORM_LIST[@]}"
}

# =============================================================================
# EXPORTS
# =============================================================================

export -f add_result get_results clear_results
export -f check_command check_file_exists check_url_reachable check_port_available check_env_var
export -f execute_check should_run_on_platform

log_debug "Check engine loaded"
