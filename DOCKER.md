# Docker Setup Guide

Complete guide for running Automated AI Web Researcher in Docker.

## Table of Contents
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Running with Different LLM Providers](#running-with-different-llm-providers)
- [Using LiteLLM Web UI](#using-litellm-web-ui)
- [Development Container](#development-container)
- [Volumes and Data Persistence](#volumes-and-data-persistence)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### 1. Install Prerequisites
- Docker Desktop (Windows/Mac) or Docker Engine (Linux)
- Ollama running on your host machine (for local LLM)

### 2. Set Up Configuration
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your settings
nano .env
```

### 3. Start the Services
```bash
# Build and start in interactive mode
docker-compose up --build

# Or run in background
docker-compose up -d
```

### 4. Access the Application
```bash
# Attach to running container
docker attach ai-researcher

# Or execute new session
docker exec -it ai-researcher python Web-LLM.py
```

---

## Prerequisites

### Docker Installation

**Windows/Mac:**
```bash
# Download and install Docker Desktop
# https://www.docker.com/products/docker-desktop
```

**Linux (Ubuntu/Debian):**
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo apt-get install docker-compose-plugin
```

### Ollama Setup (for Local LLM)

```bash
# Install Ollama on your HOST machine
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama server
ollama serve

# Pull recommended model
ollama pull phi3:3.8b-mini-128k-instruct

# Verify it's running
curl http://localhost:11434/api/version
```

---

## Configuration

### Environment Variables

Create `.env` file from template:

```bash
cp .env.example .env
```

**Key variables to set:**

```env
# LLM Provider Selection
LLM_PROVIDER=ollama  # or openai, anthropic

# Ollama (if using local LLM)
OLLAMA_BASE_URL=http://host.docker.internal:11434
OLLAMA_MODEL=phi3:3.8b-mini-128k-instruct

# OpenAI (if using cloud API)
OPENAI_API_KEY=sk-proj-xxxxx
OPENAI_MODEL=gpt-4o-mini

# Anthropic (if using cloud API)
ANTHROPIC_API_KEY=sk-ant-xxxxx
ANTHROPIC_MODEL=claude-3-5-haiku-latest
```

### Configuration File

Advanced settings in `config/config.yaml`:

```yaml
# Edit this file to customize:
# - Research settings
# - Web scraping parameters
# - UI preferences
# - Logging levels
```

---

## Running with Different LLM Providers

### Option 1: Ollama (Local - Recommended)

**Advantages:** Free, private, no API costs
**Requirements:** Ollama running on host

```bash
# 1. Start Ollama on host
ollama serve

# 2. Pull your model
ollama pull phi3:3.8b-mini-128k-instruct

# 3. Configure .env
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://host.docker.internal:11434
OLLAMA_MODEL=phi3:3.8b-mini-128k-instruct

# 4. Start container
docker-compose up
```

**Verifying Ollama Connection:**
```bash
# From inside container
docker exec -it ai-researcher curl http://host.docker.internal:11434/api/version
```

### Option 2: OpenAI API

**Advantages:** Powerful models, reliable
**Disadvantages:** Costs money per API call

⚠️ **WARNING:** This application makes MANY API calls during research. Monitor your usage carefully!

```bash
# 1. Get API key from https://platform.openai.com/api-keys

# 2. Configure .env
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-proj-xxxxx
OPENAI_MODEL=gpt-4o-mini  # Use mini for cost efficiency

# 3. Start container
docker-compose up
```

**Cost Estimation:**
- Single research session: 50-200+ API calls
- Using GPT-4: ~$0.50-$5.00 per session
- Using GPT-4o-mini: ~$0.05-$0.50 per session

### Option 3: Anthropic Claude

**Advantages:** High-quality outputs, large context
**Disadvantages:** Costs money per API call

```bash
# 1. Get API key from https://console.anthropic.com/

# 2. Configure .env
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-xxxxx
ANTHROPIC_MODEL=claude-3-5-haiku-latest  # Use haiku for cost efficiency

# 3. Start container
docker-compose up
```

---

## Using LiteLLM Web UI

LiteLLM provides a web interface for interacting with your LLMs.

### Starting LiteLLM

```bash
# Start both researcher and LiteLLM
docker-compose up

# Access web UI
open http://localhost:4000
```

### LiteLLM Features

1. **Unified API**: Use same API for all LLM providers
2. **Model Switching**: Easily switch between models
3. **Usage Tracking**: Monitor API calls and costs
4. **Playground**: Test prompts before using in research

### Configuration

Edit `config/litellm-config.yaml` to:
- Add/remove models
- Configure fallbacks
- Set rate limits
- Customize routing

### Using LiteLLM API

```bash
# Example: Call via OpenAI-compatible API
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## Development Container

### VS Code DevContainers

For the best development experience:

```bash
# 1. Install VS Code + Remote Containers extension
# 2. Open project in VS Code
# 3. Press F1 > "Remote-Containers: Reopen in Container"
```

**Included features:**
- Python development tools
- Linting and formatting (Black, Ruff)
- Testing framework (pytest)
- Git integration
- Docker-in-Docker support

### Manual Development Setup

```bash
# Build dev container
docker-compose -f .devcontainer/docker-compose.dev.yml up -d

# Attach to container
docker exec -it ai-researcher-dev bash

# Install dependencies
pip install -r requirements.txt -r requirements-dev.txt

# Run tests
pytest

# Format code
black .
ruff check .
```

---

## Volumes and Data Persistence

### Volume Mappings

```yaml
volumes:
  - ./data:/app/data      # Research session files
  - ./logs:/app/logs      # Application logs
  - ./config:/app/config  # Configuration files
```

### Managing Data

**View research sessions:**
```bash
# List all sessions
ls -lh data/research_session_*.txt

# Read latest session
cat data/research_session_$(ls data/ | grep research_session | wc -l).txt
```

**View logs:**
```bash
# Tail application logs
tail -f logs/web_llm.log

# View all logs
docker-compose logs -f researcher
```

**Backup data:**
```bash
# Create backup
tar -czf backup-$(date +%Y%m%d).tar.gz data/ logs/ config/

# Restore backup
tar -xzf backup-20240101.tar.gz
```

### Cleanup

```bash
# Remove old research sessions
rm data/research_session_*.txt

# Clean logs
rm logs/*.log

# Full cleanup (keep volumes)
docker-compose down

# Full cleanup (remove volumes)
docker-compose down -v
```

---

## Troubleshooting

### Cannot Connect to Ollama

**Symptom:** `Connection refused` or `Cannot reach Ollama`

**Solutions:**

1. **Check Ollama is running on host:**
```bash
curl http://localhost:11434/api/version
```

2. **Verify Docker network settings:**
```bash
# Test from inside container
docker exec -it ai-researcher curl http://host.docker.internal:11434/api/version
```

3. **Linux users - use host network:**
```yaml
# In docker-compose.yml, change to:
environment:
  - OLLAMA_BASE_URL=http://localhost:11434
network_mode: host
```

4. **Check firewall:**
```bash
# Allow Ollama port
sudo ufw allow 11434
```

### TTY/Terminal Issues

**Symptom:** `the input device is not a TTY` or broken terminal display

**Solutions:**

1. **Ensure stdin_open and tty are set:**
```yaml
# In docker-compose.yml
stdin_open: true
tty: true
```

2. **Run with proper flags:**
```bash
docker run -it ai-researcher
```

3. **For simple mode (no curses UI):**
```yaml
# In config/config.yaml
ui:
  input_mode: simple  # Instead of curses
```

### Model Not Found

**Symptom:** `Model 'xyz' not found in Ollama`

**Solution:**
```bash
# Pull the model on HOST machine
ollama pull phi3:3.8b-mini-128k-instruct

# Verify
ollama list
```

### Permission Denied on Volumes

**Symptom:** Cannot write to `/app/data` or `/app/logs`

**Solution:**
```bash
# Set proper permissions on host
chmod -R 777 data logs

# Or use specific UID/GID in Dockerfile
RUN chown -R 1000:1000 /app/data /app/logs
```

### Python Dependencies Failed

**Symptom:** `ModuleNotFoundError` or import errors

**Solution:**
```bash
# Rebuild with no cache
docker-compose build --no-cache

# Or install manually
docker exec -it ai-researcher pip install -r requirements.txt
```

### High Memory Usage

**Symptom:** Container crashes or system slows down

**Solution:**

1. **Set memory limits:**
```yaml
# In docker-compose.yml
deploy:
  resources:
    limits:
      memory: 8G
```

2. **Use smaller models:**
```env
OLLAMA_MODEL=phi3:3.8b-mini-128k-instruct  # Instead of 70B models
```

3. **Reduce context size:**
```yaml
# In config/config.yaml
llm:
  ollama:
    n_ctx: 32000  # Reduce from 55000
```

### LiteLLM Not Accessible

**Symptom:** Cannot access `http://localhost:4000`

**Solution:**

1. **Check service is running:**
```bash
docker-compose ps
docker-compose logs litellm
```

2. **Verify port mapping:**
```bash
docker ps | grep litellm
```

3. **Change port if conflict:**
```env
# In .env
LITELLM_PORT=8000  # Use different port
```

### API Rate Limiting

**Symptom:** `RateLimitError` or `429 Too Many Requests`

**Solution:**

1. **For DuckDuckGo:**
```yaml
# In config/config.yaml
research:
  search:
    retry_delay_base: 5  # Increase from 2
```

2. **For OpenAI/Anthropic:**
   - Upgrade to higher tier
   - Add delays between requests
   - Use batch processing

---

## Advanced Usage

### Custom Docker Build

```dockerfile
# Create custom Dockerfile
FROM python:3.11-slim-bookworm

# Add your customizations
RUN apt-get update && apt-get install -y my-package

# Copy and modify
COPY my-custom-config.yaml /app/config/config.yaml
```

### Multi-Container Setup

```yaml
# docker-compose.yml
services:
  researcher:
    # ... researcher config

  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama-data:/root/.ollama

  litellm:
    # ... litellm config

volumes:
  ollama-data:
```

### CI/CD Integration

```yaml
# .github/workflows/docker.yml
name: Build Docker Image

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build image
        run: docker build -t ai-researcher .
      - name: Run tests
        run: docker run ai-researcher pytest
```

---

## Support

- **Issues:** https://github.com/TheBlewish/Automated-AI-Web-Researcher-Ollama/issues
- **Discussions:** https://github.com/TheBlewish/Automated-AI-Web-Researcher-Ollama/discussions
- **Ollama Docs:** https://ollama.ai/docs
- **LiteLLM Docs:** https://docs.litellm.ai
