# Testing & Verification Scripts

This directory contains scripts to verify prerequisites, test container builds, and check security before deployment.

## Quick Start

Run all checks with one command:

```bash
./scripts/run-all-checks.sh
```

This runs all verification steps in the correct order and provides a comprehensive report.

## Individual Scripts

### 1. Security Check
**File:** `security-check.sh`

Checks for security vulnerabilities and misconfigurations:
- Unpinned dependencies
- Known CVEs in packages
- Docker security settings
- Exposed secrets
- File permissions
- Network exposure

```bash
./scripts/security-check.sh
```

**Exit codes:**
- `0` - No critical issues
- `1` - Critical issues found (must fix before deploy)

### 2. Prerequisites Verification
**File:** `verify-prerequisites.sh`

Verifies Docker environment and system requirements:
- Docker & Docker Compose versions
- System resources (CPU, memory, disk)
- File sharing configuration (macOS)
- Ollama installation and connectivity
- Configuration files

```bash
./scripts/verify-prerequisites.sh
```

**Requirements:**
- Docker >= 20.10
- Docker Compose V2
- 2+ CPUs, 4GB+ RAM
- Ollama running on host

### 3. Container Build & Tests
**File:** `test-container.sh`

Tests Docker container build and validates functionality:
- docker-compose.yml validation
- Container build (5-10 minutes)
- Python dependency imports
- Configuration loading
- File permissions
- Ollama connectivity
- Security checks

```bash
./scripts/test-container.sh
```

**Note:** This script takes 5-10 minutes due to building llama-cpp-python.

## Workflow

### First-Time Setup

```bash
# 1. Run all checks
./scripts/run-all-checks.sh

# 2. If checks pass, start services
docker compose up

# 3. Or open in DevContainer
code .
```

### Before Each Deployment

```bash
# Security check
./scripts/security-check.sh

# Full validation
./scripts/run-all-checks.sh
```

### Troubleshooting Build Failures

```bash
# Check prerequisites first
./scripts/verify-prerequisites.sh

# Run build test with detailed output
./scripts/test-container.sh

# Check build logs
docker compose build researcher 2>&1 | tee build.log
```

## Common Issues

### macOS File Sharing
If you get "operation not permitted" errors:
1. Open Docker Desktop
2. Settings → Resources → File Sharing
3. Add your project directory
4. Restart Docker Desktop

### Ollama Connectivity
If container can't reach Ollama:
1. Verify Ollama is running: `ollama serve`
2. Test from host: `curl http://localhost:11434/api/tags`
3. Check `OLLAMA_BASE_URL` in `.env` is set to `http://host.docker.internal:11434`

### Build Timeout
If llama-cpp-python build times out:
1. Increase Docker Desktop memory (Settings → Resources)
2. Close other applications
3. Retry build: `docker compose build --no-cache researcher`

## Security Best Practices

1. **Always run security-check.sh** before committing code
2. **Never commit .env** file (it's in .gitignore)
3. **Use requirements-pinned.txt** for production to avoid supply chain attacks
4. **Review CVE warnings** and update vulnerable packages
5. **Limit exposed ports** - only expose what's necessary

## Version Pinning

For production deployments, use pinned requirements:

```bash
# Copy pinned requirements
cp requirements-pinned.txt requirements.txt

# Rebuild with pinned versions
docker compose build --no-cache
```

See `requirements-pinned.txt` for security-vetted versions.

## Additional Tools

### Docker Built-in Diagnostics

```bash
# Validate compose file
docker compose config

# Check system info
docker info

# Check resource usage
docker stats
```

### Docker Desktop GUI
- Use Docker Desktop's built-in diagnostics (top-right menu)
- View container logs in GUI
- Monitor resource usage

## Exit Codes

All scripts use consistent exit codes:
- `0` - Success, all checks passed
- `1` - Failure, issues found

## Contributing

When adding new verification checks:
1. Add to appropriate script (security, prerequisites, or container tests)
2. Follow existing output format (colored, clear messages)
3. Use appropriate exit codes
4. Update this README

## References

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [Python Security Advisories](https://github.com/pypa/advisory-database)
