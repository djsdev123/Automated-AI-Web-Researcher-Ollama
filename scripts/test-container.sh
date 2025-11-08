#!/bin/bash
# Container build and validation test script
# Run this to test the Docker build thoroughly

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Docker Container Build & Validation Tests ===${NC}"
echo ""

ERRORS=0

print_step() {
    echo -e "${BLUE}➜${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

# Test 1: Validate docker-compose.yml
print_step "Test 1: Validating docker-compose.yml..."
if docker compose config > /dev/null 2>&1; then
    print_success "docker-compose.yml is valid"
else
    print_error "docker-compose.yml has errors"
    docker compose config
fi
echo ""

# Test 2: Validate .env file
print_step "Test 2: Validating .env configuration..."
if [ ! -f .env ]; then
    print_error ".env file missing - run: cp .env.example .env"
else
    print_success ".env file exists"

    # Check required variables
    REQUIRED_VARS=("LLM_PROVIDER" "OLLAMA_BASE_URL" "OLLAMA_MODEL")
    for var in "${REQUIRED_VARS[@]}"; do
        if grep -q "^${var}=" .env; then
            VALUE=$(grep "^${var}=" .env | cut -d'=' -f2)
            echo -e "  ${GREEN}✓${NC} $var=$VALUE"
        else
            print_error "$var not set in .env"
        fi
    done
fi
echo ""

# Test 3: Build the container (this will take several minutes)
print_step "Test 3: Building Docker container (this may take 5-10 minutes)..."
echo "  Building researcher service..."

# Build with output
if docker compose build researcher 2>&1 | tee /tmp/docker-build.log; then
    print_success "Container built successfully"

    # Check for warnings
    if grep -i "warning" /tmp/docker-build.log > /dev/null; then
        echo -e "${YELLOW}⚠ Build warnings found:${NC}"
        grep -i "warning" /tmp/docker-build.log | head -5
    fi
else
    print_error "Container build failed"
    echo ""
    echo "Last 20 lines of build output:"
    tail -20 /tmp/docker-build.log
    exit 1
fi
echo ""

# Test 4: Validate container can start
print_step "Test 4: Testing container startup..."
if docker compose run --rm researcher python -c "print('Container starts successfully')" > /dev/null 2>&1; then
    print_success "Container starts and Python runs"
else
    print_error "Container failed to start"
fi
echo ""

# Test 5: Validate Python dependencies
print_step "Test 5: Validating Python dependencies..."
echo "  Checking critical imports..."

IMPORTS=(
    "import colorama"
    "import requests"
    "import bs4"
    "import yaml"
    "import openai"
    "import anthropic"
)

for import_stmt in "${IMPORTS[@]}"; do
    PKG=$(echo "$import_stmt" | awk '{print $2}')
    if docker compose run --rm researcher python -c "$import_stmt" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $PKG"
    else
        print_error "$PKG import failed"
    fi
done
echo ""

# Test 6: Validate config loading
print_step "Test 6: Testing configuration loading..."
if docker compose run --rm researcher python -c "
from config_loader import ConfigLoader
config = ConfigLoader('/app/config/config.yaml')
print('Config loaded:', config.get('app.name'))
" 2>&1 | grep -q "Automated AI Web Researcher"; then
    print_success "Configuration loads successfully"
else
    print_error "Configuration loading failed"
fi
echo ""

# Test 7: Check file permissions
print_step "Test 7: Checking file permissions..."
if docker compose run --rm researcher sh -c "touch /app/data/test.txt && rm /app/data/test.txt" 2>/dev/null; then
    print_success "Data directory is writable"
else
    print_error "Data directory permissions issue"
fi

if docker compose run --rm researcher sh -c "touch /app/logs/test.log && rm /app/logs/test.log" 2>/dev/null; then
    print_success "Logs directory is writable"
else
    print_error "Logs directory permissions issue"
fi
echo ""

# Test 8: Validate entrypoint script
print_step "Test 8: Testing entrypoint script..."
if docker compose run --rm researcher sh -c "/app/entrypoint.sh echo 'Entrypoint works'" 2>&1 | grep -q "Entrypoint works"; then
    print_success "Entrypoint script executes"
else
    print_error "Entrypoint script failed"
fi
echo ""

# Test 9: Check Ollama connectivity (if running)
print_step "Test 9: Testing Ollama connectivity from container..."
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    if docker compose run --rm researcher python -c "
import os
import urllib.request
import urllib.error

url = os.getenv('OLLAMA_BASE_URL', 'http://host.docker.internal:11434')
try:
    urllib.request.urlopen(f'{url}/api/tags', timeout=5)
    print('Connected')
except urllib.error.URLError as e:
    print(f'Failed: {e}')
" 2>&1 | grep -q "Connected"; then
        print_success "Container can reach Ollama on host"
    else
        print_error "Container cannot reach Ollama (check host.docker.internal)"
    fi
else
    echo -e "${YELLOW}⚠ Ollama not running on host - skipping connectivity test${NC}"
fi
echo ""

# Test 10: Security check - no root processes
print_step "Test 10: Security - checking for non-root user..."
USER_CHECK=$(docker compose run --rm researcher whoami 2>/dev/null || echo "root")
if [ "$USER_CHECK" != "root" ]; then
    print_success "Running as non-root user: $USER_CHECK"
else
    echo -e "${YELLOW}⚠ Container runs as root (acceptable for development)${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}=== Test Summary ===${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Container is ready. Next steps:"
    echo "  1. Start services: docker compose up"
    echo "  2. Or open in DevContainer (VS Code)"
    echo "  3. View logs: docker compose logs -f"
    exit 0
else
    echo -e "${RED}✗ $ERRORS test(s) failed${NC}"
    echo "Review errors above and fix before deploying"
    exit 1
fi
