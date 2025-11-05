# Development Container for AI Researcher
# Includes all development tools and dependencies

FROM python:3.11-bookworm

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Build tools
    build-essential \
    cmake \
    git \
    curl \
    wget \
    # Terminal utilities
    ncurses-term \
    fish \
    zsh \
    tmux \
    vim \
    nano \
    # Network tools
    iputils-ping \
    net-tools \
    dnsutils \
    # Development tools
    sudo \
    ca-certificates \
    # For web scraping
    libxml2-dev \
    libxslt1-dev \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Switch to non-root user
USER $USERNAME

# Set up Python development tools (user-level)
RUN pip install --user --upgrade pip setuptools wheel

# Install development dependencies
RUN pip install --user \
    # Code quality
    black \
    ruff \
    mypy \
    pylint \
    isort \
    # Testing
    pytest \
    pytest-cov \
    pytest-mock \
    pytest-asyncio \
    # Development utilities
    ipython \
    ipdb \
    rich \
    # Configuration
    pyyaml \
    python-dotenv \
    # Documentation
    mkdocs \
    mkdocs-material

# Set up shell configuration
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc \
    && echo 'alias ll="ls -alF"' >> ~/.bashrc \
    && echo 'alias la="ls -A"' >> ~/.bashrc \
    && echo 'alias l="ls -CF"' >> ~/.bashrc

# Configure git
RUN git config --global core.autocrlf input \
    && git config --global init.defaultBranch main

# Set working directory
WORKDIR /workspace

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog

# Set up entrypoint
ENTRYPOINT ["/bin/bash"]
