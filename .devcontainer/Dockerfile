# Development Container Dockerfile
FROM python:3.11-slim-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    ncurses-term \
    vim \
    nano \
    sudo \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Create workspace directory with proper permissions
RUN mkdir -p /workspace && chown -R $USERNAME:$USERNAME /workspace

# Switch to non-root user
USER $USERNAME
WORKDIR /workspace

# Set up PATH for user-installed packages
ENV PATH="/home/vscode/.local/bin:$PATH"

# Pre-install pip tools
RUN pip install --user --no-cache-dir --upgrade pip setuptools wheel

CMD ["/bin/bash"]
