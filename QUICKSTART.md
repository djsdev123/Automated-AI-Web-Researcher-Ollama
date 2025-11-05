# Quick Start Guide

## 🎯 Single Source of Truth: `.env` File

**ALL configuration is done in ONE place: the `.env` file**

### Setup (3 steps)

```bash
# 1. Copy template
cp .env.example .env

# 2. Edit TWO lines in .env
nano .env
```

Change these two lines only:
```env
OLLAMA_BASE_URL=http://host.docker.internal:11434
OLLAMA_MODEL=phi3:3.8b-mini-128k-instruct
```

```bash
# 3. Start
docker-compose up
```

**That's it!** All other configs update automatically.

---

## 📝 What Gets Updated Automatically

When you edit `.env`, these update automatically:
- ✅ Docker Compose (both services)
- ✅ DevContainer
- ✅ config.yaml (via `${VAR}` interpolation)
- ✅ Python app (via config_loader.py)
- ✅ LiteLLM proxy

**No need to edit anything else!**

---

## 🔄 Common Changes

### Switch Ollama Model
```bash
# Edit .env - change ONE line:
OLLAMA_MODEL=llama3:8b

# Restart
docker-compose restart
```

### Use Remote Ollama
```bash
# Edit .env - change ONE line:
OLLAMA_BASE_URL=http://192.168.1.100:11434

# Restart
docker-compose restart
```

### Use OpenAI Instead
```bash
# Edit .env - change TWO lines:
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-proj-xxxxx

# Restart
docker-compose restart
```

---

## 🚫 Don't Edit These Files

You should NOT manually edit:
- ❌ `docker-compose.yml` - reads from `.env`
- ❌ `config/config.yaml` - uses `${VAR}` from `.env`
- ❌ `.devcontainer/devcontainer.json` - reads from `.env`
- ❌ `config/litellm-config.yaml` - reads from `.env`

**Only edit `.env`** - everything else updates automatically!

---

## 📚 Configuration Flow

```
┌─────────────┐
│  .env file  │ ← YOU EDIT THIS ONLY
└──────┬──────┘
       │
       ├──→ docker-compose.yml (auto-reads)
       ├──→ config.yaml (${VAR} interpolation)
       ├──→ devcontainer.json (--env-file flag)
       └──→ Python code (config_loader.py)
```

---

## 🆘 Troubleshooting

### "Can't connect to Ollama"
```bash
# Check .env has correct URL:
grep OLLAMA_BASE_URL .env

# Should show:
# OLLAMA_BASE_URL=http://host.docker.internal:11434
```

### "Model not found"
```bash
# Check .env has correct model:
grep OLLAMA_MODEL .env

# Pull model on HOST:
ollama pull phi3:3.8b-mini-128k-instruct
```

### "Changes not taking effect"
```bash
# Restart containers:
docker-compose down
docker-compose up

# Or rebuild:
docker-compose up --build
```

---

## 📖 Full Documentation

- **Docker Guide**: See [DOCKER.md](DOCKER.md)
- **All Settings**: See [CONFIGURATION.md](CONFIGURATION.md)
- **Main README**: See [README.md](README.md)
