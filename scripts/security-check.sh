#!/bin/bash
# Security verification script
# Checks for known vulnerabilities and security issues

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Security Verification ===${NC}"
echo ""

WARNINGS=0
CRITICAL=0

print_critical() {
    echo -e "${RED}✗ CRITICAL:${NC} $1"
    ((CRITICAL++))
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING:${NC} $1"
    ((WARNINGS++))
}

print_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# 1. Check requirements.txt for unpinned versions
echo "1. Checking dependency pinning..."
if [ -f requirements.txt ]; then
    UNPINNED=$(grep -v "^#" requirements.txt | grep -v "^$" | grep -v "==" | grep -v "; sys_platform" | wc -l | tr -d ' ')
    if [ "$UNPINNED" -gt 0 ]; then
        print_warning "$UNPINNED unpinned dependencies in requirements.txt"
        echo "  Unpinned packages can introduce vulnerabilities"
        echo "  Consider using: requirements-pinned.txt"
        grep -v "^#" requirements.txt | grep -v "^$" | grep -v "==" | grep -v "; sys_platform" | while read -r pkg; do
            echo "    - $pkg"
        done
    else
        print_ok "All dependencies are pinned"
    fi
else
    print_critical "requirements.txt not found"
fi
echo ""

# 2. Check for known vulnerable packages
echo "2. Checking for known vulnerable packages..."
VULNERABLE_PACKAGES=(
    "requests<2.32.0:CVE-2024-35195:Request smuggling vulnerability"
    "urllib3<2.2.2:CVE-2024-37891:Proxy-Authorization header leak"
    "pyyaml<5.4:CVE-2020-14343:Arbitrary code execution"
    "cryptography<42.0.0:CVE-2023-50782:Bleichenbacher timing oracle"
)

for vuln in "${VULNERABLE_PACKAGES[@]}"; do
    PKG=$(echo "$vuln" | cut -d':' -f1 | cut -d'<' -f1)
    CVE=$(echo "$vuln" | cut -d':' -f2)
    DESC=$(echo "$vuln" | cut -d':' -f3)
    MIN_VERSION=$(echo "$vuln" | cut -d':' -f1 | cut -d'<' -f2)

    if grep -q "^${PKG}" requirements.txt 2>/dev/null || grep -q "^${PKG}" requirements-pinned.txt 2>/dev/null; then
        VERSION=$(grep "^${PKG}" requirements-pinned.txt 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unpinned")
        if [ "$VERSION" != "unpinned" ]; then
            # Simple version comparison (works for x.y.z format)
            if [ "$(printf '%s\n' "$MIN_VERSION" "$VERSION" | sort -V | head -n1)" = "$MIN_VERSION" ] && [ "$VERSION" != "$MIN_VERSION" ]; then
                print_ok "$PKG==$VERSION (>= $MIN_VERSION, $CVE mitigated)"
            else
                print_critical "$PKG==$VERSION may be vulnerable to $CVE: $DESC"
            fi
        else
            print_warning "$PKG version unpinned - cannot verify $CVE status"
        fi
    fi
done
echo ""

# 3. Check Docker base image
echo "3. Checking Docker base image..."
if [ -f Dockerfile ]; then
    BASE_IMAGE=$(grep "^FROM" Dockerfile | head -1 | awk '{print $2}')
    print_info "Base image: $BASE_IMAGE"

    if echo "$BASE_IMAGE" | grep -q "python:3.11"; then
        print_ok "Using Python 3.11 (supported until 2027-10)"
    fi

    if echo "$BASE_IMAGE" | grep -q "slim"; then
        print_ok "Using slim image (reduced attack surface)"
    fi

    if echo "$BASE_IMAGE" | grep -q "bookworm"; then
        print_ok "Using Debian Bookworm (latest stable)"
    fi
fi
echo ""

# 4. Check file permissions in Docker
echo "4. Checking Docker security settings..."
if [ -f Dockerfile ]; then
    if grep -q "chmod 777" Dockerfile; then
        print_warning "Found 'chmod 777' in Dockerfile - overly permissive"
        grep -n "chmod 777" Dockerfile
    else
        print_ok "No overly permissive file permissions found"
    fi

    if grep -q "USER" Dockerfile; then
        print_ok "Non-root user configured"
    else
        print_warning "Container runs as root (acceptable for development, not production)"
    fi
fi
echo ""

# 5. Check .env for sensitive data
echo "5. Checking for exposed secrets..."
if [ -f .env ]; then
    print_warning ".env file exists - ensure it's in .gitignore"

    # Check for common secret patterns
    if grep -iE "(password|secret|key|token)=" .env | grep -v "^#" | grep -qv "YOUR_"; then
        print_warning "Potential secrets found in .env:"
        grep -iE "(password|secret|key|token)=" .env | grep -v "^#" | grep -v "YOUR_" | sed 's/=.*/=***REDACTED***/'
    else
        print_ok "No obvious secrets in .env"
    fi
fi

if [ -f .gitignore ]; then
    if grep -q "^.env$" .gitignore; then
        print_ok ".env is in .gitignore"
    else
        print_critical ".env is NOT in .gitignore - secrets could leak!"
    fi
else
    print_warning ".gitignore not found"
fi
echo ""

# 6. Check for hardcoded secrets in code
echo "6. Scanning code for hardcoded secrets..."
SECRET_PATTERNS=(
    "password.*=.*['\"]"
    "api[_-]?key.*=.*['\"]"
    "secret.*=.*['\"]"
    "token.*=.*['\"]"
)

FOUND_SECRETS=0
for pattern in "${SECRET_PATTERNS[@]}"; do
    if grep -riE "$pattern" *.py 2>/dev/null | grep -v "getenv" | grep -v "config" | grep -qv "#"; then
        ((FOUND_SECRETS++))
    fi
done

if [ $FOUND_SECRETS -eq 0 ]; then
    print_ok "No hardcoded secrets found in Python files"
else
    print_warning "Potential hardcoded secrets found - review code manually"
fi
echo ""

# 7. Check network exposure
echo "7. Checking network exposure..."
if [ -f docker-compose.yml ]; then
    EXPOSED_PORTS=$(grep "ports:" docker-compose.yml -A 2 | grep -oE "[0-9]+:[0-9]+" | cut -d':' -f1 | sort -u)
    if [ -n "$EXPOSED_PORTS" ]; then
        print_info "Exposed ports:"
        echo "$EXPOSED_PORTS" | while read -r port; do
            echo "  - $port"
        done
        print_warning "Ensure firewall rules are configured appropriately"
    else
        print_ok "No ports directly exposed (using host.docker.internal)"
    fi
fi
echo ""

# Summary
echo -e "${BLUE}=== Security Summary ===${NC}"
echo ""

if [ $CRITICAL -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ No security issues found${NC}"
    echo "Good security posture for development"
    exit 0
elif [ $CRITICAL -gt 0 ]; then
    echo -e "${RED}✗ $CRITICAL CRITICAL issue(s) found${NC}"
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo ""
    echo "Address CRITICAL issues before deploying"
    exit 1
else
    echo -e "${GREEN}✓ No critical issues${NC}"
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo "Review warnings and address as needed"
    exit 0
fi
