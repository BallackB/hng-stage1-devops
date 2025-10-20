#!/bin/bash

###############################################################################
# HNG DevOps Stage 1 - Automated Deployment Script
# Author: Victor Efunwa (@Ballack)
# Description: Automates deployment of a Dockerized app on a remote server.
# Logs: Generates deployment logs with timestamp.
###############################################################################

# Enable strict mode (good DevOps practice)
set -euo pipefail

# === Color codes for better terminal output ===
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# === Logging Setup ===
LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"

log() {
    echo -e "${GREEN}[INFO]${RESET} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $1" | tee -a "$LOG_FILE" >&2
}

trap 'error "An unexpected error occurred. Check $LOG_FILE for details." ; exit 1' ERR

log "Starting HNG DevOps Stage 1 Deployment Script..."
###############################################################################
# 1. Collect User Input
###############################################################################

log "🔧 Collecting user input..."

read -p "👉 Enter Git Repository URL: " GIT_REPO_URL
if [[ -z "$GIT_REPO_URL" ]]; then
    error "Git repository URL cannot be empty!"
    exit 1
fi

read -p "👉 Enter Personal Access Token (PAT): " GITHUB_PAT
if [[ -z "$GITHUB_PAT" ]]; then
    error "PAT cannot be empty!"
    exit 1
fi

read -p "👉 Enter Branch Name (default: main): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}

read -p "👉 Enter Remote Server SSH Username: " SSH_USER
if [[ -z "$SSH_USER" ]]; then
    error "SSH Username cannot be empty!"
    exit 1
fi

read -p "👉 Enter Remote Server IP Address: " SERVER_IP
if [[ -z "$SERVER_IP" ]]; then
    error "Server IP cannot be empty!"
    exit 1
fi

read -p "👉 Enter SSH Key Path (e.g., ~/.ssh/id_rsa): " SSH_KEY_PATH
if [[ -z "$SSH_KEY_PATH" ]]; then
    error "SSH Key Path cannot be empty!"
    exit 1
fi

read -p "👉 Enter Application Port (internal container port, e.g., 3000): " APP_PORT
if [[ -z "$APP_PORT" ]]; then
    error "Application port cannot be empty!"
    exit 1
fi

log "✅ User input collected successfully."
