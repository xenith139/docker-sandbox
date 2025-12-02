FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Set terminal environment for proper colors and formatting
ENV TERM=xterm-256color

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    software-properties-common \
    tmux \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.13 from deadsnakes PPA
RUN apt-get update && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && \
    apt-get install -y \
    python3.13 \
    python3.13-venv \
    python3.13-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip for Python 3.13 (pip needs setuptools, not distutils in Python 3.13+)
RUN python3.13 -m ensurepip --upgrade && python3.13 -m pip install --upgrade pip setuptools

# Install Node.js (using NodeSource repository for latest LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create ubuntu user with sudo privileges EARLY
RUN useradd -m -s /bin/bash ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create workspace directory for ubuntu user
RUN mkdir -p /home/ubuntu/workspace && \
    chown -R ubuntu:ubuntu /home/ubuntu

# Configure npm to use user-writable directory for ubuntu user
ENV NPM_CONFIG_PREFIX=/home/ubuntu/.npm-global
ENV PATH=/home/ubuntu/.npm-global/bin:$PATH

# Switch to ubuntu user to install Claude Code
USER ubuntu

# Install Claude Code as ubuntu user (this allows auto-updates to work)
RUN npm install -g @anthropic-ai/claude-code

# Set working directory to ubuntu's home
WORKDIR /home/ubuntu

# Keep container running for docker exec access
CMD ["sleep", "infinity"]
