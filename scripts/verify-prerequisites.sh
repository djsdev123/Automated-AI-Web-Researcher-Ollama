#!/bin/bash
# Prerequisites verification script
# Run this before attempting Docker build

set -e

echo "=== Docker Prerequisites Verification ==="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_check() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

ERRORS=0

# 1. Check Docker is installed and running
echo "1. Checking Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    print_check 0 "Docker installed: $DOCKER_VERSION"

    # Check Docker is running
    if docker ps &> /dev/null; then
        print_check 0 "Docker daemon is running"
    else
        print_check 1 "Docker daemon is NOT running - start Docker Desktop"
        ((ERRORS++))
    fi

    # Check Docker version (minimum 20.10)
    MAJOR=$(echo $DOCKER_VERSION | cut -d. -f1)
    MINOR=$(echo $DOCKER_VERSION | cut -d. -f2)
    if [ "$MAJOR" -ge 20 ] && [ "$MINOR" -ge 10 ]; then
        print_check 0 "Docker version >= 20.10"
    else
        print_warning "Docker version < 20.10 - recommend upgrading"
    fi
else
    print_check 1 "Docker is NOT installed"
    ((ERRORS++))
fi

echo ""

# 2. Check Docker Compose
echo "2. Checking Docker Compose..."
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    print_check 0 "Docker Compose V2 installed: $COMPOSE_VERSION"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    print_warning "Using legacy docker-compose v1: $COMPOSE_VERSION (recommend Docker Compose V2)"
else
    print_check 1 "Docker Compose is NOT installed"
    ((ERRORS++))
fi

echo ""

# 3. Check system resources
echo "3. Checking system resources..."
# macOS specific
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Get Docker Desktop settings
    DOCKER_CPUS=$(docker info --format '{{.NCPU}}' 2>/dev/null || echo "unknown")
    DOCKER_MEM=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo "unknown")

    if [ "$DOCKER_CPUS" != "unknown" ] && [ "$DOCKER_CPUS" -ge 2 ]; then
        print_check 0 "Docker CPUs: $DOCKER_CPUS (recommended >= 2)"
    else
        print_warning "Docker CPUs: $DOCKER_CPUS (recommend >= 2 in Docker Desktop settings)"
    fi

    if [ "$DOCKER_MEM" != "unknown" ]; then
        DOCKER_MEM_GB=$((DOCKER_MEM / 1024 / 1024 / 1024))
        if [ "$DOCKER_MEM_GB" -ge 4 ]; then
            print_check 0 "Docker Memory: ${DOCKER_MEM_GB}GB (recommended >= 4GB)"
        else
            print_warning "Docker Memory: ${DOCKER_MEM_GB}GB (recommend >= 4GB in Docker Desktop settings)"
        fi
    fi
fi

echo ""

# 4. Check file sharing (macOS Docker Desktop)
echo "4. Checking Docker Desktop file sharing..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    CURRENT_DIR=$(pwd)
    print_check 0 "Current directory: $CURRENT_DIR"
    print_warning "Verify this path is shared in Docker Desktop → Settings → Resources → File Sharing"
fi

echo ""

# 5. Check Ollama on host
echo "5. Checking Ollama on host..."
if command -v ollama &> /dev/null; then
    OLLAMA_VERSION=$(ollama --version 2>&1 | head -1)
    print_check 0 "Ollama installed: $OLLAMA_VERSION"

    # Check if Ollama is running
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        print_check 0 "Ollama is running on localhost:11434"

        # List available models
        MODELS=$(curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | head -3)
        if [ -n "$MODELS" ]; then
            echo -e "${GREEN}  Available models:${NC}"
            echo "$MODELS" | while read -r model; do
                echo "    - $model"
            done
        fi
    else
        print_warning "Ollama not running - start with: ollama serve"
    fi
else
    print_warning "Ollama not installed - install from https://ollama.ai"
fi

echo ""

# 6. Check .env file
echo "6. Checking configuration..."
if [ -f .env ]; then
    print_check 0 ".env file exists"

    # Check key variables
    if grep -q "OLLAMA_MODEL=" .env; then
        MODEL=$(grep "OLLAMA_MODEL=" .env | cut -d'=' -f2)
        echo -e "${GREEN}  Model configured:${NC} $MODEL"
    else
        print_warning "OLLAMA_MODEL not set in .env"
    fi
else
    print_check 1 ".env file missing - run: cp .env.example .env"
    ((ERRORS++))
fi

echo ""

# 7. Check disk space
echo "7. Checking disk space..."
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}')
print_check 0 "Available disk space: $AVAILABLE_SPACE"
print_warning "Docker build requires ~2-3GB for layers and dependencies"

echo ""
echo "=== Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All critical prerequisites met${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Ensure Ollama is running: ollama serve"
    echo "  2. Build container: docker compose build"
    echo "  3. Run tests: ./scripts/test-container.sh"
    exit 0
else
    echo -e "${RED}✗ $ERRORS critical issue(s) found${NC}"
    echo "Fix the issues above before building"
    exit 1
fi
