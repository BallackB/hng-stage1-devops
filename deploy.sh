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
