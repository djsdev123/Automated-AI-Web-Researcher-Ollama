#!/usr/bin/env bash
# Main Diagnostic Orchestrator
# Minimal script - all logic is in modular libraries
# This script just coordinates the flow

set -euo pipefail

# =============================================================================
# SETUP
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT

# Load modular libraries (DRY - reuse everything)
# shellcheck source=lib/core.sh
source "${SCRIPT_DIR}/lib/core.sh"
# shellcheck source=lib/check-engine.sh
source "${SCRIPT_DIR}/lib/check-engine.sh"
# shellcheck source=lib/report-builder.sh
source "${SCRIPT_DIR}/lib/report-builder.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

RULES_FILE="${SCRIPT_DIR}/diagnostics/rules.yaml"
PLATFORM_RULES="${SCRIPT_DIR}/diagnostics/platform/${PLATFORM}.yaml"
OUTPUT_FORMAT="${1:-console}"  # console, json, markdown
DEBUG="${DEBUG:-0}"

# =============================================================================
# LOAD .ENV FOR VARIABLE EXPANSION
# =============================================================================

if file_exists "${PROJECT_ROOT}/.env"; then
    log_debug "Loading environment from .env"
    set -a
    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/.env"
    set +a
else
    log_warning ".env file not found - some checks may fail"
fi

# =============================================================================
# PARSE YAML AND RUN CHECKS
# =============================================================================

run_diagnostics() {
    log_section "AI Researcher Diagnostics"
    log_info "Platform: $PLATFORM"
    log_info "Config: $RULES_FILE"
    echo ""

    # Clear any previous results
    clear_results

    # Simple YAML parsing (basic implementation)
    # In production, this would use yq or a proper YAML parser
    # For now, we'll run checks manually based on the config

    log_info "Running diagnostic checks..."
    echo ""

    # Load common environment variables with defaults
    export OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
    export OLLAMA_MODEL="${OLLAMA_MODEL:-phi3:3.8b-mini-128k-instruct}"
    export LLM_PROVIDER="${LLM_PROVIDER:-ollama}"

    # Execute checks (in real implementation, these would be parsed from YAML)
    run_check_suite

    # Get all results
    local -a results
    mapfile -t results < <(get_results)

    # Generate report
    log_section "Generating Report"
    generate_report "$OUTPUT_FORMAT" "${results[@]}"

    # Suggest fixes if there are failures
    if [[ "$OUTPUT_FORMAT" == "console" ]]; then
        echo ""
        suggest_fixes "${results[@]}"
    fi
}

# =============================================================================
# CHECK SUITE (Data-driven from YAML in production)
# =============================================================================

run_check_suite() {
    # Docker checks
    execute_check command "docker-installed" \
        "docker --version" \
        "Docker version" \
        "critical" \
        "5" || true

    execute_check command "docker-running" \
        "docker info" \
        "Server Version" \
        "critical" \
        "10" || true

    execute_check command "docker-compose-installed" \
        "docker-compose --version || docker compose version" \
        "version" \
        "warning" \
        "5" || true

    # macOS-specific checks
    if [[ "$PLATFORM" == "macos" ]]; then
        execute_check command "docker-file-sharing-macos" \
            "docker run --rm -v \"${PROJECT_ROOT}:/test\" alpine ls /test >/dev/null 2>&1" \
            "" \
            "critical" \
            "15" || true
    fi

    # Configuration file checks
    execute_check file_exists "env-file-exists" \
        "${PROJECT_ROOT}/.env" \
        "warning" || true

    execute_check file_exists "config-yaml-exists" \
        "${PROJECT_ROOT}/config/config.yaml" \
        "warning" || true

    execute_check file_exists "dockerfile-exists" \
        "${PROJECT_ROOT}/Dockerfile" \
        "critical" || true

    execute_check file_exists "docker-compose-exists" \
        "${PROJECT_ROOT}/docker-compose.yml" \
        "critical" || true

    # Environment variable checks
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        execute_check env_var "llm-provider-set" \
            "LLM_PROVIDER" \
            "" \
            "warning" || true

        execute_check env_var "ollama-url-set" \
            "OLLAMA_BASE_URL" \
            "" \
            "info" || true

        execute_check env_var "ollama-model-set" \
            "OLLAMA_MODEL" \
            "" \
            "info" || true
    fi

    # Network checks (only if relevant)
    if [[ "${LLM_PROVIDER}" == "ollama" ]]; then
        execute_check url_reachable "ollama-reachable" \
            "${OLLAMA_BASE_URL}/api/version" \
            "warning" \
            "5" || true
    fi

    # Port checks
    execute_check port_available "port-4000-available" \
        "4000" \
        "info" || true

    # Python checks
    execute_check command "python-installed" \
        "python3 --version" \
        "Python 3" \
        "critical" \
        "5" || true

    execute_check file_exists "requirements-file-exists" \
        "${PROJECT_ROOT}/requirements.txt" \
        "warning" || true
}

# =============================================================================
# USAGE
# =============================================================================

show_usage() {
    cat <<EOF
Usage: $0 [FORMAT]

Run diagnostics and generate report in specified format.

FORMATS:
  console     Human-readable colored output (default)
  json        JSON format for CI/CD
  markdown    Markdown format for documentation

ENVIRONMENT VARIABLES:
  DEBUG=1     Enable debug output

EXAMPLES:
  $0              # Console output
  $0 json         # JSON output
  $0 markdown > report.md  # Save markdown report

EXIT CODES:
  0   All checks passed
  1   One or more checks failed
  2   Missing dependencies
  3   Configuration error

EOF
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

main() {
    # Parse arguments
    case "${1:-}" in
        -h|--help|help)
            show_usage
            exit 0
            ;;
        console|json|markdown|md)
            OUTPUT_FORMAT="$1"
            ;;
        "")
            OUTPUT_FORMAT="console"
            ;;
        *)
            log_error "Unknown format: $1"
            show_usage
            exit 1
            ;;
    esac

    # Check dependencies
    if ! has_command docker; then
        log_error "Docker is required but not installed"
        log_info "Install from: https://docker.com"
        exit "$EXIT_MISSING_DEPENDENCY"
    fi

    # Run diagnostics
    run_diagnostics

    # Exit code based on results
    local failed=0
    for result in $(get_results); do
        if [[ "$(parse_result "$result" "status")" == "FAIL" ]] && \
           [[ "$(parse_result "$result" "severity")" == "critical" ]]; then
            ((failed++))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        exit "$EXIT_CHECK_FAILED"
    fi

    exit "$EXIT_SUCCESS"
}

# Run main function
main "$@"
