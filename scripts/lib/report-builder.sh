#!/usr/bin/env bash
# Report Builder - Modular Output Formatter
# Generates reports in multiple formats from standardized check results
# DRY - single input format, multiple output formats

set -euo pipefail

# Source core library
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./core.sh
source "${LIB_DIR}/core.sh"

# =============================================================================
# RESULT PARSING (DRY - parse standardized result format)
# =============================================================================

parse_result() {
    local result="$1"
    local field="$2"

    IFS='|' read -r name status message severity elapsed <<< "$result"

    case "$field" in
        name)     echo "$name" ;;
        status)   echo "$status" ;;
        message)  echo "$message" ;;
        severity) echo "$severity" ;;
        elapsed)  echo "$elapsed" ;;
        *)        echo "" ;;
    esac
}

# =============================================================================
# CONSOLE REPORT (Colored, human-readable)
# =============================================================================

report_console() {
    local results=("$@")

    local total=${#results[@]}
    local passed=0
    local failed=0
    local warned=0
    local skipped=0

    # Header
    log_section "Diagnostic Results"

    # Process each result
    for result in "${results[@]}"; do
        local name status message severity
        name=$(parse_result "$result" "name")
        status=$(parse_result "$result" "status")
        message=$(parse_result "$result" "message")
        severity=$(parse_result "$result" "severity")

        # Count by status
        case "$status" in
            PASS) ((passed++)) ;;
            FAIL) ((failed++)) ;;
            WARN) ((warned++)) ;;
            SKIP) ((skipped++)) ;;
        esac

        # Display result
        case "$status" in
            PASS)
                log_success "$name"
                ;;
            FAIL)
                if [[ "$severity" == "critical" ]]; then
                    log_error "$name"
                    echo "         ${COLOR_RED}$message${COLOR_RESET}"
                else
                    log_warning "$name"
                    echo "         ${COLOR_YELLOW}$message${COLOR_RESET}"
                fi
                ;;
            WARN)
                log_warning "$name"
                echo "         $message"
                ;;
            SKIP)
                log_info "$name (skipped)"
                ;;
        esac
    done

    # Summary
    echo ""
    log_section "Summary"
    echo "Total checks: $total"
    echo "${COLOR_GREEN}Passed:${COLOR_RESET} $passed"
    echo "${COLOR_RED}Failed:${COLOR_RESET} $failed"
    echo "${COLOR_YELLOW}Warnings:${COLOR_RESET} $warned"
    echo "${COLOR_BLUE}Skipped:${COLOR_RESET} $skipped"

    # Overall status
    echo ""
    if [[ $failed -eq 0 ]]; then
        log_success "All checks passed!"
        return 0
    else
        log_error "$failed check(s) failed"
        return 1
    fi
}

# =============================================================================
# JSON REPORT (Machine-readable, for CI/CD)
# =============================================================================

report_json() {
    local results=("$@")
    local output_file="${1:-/dev/stdout}"

    echo "{"
    echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "  \"platform\": \"$PLATFORM\","
    echo "  \"checks\": ["

    local first=true
    for result in "${results[@]}"; do
        if ! $first; then
            echo ","
        fi
        first=false

        local name status message severity elapsed
        name=$(parse_result "$result" "name")
        status=$(parse_result "$result" "status")
        message=$(parse_result "$result" "message")
        severity=$(parse_result "$result" "severity")
        elapsed=$(parse_result "$result" "elapsed")

        # Escape quotes in message
        message="${message//\"/\\\"}"

        echo "    {"
        echo "      \"name\": \"$name\","
        echo "      \"status\": \"$status\","
        echo "      \"message\": \"$message\","
        echo "      \"severity\": \"$severity\","
        echo "      \"elapsed_ms\": $elapsed"
        echo -n "    }"
    done

    echo ""
    echo "  ]"
    echo "}"
}

# =============================================================================
# MARKDOWN REPORT (Documentation, for reports)
# =============================================================================

report_markdown() {
    local results=("$@")

    echo "# Diagnostic Report"
    echo ""
    echo "**Generated:** $(date)"
    echo ""
    echo "**Platform:** $PLATFORM"
    echo ""

    # Results table
    echo "## Results"
    echo ""
    echo "| Check | Status | Severity | Message |"
    echo "|-------|--------|----------|---------|"

    for result in "${results[@]}"; do
        local name status message severity
        name=$(parse_result "$result" "name")
        status=$(parse_result "$result" "status")
        message=$(parse_result "$result" "message")
        severity=$(parse_result "$result" "severity")

        # Status emoji
        local status_icon
        case "$status" in
            PASS) status_icon="✅" ;;
            FAIL) status_icon="❌" ;;
            WARN) status_icon="⚠️" ;;
            SKIP) status_icon="⏭️" ;;
            *)    status_icon="❓" ;;
        esac

        echo "| $name | $status_icon $status | $severity | $message |"
    done

    echo ""

    # Summary
    local total=${#results[@]}
    local passed=0
    local failed=0

    for result in "${results[@]}"; do
        local status
        status=$(parse_result "$result" "status")
        case "$status" in
            PASS) ((passed++)) ;;
            FAIL) ((failed++)) ;;
        esac
    done

    echo "## Summary"
    echo ""
    echo "- **Total Checks:** $total"
    echo "- **Passed:** $passed"
    echo "- **Failed:** $failed"
    echo "- **Success Rate:** $((passed * 100 / total))%"
}

# =============================================================================
# FIX SUGGESTIONS (DRY - generate actionable fixes)
# =============================================================================

suggest_fixes() {
    local results=("$@")
    local fixes_file="${PROJECT_ROOT}/scripts/diagnostics/fixes.yaml"

    log_section "Suggested Fixes"

    local has_failures=false

    for result in "${results[@]}"; do
        local name status severity
        name=$(parse_result "$result" "name")
        status=$(parse_result "$result" "status")
        severity=$(parse_result "$result" "severity")

        if [[ "$status" == "FAIL" ]]; then
            has_failures=true
            echo ""
            echo "${COLOR_YELLOW}Issue:${COLOR_RESET} $name"

            # Try to load fix suggestions from YAML
            if file_exists "$fixes_file"; then
                # This is simplified - in real implementation would parse YAML
                echo "${COLOR_CYAN}Suggested fix:${COLOR_RESET}"
                echo "  See documentation for $name"
            fi
        fi
    done

    if ! $has_failures; then
        log_success "No fixes needed - all checks passed!"
    fi
}

# =============================================================================
# REPORT DISPATCHER (DRY - route to appropriate formatter)
# =============================================================================

generate_report() {
    local format="$1"
    shift
    local results=("$@")

    case "$format" in
        console)
            report_console "${results[@]}"
            ;;
        json)
            report_json "${results[@]}"
            ;;
        markdown|md)
            report_markdown "${results[@]}"
            ;;
        fixes)
            suggest_fixes "${results[@]}"
            ;;
        *)
            log_error "Unknown report format: $format"
            return 1
            ;;
    esac
}

# =============================================================================
# EXPORTS
# =============================================================================

export -f parse_result
export -f report_console report_json report_markdown suggest_fixes
export -f generate_report

log_debug "Report builder loaded"
