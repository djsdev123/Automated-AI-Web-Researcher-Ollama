#!/bin/bash
# Master test runner - runs all verification checks in order
# Usage: ./scripts/run-all-checks.sh

set +e  # Don't exit on errors, we want to run all checks

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Automated AI Web Researcher - Full Test Suite   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

TOTAL_CHECKS=3
PASSED=0
FAILED=0

run_check() {
    local name=$1
    local script=$2
    local num=$3

    echo ""
    echo -e "${BLUE}[$num/$TOTAL_CHECKS] Running: $name${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ ! -f "$script" ]; then
        echo -e "${RED}✗ Script not found: $script${NC}"
        ((FAILED++))
        return 1
    fi

    chmod +x "$script"

    if bash "$script"; then
        echo -e "${GREEN}✓ $name PASSED${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ $name FAILED${NC}"
        ((FAILED++))
        return 1
    fi
}

# Run all checks
run_check "Security Verification" "$SCRIPT_DIR/security-check.sh" 1
run_check "Prerequisites Check" "$SCRIPT_DIR/verify-prerequisites.sh" 2
run_check "Container Build & Tests" "$SCRIPT_DIR/test-container.sh" 3

# Final summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Final Summary                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ ALL CHECKS PASSED ($PASSED/$TOTAL_CHECKS) ✓✓✓${NC}"
    echo ""
    echo "Your environment is ready! Next steps:"
    echo "  1. Start services:    docker compose up"
    echo "  2. Open in VS Code:   code ."
    echo "  3. View logs:         docker compose logs -f researcher"
    echo ""
    exit 0
else
    echo -e "${RED}✗✗✗ SOME CHECKS FAILED ✗✗✗${NC}"
    echo ""
    echo "Results:"
    echo -e "  ${GREEN}Passed: $PASSED${NC}"
    echo -e "  ${RED}Failed: $FAILED${NC}"
    echo ""
    echo "Review the output above and fix failing checks"
    exit 1
fi
