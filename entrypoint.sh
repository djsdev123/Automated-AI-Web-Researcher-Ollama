#!/bin/bash
# Entrypoint script for Automated AI Web Researcher Docker container
# Performs health checks and environment validation before starting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       Automated AI Web Researcher - Starting...         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to print colored messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Function to check Ollama connectivity
check_ollama() {
    if [ "${LLM_PROVIDER:-ollama}" == "ollama" ]; then
        log_info "Checking Ollama connectivity at ${OLLAMA_BASE_URL}..."

        local max_attempts=5
        local attempt=1

        while [ $attempt -le $max_attempts ]; do
            if curl -sf "${OLLAMA_BASE_URL}/api/version" > /dev/null 2>&1; then
                local version=$(curl -s "${OLLAMA_BASE_URL}/api/version" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
                log_success "Ollama is reachable (version: ${version})"

                # Check if model is available
                check_ollama_model
                return 0
            fi

            log_warning "Attempt $attempt/$max_attempts: Ollama not reachable, waiting 2s..."
            sleep 2
            attempt=$((attempt + 1))
        done

        log_error "Ollama not reachable at ${OLLAMA_BASE_URL}"
        log_warning "Make sure Ollama is running on your host machine:"
        echo "  1. Install Ollama: https://ollama.ai"
        echo "  2. Start Ollama server: ollama serve"
        echo "  3. Pull your model: ollama pull ${OLLAMA_MODEL}"
        echo ""

        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to check if Ollama model is pulled
check_ollama_model() {
    log_info "Checking if model '${OLLAMA_MODEL}' is available..."

    # Try to list models and check if our model exists
    if curl -sf "${OLLAMA_BASE_URL}/api/tags" > /dev/null 2>&1; then
        local models=$(curl -s "${OLLAMA_BASE_URL}/api/tags")

        if echo "$models" | grep -q "\"name\":\"${OLLAMA_MODEL}\""; then
            log_success "Model '${OLLAMA_MODEL}' is available"
        else
            log_warning "Model '${OLLAMA_MODEL}' not found in Ollama"
            log_warning "Pull it with: ollama pull ${OLLAMA_MODEL}"

            # List available models
            echo ""
            log_info "Available models:"
            echo "$models" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sed 's/^/  - /'
            echo ""
        fi
    fi
}

# Function to check OpenAI configuration
check_openai() {
    if [ "${LLM_PROVIDER}" == "openai" ]; then
        log_info "Checking OpenAI configuration..."

        if [ -z "${OPENAI_API_KEY}" ]; then
            log_error "OPENAI_API_KEY is not set!"
            log_warning "Set it in .env file or environment variable"
            exit 1
        fi

        # Validate API key format
        if [[ ! "${OPENAI_API_KEY}" =~ ^sk- ]]; then
            log_warning "OpenAI API key should start with 'sk-'"
        fi

        log_success "OpenAI API key is configured"
        log_warning "This application makes MANY API calls - monitor your costs!"
    fi
}

# Function to check Anthropic configuration
check_anthropic() {
    if [ "${LLM_PROVIDER}" == "anthropic" ]; then
        log_info "Checking Anthropic configuration..."

        if [ -z "${ANTHROPIC_API_KEY}" ]; then
            log_error "ANTHROPIC_API_KEY is not set!"
            log_warning "Set it in .env file or environment variable"
            exit 1
        fi

        # Validate API key format
        if [[ ! "${ANTHROPIC_API_KEY}" =~ ^sk-ant- ]]; then
            log_warning "Anthropic API key should start with 'sk-ant-'"
        fi

        log_success "Anthropic API key is configured"
        log_warning "This application makes MANY API calls - monitor your costs!"
    fi
}

# Function to verify Python environment
check_python() {
    log_info "Checking Python environment..."

    if command -v python &> /dev/null; then
        local python_version=$(python --version 2>&1 | cut -d' ' -f2)
        log_success "Python ${python_version} is available"
    else
        log_error "Python not found!"
        exit 1
    fi
}

# Function to check required directories
check_directories() {
    log_info "Checking required directories..."

    for dir in "${LOG_DIR:-/app/logs}" "${DATA_DIR:-/app/data}" "/app/config"; do
        if [ ! -d "$dir" ]; then
            log_warning "Creating directory: $dir"
            mkdir -p "$dir"
        fi

        # Ensure directory is writable
        if [ ! -w "$dir" ]; then
            log_warning "Making directory writable: $dir"
            chmod 777 "$dir"
        fi
    done

    log_success "All directories are ready"
}

# Function to check configuration file
check_config() {
    log_info "Checking configuration file..."

    local config_file="${CONFIG_PATH:-/app/config/config.yaml}"

    if [ ! -f "$config_file" ]; then
        log_warning "Configuration file not found at: $config_file"
        log_info "Will attempt to use legacy llm_config.py"
    else
        log_success "Configuration file found: $config_file"

        # Validate YAML syntax
        if command -v python &> /dev/null; then
            if python -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
                log_success "Configuration file is valid YAML"
            else
                log_error "Configuration file has syntax errors!"
                exit 1
            fi
        fi
    fi
}

# Function to display configuration summary
show_config_summary() {
    echo ""
    log_info "Configuration Summary:"
    echo "  LLM Provider: ${LLM_PROVIDER:-ollama}"

    if [ "${LLM_PROVIDER:-ollama}" == "ollama" ]; then
        echo "  Ollama URL: ${OLLAMA_BASE_URL}"
        echo "  Ollama Model: ${OLLAMA_MODEL}"
    elif [ "${LLM_PROVIDER}" == "openai" ]; then
        echo "  OpenAI Model: ${OPENAI_MODEL}"
    elif [ "${LLM_PROVIDER}" == "anthropic" ]; then
        echo "  Anthropic Model: ${ANTHROPIC_MODEL}"
    fi

    echo "  Log Level: ${LOG_LEVEL:-INFO}"
    echo "  Config Path: ${CONFIG_PATH:-/app/config/config.yaml}"
    echo ""
}

# Main execution
main() {
    # Run all checks
    check_python
    check_directories
    check_config
    check_ollama
    check_openai
    check_anthropic

    # Show summary
    show_config_summary

    log_success "All checks passed! Starting application..."
    echo ""

    # Execute the main command
    exec "$@"
}

# Run main function
main "$@"
