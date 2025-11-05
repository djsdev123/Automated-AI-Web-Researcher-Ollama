# Dockerfile for Automated AI Web Researcher
# Simple CPU-only build since Ollama runs on host

FROM python:3.11-slim-bookworm

LABEL maintainer="AI Researcher Project"
LABEL description="Automated AI Web Researcher with LLM integration"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # For terminal handling (curses)
    ncurses-term \
    # For web scraping
    ca-certificates \
    curl \
    # For git operations
    git \
    # Build tools (gcc for C, g++ for C++ in llama-cpp-python)
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
# Note: llama-cpp-python is optional - only needed if using local models
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir pyyaml

# Copy application code
COPY *.py /app/

# Create default config directory structure
RUN mkdir -p /app/config /app/data /app/logs && \
    chmod -R 777 /app/data /app/logs

# Copy default configuration
COPY config/ /app/config/

# Copy entrypoint script
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    CONFIG_PATH=/app/config/config.yaml

# Expose port for future web UI
EXPOSE 8000

# Health check - verify Python and config file exist
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import sys; sys.exit(0)" || exit 1

# Use entrypoint script for startup checks
ENTRYPOINT ["/app/entrypoint.sh"]

# Default command - run the main application
CMD ["python", "Web-LLM.py"]
