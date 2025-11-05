# Diagnostic System Documentation

## 🎯 Overview

A modular, DRY (Don't Repeat Yourself), self-diagnosing troubleshooting system that follows least-privilege principles.

### Design Principles

1. **Modular**: Pluggable checks, easy to extend
2. **DRY**: Single source of truth, no code duplication
3. **Config-Driven**: All checks defined in YAML
4. **Least Privilege**: Read-only operations, no sudo
5. **Self-Diagnosing**: Automatically detects issues
6. **Platform-Aware**: Adapts to macOS, Linux, Windows

## 📁 Architecture

```
scripts/
├── diagnose.sh                  # Main entry point (orchestrator)
├── lib/                         # Reusable libraries (DRY)
│   ├── core.sh                  # Foundation utilities
│   ├── check-engine.sh          # Generic check executor
│   └── report-builder.sh        # Multi-format reporter
└── diagnostics/
    ├── rules.yaml               # All check definitions
    └── platform/
        ├── macos.yaml           # macOS-specific checks
        └── linux.yaml           # Linux-specific checks
```

## 🚀 Quick Start

```bash
# Run diagnostics
./scripts/diagnose.sh

# Generate JSON report
./scripts/diagnose.sh json

# Generate Markdown report
./scripts/diagnose.sh markdown > report.md

# Debug mode
DEBUG=1 ./scripts/diagnose.sh
```

## 🔧 How It Works

### 1. Modular Libraries (DRY Foundation)

**core.sh** - Foundation utilities:
- Logging (colored output)
- Platform detection
- File operations
- YAML parsing
- Command availability checking
- Timer utilities
- Validation functions

**check-engine.sh** - Generic check types:
- `command` - Execute and validate command output
- `file_exists` - Check file presence
- `url_reachable` - Test URL connectivity
- `port_available` - Check port status
- `env_var` - Validate environment variables

**report-builder.sh** - Output formatters:
- Console (colored, human-readable)
- JSON (machine-readable, CI/CD)
- Markdown (documentation)
- Fix suggestions

### 2. Configuration-Driven Checks

All checks are defined in `diagnostics/rules.yaml`:

```yaml
checks:
  - name: docker-running
    description: Check if Docker daemon is running
    type: command              # Check type
    platforms: all             # all | macos | linux | windows
    severity: critical         # critical | warning | info
    parameters:
      command: "docker info"
      expect: "Server Version"
      timeout: 10
```

### 3. Platform-Specific Checks

Platform-specific checks in separate YAML files:
- `platform/macos.yaml` - macOS Docker Desktop checks
- `platform/linux.yaml` - systemd service checks

## 📊 Check Types

### Command Check
```yaml
- name: my-check
  type: command
  parameters:
    command: "docker --version"
    expect: "Docker version"
    timeout: 5
```

### File Exists Check
```yaml
- name: env-file
  type: file_exists
  parameters:
    filepath: "${PROJECT_ROOT}/.env"
```

### URL Reachable Check
```yaml
- name: ollama-api
  type: url_reachable
  parameters:
    url: "${OLLAMA_BASE_URL}/api/version"
    timeout: 5
```

### Port Available Check
```yaml
- name: litellm-port
  type: port_available
  parameters:
    port: 4000
```

### Environment Variable Check
```yaml
- name: llm-provider
  type: env_var
  parameters:
    var_name: "LLM_PROVIDER"
    expected_value: "ollama"  # Optional
```

## 🎨 Output Formats

### Console (Default)
```bash
./scripts/diagnose.sh

━━━ AI Researcher Diagnostics ━━━
[✓] docker-installed
[✓] docker-running
[⚠] env-file-exists
     File not found: /path/to/.env
[✓] ollama-reachable

━━━ Summary ━━━
Total checks: 10
Passed: 8
Failed: 0
Warnings: 2
```

### JSON (CI/CD)
```bash
./scripts/diagnose.sh json
```
```json
{
  "timestamp": "2025-01-05T10:30:00Z",
  "platform": "macos",
  "checks": [
    {
      "name": "docker-running",
      "status": "PASS",
      "message": "Check passed",
      "severity": "critical",
      "elapsed_ms": 123
    }
  ]
}
```

### Markdown (Documentation)
```bash
./scripts/diagnose.sh markdown > report.md
```

## 🔍 Adding New Checks

### 1. Add to rules.yaml
```yaml
checks:
  - name: my-new-check
    description: What this checks
    type: command
    platforms: all
    severity: warning
    parameters:
      command: "my-command"
      expect: "expected output"
      timeout: 10
```

### 2. Add Fix Suggestions
```yaml
fixes:
  my-new-check:
    - "Step 1 to fix"
    - "Step 2 to fix"
```

That's it! No code changes needed.

## 🛠️ Extending

### Adding a New Check Type

Edit `scripts/lib/check-engine.sh`:

```bash
check_my_type() {
    local name="$1"
    local param1="$2"
    local severity="${3:-info}"

    # Implement your check logic
    if [[ check passes ]]; then
        add_result "$name" "PASS" "Success message" "$severity" "$elapsed"
        return 0
    else
        add_result "$name" "FAIL" "Failure message" "$severity" "$elapsed"
        return 1
    fi
}

# Add to dispatcher
execute_check() {
    case "$check_type" in
        # ...existing types...
        my_type)
            check_my_type "$@"
            ;;
    esac
}
```

## 📈 Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | General error |
| 2 | Missing dependencies |
| 3 | Configuration error |
| 10 | One or more critical checks failed |

## 🔒 Security & Least Privilege

### Allowed Operations (Read-Only)
- ✅ `docker info` - Read Docker state
- ✅ `docker ps` - List containers
- ✅ `curl` - Test connectivity
- ✅ `test -f` - Check file existence
- ✅ `grep` - Read configuration
- ✅ `ls` - List files

### Prohibited Operations
- ❌ `docker restart` - Modifies state
- ❌ `sudo anything` - Privilege escalation
- ❌ `rm/mv/cp` - File modifications
- ❌ Writing to `.env` - Config changes
- ❌ `apt install` - System changes

### Principle
```
Diagnose → Report → Suggest → User Decides
   ↓         ↓         ↓
 Read     Display    Guide
 Only     Results    Human
```

## 🧪 Testing

```bash
# Test with debug output
DEBUG=1 ./scripts/diagnose.sh

# Test specific format
./scripts/diagnose.sh json | jq .

# Test in Docker
docker run --rm -v $(pwd):/work -w /work alpine sh -c "
  apk add bash curl &&
  ./scripts/diagnose.sh
"
```

## 📝 Examples

### Example 1: Pre-Flight Check
```bash
#!/bin/bash
# run-before-docker.sh

if ! ./scripts/diagnose.sh json | jq -e '.checks[] | select(.status=="FAIL" and .severity=="critical")' > /dev/null; then
    echo "✓ Pre-flight checks passed"
    docker-compose up
else
    echo "✗ Critical issues found - fix before starting"
    ./scripts/diagnose.sh  # Show detailed report
    exit 1
fi
```

### Example 2: CI/CD Integration
```yaml
# .github/workflows/test.yml
- name: Run Diagnostics
  run: |
    ./scripts/diagnose.sh json > diagnostics.json

- name: Check Results
  run: |
    if jq -e '.checks[] | select(.status=="FAIL" and .severity=="critical")' diagnostics.json; then
      echo "Critical diagnostic failures"
      exit 1
    fi
```

### Example 3: Custom Check Suite
```bash
# Create custom rules
cat > custom-checks.yaml <<EOF
checks:
  - name: my-app-running
    type: command
    parameters:
      command: "pgrep myapp"
EOF

# Run with custom rules
RULES_FILE=custom-checks.yaml ./scripts/diagnose.sh
```

## 🤝 Contributing

To add a new check:
1. Edit `diagnostics/rules.yaml`
2. Add check definition
3. Add fix suggestions
4. Test with `./scripts/diagnose.sh`
5. Submit PR

No code changes needed for most checks!

## 📚 Further Reading

- [YAML Check Reference](./diagnostics/rules.yaml)
- [Platform Checks](./diagnostics/platform/)
- [Core Library API](./lib/core.sh)
- [Check Engine API](./lib/check-engine.sh)

## 🐛 Troubleshooting

**Issue**: "command not found: yq"
**Solution**: Basic YAML parsing works without yq. For advanced features, install yq:
```bash
brew install yq  # macOS
sudo apt install yq  # Ubuntu
```

**Issue**: Colors not showing
**Solution**: Ensure you're in a terminal (not piping to file):
```bash
./scripts/diagnose.sh  # Colors
./scripts/diagnose.sh > report.txt  # No colors (automatic)
```

**Issue**: Check times out
**Solution**: Increase timeout in rules.yaml:
```yaml
parameters:
  timeout: 30  # Increase from default 10
```
