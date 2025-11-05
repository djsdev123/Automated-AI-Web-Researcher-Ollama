#!/usr/bin/env bash
# Core Library - DRY Foundation for Diagnostic System
# Single source of truth for common utilities
# NO BUSINESS LOGIC - only reusable utilities

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Only set if not already defined (allow parent script to set these)
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

readonly SCRIPT_DIR
readonly PROJECT_ROOT

# =============================================================================
# COLOR CODES (Single source of truth for colors)
# =============================================================================

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    COLOR_RESET=$(tput sgr0)
    COLOR_RED=$(tput setaf 1)
    COLOR_GREEN=$(tput setaf 2)
    COLOR_YELLOW=$(tput setaf 3)
    COLOR_BLUE=$(tput setaf 4)
    COLOR_MAGENTA=$(tput setaf 5)
    COLOR_CYAN=$(tput setaf 6)
    COLOR_BOLD=$(tput bold)
else
    COLOR_RESET=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_MAGENTA=""
    COLOR_CYAN=""
    COLOR_BOLD=""
fi

# =============================================================================
# LOGGING FUNCTIONS (DRY - all output goes through these)
# =============================================================================

log_info() {
    echo "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" >&2
}

log_success() {
    echo "${COLOR_GREEN}[✓]${COLOR_RESET} $*" >&2
}

log_warning() {
    echo "${COLOR_YELLOW}[⚠]${COLOR_RESET} $*" >&2
}

log_error() {
    echo "${COLOR_RED}[✗]${COLOR_RESET} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "${COLOR_MAGENTA}[DEBUG]${COLOR_RESET} $*" >&2
    fi
}

log_section() {
    echo ""
    echo "${COLOR_CYAN}${COLOR_BOLD}━━━ $* ━━━${COLOR_RESET}"
}

# =============================================================================
# PLATFORM DETECTION (DRY - detect once, use everywhere)
# =============================================================================

detect_platform() {
    local os
    case "$(uname -s)" in
        Darwin*)  os="macos" ;;
        Linux*)   os="linux" ;;
        MINGW*|MSYS*|CYGWIN*) os="windows" ;;
        *)        os="unknown" ;;
    esac
    echo "$os"
}

PLATFORM=$(detect_platform)

# =============================================================================
# COMMAND AVAILABILITY (DRY - check once, cache result)
# =============================================================================

declare -A COMMAND_CACHE

has_command() {
    local cmd="$1"

    # Check cache first
    if [[ -n "${COMMAND_CACHE[$cmd]:-}" ]]; then
        return "${COMMAND_CACHE[$cmd]}"
    fi

    # Check and cache
    if command -v "$cmd" >/dev/null 2>&1; then
        COMMAND_CACHE[$cmd]=0
        return 0
    else
        COMMAND_CACHE[$cmd]=1
        return 1
    fi
}

require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! has_command "$cmd"; then
        log_error "Required command not found: $cmd"
        if [[ -n "$install_hint" ]]; then
            log_info "Install with: $install_hint"
        fi
        return 1
    fi
    return 0
}

# =============================================================================
# FILE OPERATIONS (DRY - safe file handling)
# =============================================================================

file_exists() {
    [[ -f "$1" ]]
}

dir_exists() {
    [[ -d "$1" ]]
}

is_readable() {
    [[ -r "$1" ]]
}

safe_source() {
    local file="$1"
    if file_exists "$file" && is_readable "$file"; then
        # shellcheck source=/dev/null
        source "$file"
        return 0
    else
        log_error "Cannot source file: $file"
        return 1
    fi
}

# =============================================================================
# YAML PARSING (DRY - centralized YAML handling)
# =============================================================================

# Try to use yq if available, otherwise fall back to basic parsing
parse_yaml_value() {
    local yaml_file="$1"
    local key_path="$2"  # e.g., "checks.docker.command"

    if has_command yq; then
        yq eval ".${key_path}" "$yaml_file" 2>/dev/null || echo ""
    else
        # Fallback: basic grep/sed parsing (limited functionality)
        local key="${key_path##*.}"  # Get last part of path
        grep -E "^[[:space:]]*${key}:" "$yaml_file" | \
            sed -E 's/^[[:space:]]*[^:]+:[[:space:]]*//' | \
            sed -E 's/^["'\'']//' | \
            sed -E 's/["'\'']$//' || echo ""
    fi
}

# =============================================================================
# EXIT CODE HANDLING (DRY - consistent exit codes)
# =============================================================================

EXIT_SUCCESS=0
EXIT_GENERAL_ERROR=1
EXIT_MISSING_DEPENDENCY=2
EXIT_CONFIG_ERROR=3
EXIT_CHECK_FAILED=10

exit_with_code() {
    local code="$1"
    local message="${2:-}"

    if [[ -n "$message" ]]; then
        log_error "$message"
    fi

    exit "$code"
}

# =============================================================================
# ARRAY/STRING UTILITIES (DRY - common operations)
# =============================================================================

string_contains() {
    [[ "$1" == *"$2"* ]]
}

string_trim() {
    local str="$1"
    # Remove leading/trailing whitespace
    str="${str#"${str%%[![:space:]]*}"}"
    str="${str%"${str##*[![:space:]]}"}"
    echo "$str"
}

array_contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# =============================================================================
# TIMER UTILITIES (DRY - execution timing)
# =============================================================================

declare -A TIMERS

timer_start() {
    local name="$1"
    TIMERS[$name]=$(date +%s)
}

timer_elapsed() {
    local name="$1"
    local start="${TIMERS[$name]:-}"

    if [[ -z "$start" ]]; then
        echo "0"
        return
    fi

    local end=$(date +%s)
    echo $((end - start))
}

# =============================================================================
# SAFE EXECUTION (DRY - run commands with timeout/error handling)
# =============================================================================

safe_exec() {
    local timeout="${1:-30}"
    shift

    if has_command timeout; then
        timeout "$timeout" "$@" 2>&1
    else
        "$@" 2>&1
    fi
}

# =============================================================================
# PROGRESS INDICATORS (DRY - consistent UI)
# =============================================================================

show_spinner() {
    local pid=$1
    local message="${2:-Processing...}"
    local spinstr='|/-\'

    echo -n "$message "
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\b\b\b"
    done
    printf "   \b\b\b"
}

# =============================================================================
# VALIDATION (DRY - input validation)
# =============================================================================

is_valid_url() {
    local url="$1"
    [[ "$url" =~ ^https?:// ]]
}

is_valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]
}

# =============================================================================
# EXPORTS (Make functions available to other scripts)
# =============================================================================

export -f log_info log_success log_warning log_error log_debug log_section
export -f has_command require_command
export -f file_exists dir_exists is_readable safe_source
export -f parse_yaml_value
export -f exit_with_code
export -f string_contains string_trim array_contains
export -f timer_start timer_elapsed
export -f safe_exec
export -f is_valid_url is_valid_port

# Make variables available
export SCRIPT_DIR PROJECT_ROOT PLATFORM
export COLOR_RESET COLOR_RED COLOR_GREEN COLOR_YELLOW COLOR_BLUE COLOR_MAGENTA COLOR_CYAN COLOR_BOLD
export EXIT_SUCCESS EXIT_GENERAL_ERROR EXIT_MISSING_DEPENDENCY EXIT_CONFIG_ERROR EXIT_CHECK_FAILED

log_debug "Core library loaded (Platform: $PLATFORM)"
