# DevContainer Troubleshooting for macOS

## Common Error: "operation not permitted" on macOS

If you see:
```
invalid mount config for type "bind": stat /host_mnt/Users/...: operation not permitted
```

### Fix 1: Enable File Sharing in Docker Desktop (MOST COMMON)

1. Open **Docker Desktop**
2. Go to **Settings** (gear icon)
3. Click **Resources** → **File Sharing**
4. Ensure these paths are listed:
   - `/Users`
   - `/Volumes`
   - `/private`
   - `/tmp`

5. If `/Users` is missing:
   - Click **+** button
   - Add `/Users`
   - Click **Apply & Restart**

6. **Restart Docker Desktop** completely

7. Try opening DevContainer again

### Fix 2: Reset Docker Desktop

If File Sharing is already configured:

1. **Docker Desktop** → **Troubleshoot** (bug icon)
2. Click **Reset to factory defaults**
3. Click **Reset**
4. Wait for Docker to restart
5. Re-enable File Sharing (see Fix 1)
6. Try again

### Fix 3: Check Docker Desktop is Running

```bash
# Verify Docker is running
docker ps

# If error, start Docker Desktop app
open -a Docker
```

### Fix 4: Use Alternative - Docker Compose Directly

Instead of DevContainer, use Docker Compose:

```bash
# Navigate to project
cd /Users/ms/Documents/GitHub/Automated-AI-Web-Researcher-Ollama

# Copy .env
cp .env.example .env

# Start with Docker Compose
docker-compose up --build

# In another terminal, attach
docker exec -it ai-researcher bash
```

### Fix 5: Check macOS Security Settings

1. **System Settings** → **Privacy & Security**
2. Scroll to **Files and Folders**
3. Find **Docker** or **Docker Desktop**
4. Ensure it has access to:
   - Documents folder
   - Downloads folder
   - Removable Volumes

### Still Not Working?

Run diagnostics:

```bash
# Check Docker version
docker --version
docker-compose --version

# Check Docker info
docker info | grep "Operating System"

# Test a simple mount
docker run -v /Users:/test alpine ls /test
# Should list your home directory contents
```

If this test fails, Docker Desktop file sharing is definitely broken.

### Last Resort: Move Project

If nothing works, move project to a simpler path:

```bash
# Move to home directory
mv /Users/ms/Documents/GitHub/Automated-AI-Web-Researcher-Ollama ~/ai-researcher

cd ~/ai-researcher

# Try DevContainer again
```

Sometimes deeply nested paths cause issues on macOS.

## Why This Happens

Docker Desktop on macOS uses a Linux VM that needs explicit permission to access macOS file system. The `/host_mnt/` prefix in the error indicates Docker's VM can't access your files through normal macOS file sharing (osxfs).

This is a Docker Desktop limitation, not a DevContainer issue.
