# Configuration Guide

Complete reference for configuring the Automated AI Web Researcher.

## Table of Contents
- [Configuration Files](#configuration-files)
- [Environment Variables](#environment-variables)
- [LLM Provider Settings](#llm-provider-settings)
- [Research Engine Settings](#research-engine-settings)
- [UI and Display Settings](#ui-and-display-settings)
- [Migration from Legacy Config](#migration-from-legacy-config)

---

## Configuration Files

### Primary Configuration: `config/config.yaml`

The main configuration file with full control over all settings.

**Location:**
- Docker: `/app/config/config.yaml`
- Native: `./config/config.yaml`

**Loading Priority:**
1. Environment variables (highest)
2. `config/config.yaml`
3. Legacy `llm_config.py` (fallback)

### Environment Configuration: `.env`

Stores secrets and environment-specific overrides.

**Location:** Project root `.env` file

**Best Practices:**
- Never commit `.env` to version control
- Use `.env.example` as template
- Store sensitive data (API keys) here

---

## Environment Variables

### LLM Provider Selection

```env
# Which LLM provider to use
LLM_PROVIDER=ollama  # Options: ollama, openai, anthropic
```

### Ollama Settings

```env
# Base URL for Ollama server
OLLAMA_BASE_URL=http://localhost:11434

# Docker: Use host.docker.internal to reach host
# OLLAMA_BASE_URL=http://host.docker.internal:11434

# Model name (must be pulled first: ollama pull <model>)
OLLAMA_MODEL=phi3:3.8b-mini-128k-instruct
```

**Available Models:**
- `phi3:3.8b-mini-128k-instruct` - Recommended, fast, good context
- `phi3:14b-medium-128k-instruct` - Better quality, slower
- `llama3:8b` - Meta's Llama 3, general purpose
- `llama3:70b` - Highest quality, requires lots of RAM
- `mistral:7b` - Mistral AI, balanced
- `mixtral:8x7b` - Mixture of experts, versatile

### OpenAI Settings

```env
# Get from: https://platform.openai.com/api-keys
OPENAI_API_KEY=sk-proj-xxxxx

# Optional: Custom endpoint (for proxies or compatible services)
OPENAI_BASE_URL=

# Model selection
OPENAI_MODEL=gpt-4o-mini  # Options: gpt-4o, gpt-4o-mini, gpt-4-turbo
```

**Cost Considerations:**
- `gpt-4o-mini`: ~$0.05-0.50 per research session
- `gpt-4o`: ~$0.50-5.00 per research session
- Research makes 50-200+ API calls per session

### Anthropic Settings

```env
# Get from: https://console.anthropic.com/
ANTHROPIC_API_KEY=sk-ant-xxxxx

# Model selection
ANTHROPIC_MODEL=claude-3-5-haiku-latest  # Options: haiku, sonnet, opus
```

**Models:**
- `claude-3-5-haiku-latest`: Fastest, cheapest
- `claude-3-5-sonnet-latest`: Balanced (recommended)
- `claude-3-opus-latest`: Highest quality, most expensive

### Application Settings

```env
# Logging level
LOG_LEVEL=INFO  # Options: DEBUG, INFO, WARNING, ERROR, CRITICAL

# Directory paths (usually don't need to change)
LOG_DIR=/app/logs
DATA_DIR=/app/data
CONFIG_PATH=/app/config/config.yaml
```

### LiteLLM Settings

```env
# Web UI port
LITELLM_PORT=4000

# API authentication key
LITELLM_MASTER_KEY=sk-1234  # Change in production!
```

---

## LLM Provider Settings

### Ollama Configuration

**In `config/config.yaml`:**

```yaml
llm:
  provider: ollama

  ollama:
    base_url: "http://localhost:11434"
    model_name: "phi3:3.8b-mini-128k-instruct"

    # Generation parameters
    temperature: 0.7  # 0.0 = deterministic, 2.0 = very random
    top_p: 0.9        # Nucleus sampling threshold
    n_ctx: 55000      # Context window size (tokens)

    # Stop sequences (when to stop generating)
    stop_sequences:
      - "User:"
      - "\n\n"
```

**Parameter Tuning:**

| Parameter | Range | Effect |
|-----------|-------|--------|
| `temperature` | 0.0-2.0 | Higher = more creative/random |
| `top_p` | 0.0-1.0 | Lower = more focused responses |
| `n_ctx` | 2048-128000 | Context window (model dependent) |

**Recommended Settings:**
- **Research:** `temperature: 0.7`, `top_p: 0.9` (default)
- **Factual:** `temperature: 0.3`, `top_p: 0.8`
- **Creative:** `temperature: 1.0`, `top_p: 0.95`

### OpenAI Configuration

```yaml
llm:
  provider: openai

  openai:
    api_key: "${OPENAI_API_KEY}"  # From environment
    base_url: "${OPENAI_BASE_URL}"  # Optional
    model_name: "gpt-4o-mini"

    # Generation parameters
    temperature: 0.7
    top_p: 0.9
    max_tokens: 4096  # Maximum response length

    # Stop sequences
    stop_sequences:
      - "User:"
      - "\n\n"

    # Penalty parameters (reduce repetition)
    presence_penalty: 0   # -2.0 to 2.0
    frequency_penalty: 0  # -2.0 to 2.0
```

**Penalty Parameters:**
- `presence_penalty`: Penalize tokens that appear at all
- `frequency_penalty`: Penalize tokens based on frequency
- Use small values (0.1-0.5) to reduce repetition

### Anthropic Configuration

```yaml
llm:
  provider: anthropic

  anthropic:
    api_key: "${ANTHROPIC_API_KEY}"
    model_name: "claude-3-5-haiku-latest"

    # Generation parameters
    temperature: 0.7
    top_p: 0.9
    max_tokens: 4096

    stop_sequences:
      - "User:"
      - "\n\n"
```

---

## Research Engine Settings

### General Research Settings

```yaml
research:
  # How many search queries per research cycle
  max_searches_per_cycle: 5  # 3-10 recommended

  # How many focus areas to investigate
  max_focus_areas: 5  # 3-7 recommended

  # Stop research when document reaches % of context limit
  document_size_limit_ratio: 0.9  # 0.8-0.95
```

**Tuning for Speed vs Depth:**
- **Fast:** `max_searches: 3`, `max_focus_areas: 3`
- **Balanced:** `max_searches: 5`, `max_focus_areas: 5` (default)
- **Thorough:** `max_searches: 10`, `max_focus_areas: 7`

### Search Configuration

```yaml
research:
  search:
    provider: "duckduckgo"  # Currently only option
    max_results: 10         # Search results to fetch
    pages_to_scrape: 2      # How many pages to analyze

    # Retry settings for rate limiting
    retry_attempts: 3
    retry_delay_base: 2  # Seconds (exponential backoff)

    # Time range options for searches
    time_range_options:
      - "d"    # Past day
      - "w"    # Past week
      - "m"    # Past month
      - "y"    # Past year
      - "none" # No time limit
```

**Search Tuning:**
- `max_results: 10`: Standard, good coverage
- `pages_to_scrape: 2`: Balance speed/depth
- Increase for more thorough research
- Decrease for faster iterations

### Web Scraping Configuration

```yaml
research:
  web_scraping:
    # Request timeout in seconds
    timeout: 30  # 10-60 seconds

    # Retry failed requests
    max_retries: 3

    # Minimum delay between requests (same domain)
    rate_limit: 1  # Seconds

    # User agent string
    user_agent: "AIResearcher/2.0 (+https://github.com/...)"

    # Respect robots.txt (currently hardcoded false)
    respect_robots_txt: false

    # Content extraction limits
    max_content_length: 2400  # Characters per page
    max_workers: 5            # Parallel scraping threads
```

**Scraping Best Practices:**
- `timeout: 30`: Good balance
- `rate_limit: 1`: Be respectful
- Increase `max_workers` for faster scraping (use caution)
- Lower `timeout` if sites are slow

### Session Management

```yaml
research:
  session:
    output_format: "txt"  # Future: json, markdown
    filename_pattern: "research_session_{number}.txt"
    auto_increment: true
```

**File Location:**
- Files saved to `data/` directory
- Numbered sequentially: `research_session_1.txt`, etc.
- Contains all retrieved content and sources

---

## UI and Display Settings

### Terminal UI Configuration

```yaml
ui:
  enable_colors: true  # ANSI color output

  # Color scheme
  color_scheme:
    thinking: "magenta"
    searching: "magenta"
    success: "green"
    warning: "yellow"
    error: "red"
    info: "cyan"

  # Input mode
  input_mode: "curses"  # Options: curses, simple

  # Progress indicators
  progress_indicators:
    enabled: true
    spinner_chars: ["|", "/", "-", "\\"]
    update_interval: 0.2  # Seconds
```

**Input Modes:**

| Mode | Description | Use When |
|------|-------------|----------|
| `curses` | Split-screen UI | Interactive terminal |
| `simple` | Basic I/O | Non-TTY, scripting |

### Curses-Specific Settings

```yaml
ui:
  curses:
    enable_mouse: false  # Mouse support (experimental)
    enable_scroll: true  # Scrolling in output window
    status_line_height: 1
    input_area_height: 3
```

**Troubleshooting:**
- If terminal corrupted: Set `input_mode: simple`
- If CTRL+D not working: Check TTY allocation
- Garbled output: Disable colors with `enable_colors: false`

---

## Logging Configuration

### File Logging

```yaml
logging:
  file:
    enabled: true
    level: "INFO"  # DEBUG, INFO, WARNING, ERROR, CRITICAL
    format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    max_bytes: 10485760  # 10MB
    backup_count: 5      # Keep 5 rotated logs
```

**Log Files:**
- `logs/web_llm.log`: Main application
- `logs/research_llm.log`: Research manager
- `logs/llama_output.log`: LLM interactions

### Console Logging

```yaml
logging:
  console:
    enabled: false  # Usually disabled (conflicts with curses)
    level: "WARNING"
```

**Note:** Console logging disabled by default to avoid interfering with curses UI.

### Module-Specific Levels

```yaml
logging:
  modules:
    llm_wrapper: "INFO"
    research_manager: "INFO"
    web_scraper: "WARNING"
    duckduckgo_search: "WARNING"
    requests: "WARNING"
    urllib3: "WARNING"
```

**Debugging:**
Set specific module to `DEBUG` for detailed logs:

```yaml
modules:
  llm_wrapper: "DEBUG"  # See all LLM interactions
```

---

## Feature Flags

Enable/disable features:

```yaml
features:
  conversation_mode: true      # Q&A after research
  pause_and_assess: true       # Pause command
  auto_summarization: true     # Generate summaries

  # Future features (not implemented yet)
  web_ui: false
  api_server: false
  multi_language: false
  export_formats: ["txt"]
```

---

## Performance Settings

```yaml
performance:
  # Async/threading
  enable_async_search: true
  max_concurrent_scrapes: 5

  # Caching (future)
  enable_cache: false
  cache_ttl: 3600  # Seconds
```

**Tuning:**
- `max_concurrent_scrapes`: 3-10 depending on system
- Higher values = faster but more resource usage

---

## Migration from Legacy Config

### Automatic Migration

The config loader automatically detects and migrates `llm_config.py`:

```python
# Old way (llm_config.py)
LLM_TYPE = "ollama"
LLM_CONFIG_OLLAMA = {
    "llm_type": "ollama",
    "base_url": "http://localhost:11434",
    "model_name": "phi3",
    ...
}

# New way (config/config.yaml)
llm:
  provider: ollama
  ollama:
    base_url: "http://localhost:11434"
    model_name: "phi3"
    ...
```

### Manual Migration Steps

1. **Copy your settings:**
```bash
# Backup old config
cp llm_config.py llm_config.py.backup

# Start with template
cp config/config.yaml.example config/config.yaml
```

2. **Transfer LLM settings:**
   - `LLM_TYPE` → `llm.provider`
   - `LLM_CONFIG_OLLAMA` → `llm.ollama`
   - `base_url` → `base_url` (same)
   - `model_name` → `model_name` (same)

3. **Use environment variables for secrets:**
```yaml
# Instead of hardcoded:
api_key: "sk-xxxxx"

# Use environment variable:
api_key: "${OPENAI_API_KEY}"
```

4. **Test the migration:**
```bash
python -m config_loader  # Validates config
```

### Backward Compatibility

The system maintains backward compatibility:

```python
# This still works:
from llm_config import get_llm_config

# But new code should use:
from config_loader import get_llm_config
```

---

## Configuration Validation

### Using Python

```python
from config_loader import ConfigLoader

loader = ConfigLoader()
config = loader.load()

# Check if valid
print(f"Config loaded: {config['app']['name']}")
print(f"Provider: {config['llm']['provider']}")
```

### Using YAML Linter

```bash
# Install yamllint
pip install yamllint

# Validate syntax
yamllint config/config.yaml

# Or use Python
python -c "import yaml; yaml.safe_load(open('config/config.yaml'))"
```

---

## Examples

### Example 1: Cost-Effective OpenAI Setup

```yaml
llm:
  provider: openai
  openai:
    model_name: "gpt-4o-mini"  # Cheapest option
    max_tokens: 2048            # Limit response size

research:
  max_searches_per_cycle: 3     # Reduce API calls
  max_focus_areas: 3
  search:
    pages_to_scrape: 1          # Scrape fewer pages
```

### Example 2: High-Quality Ollama Setup

```yaml
llm:
  provider: ollama
  ollama:
    model_name: "llama3:70b"    # Highest quality
    n_ctx: 128000               # Maximum context
    temperature: 0.5            # More factual

research:
  max_searches_per_cycle: 10    # Thorough research
  max_focus_areas: 7
  search:
    max_results: 15
    pages_to_scrape: 3
```

### Example 3: Fast Research Setup

```yaml
research:
  max_searches_per_cycle: 2
  max_focus_areas: 3
  search:
    max_results: 5
    pages_to_scrape: 1
  web_scraping:
    timeout: 10
    max_workers: 10  # Parallel scraping
```

---

## Troubleshooting Configuration

### Config Not Loading

```bash
# Check file exists
ls -l config/config.yaml

# Validate YAML syntax
python -c "import yaml; print(yaml.safe_load(open('config/config.yaml')))"

# Check environment variable
echo $CONFIG_PATH
```

### Environment Variables Not Substituting

```yaml
# ✗ Wrong:
base_url: $OLLAMA_BASE_URL

# ✓ Correct:
base_url: "${OLLAMA_BASE_URL}"

# ✓ With default:
base_url: "${OLLAMA_BASE_URL:-http://localhost:11434}"
```

### API Keys Not Working

```bash
# Verify they're set
echo $OPENAI_API_KEY
echo $ANTHROPIC_API_KEY

# Check in container
docker exec ai-researcher env | grep API_KEY

# Reload .env
docker-compose down
docker-compose up
```

---

## Support

For configuration help:
- Check `DOCKER.md` for deployment issues
- See `README.md` for general usage
- Open an issue: https://github.com/TheBlewish/Automated-AI-Web-Researcher-Ollama/issues
