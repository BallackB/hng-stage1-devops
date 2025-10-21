#!/bin/bash

###############################################################################
# HNG DevOps Stage 1 - Automated Deployment Script
# Author: Victor Efunwa (@BallackB)
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
###############################################################################
# 2. Clone or Pull Repository
###############################################################################

log "📁 Preparing to clone or update repository..."

# Extract repo directory name from URL
REPO_DIR=$(basename "$GIT_REPO_URL" .git)

if [[ -d "$REPO_DIR" ]]; then
    log "📂 Repository already exists. Pulling latest changes..."
    cd "$HOME/$REPO_DIR" || exit
    git pull origin "$GIT_BRANCH" || { error "Git pull failed!"; exit 1; }
else
    log "📥 Cloning repository..."
    GIT_REPO_URL_AUTH="https://${GITHUB_PAT}@${GIT_REPO_URL#https://}"
    git clone -b "$GIT_BRANCH" "$GIT_REPO_URL_AUTH" || { error "Git clone failed!"; exit 1; }
    cd "$REPO_DIR" || exit
fi

log "✅ Repository ready and on branch $GIT_BRANCH."
###############################################################################
# 3. Validate SSH Connection
###############################################################################

log "🔌 Testing SSH connectivity to $SSH_USER@$SERVER_IP..."

ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "echo 'SSH connection successful'" \
    || { error "SSH connection failed! Check IP, SSH user, or SSH key path."; exit 1; }

log "✅ SSH connection validated."
###############################################################################
# 4. Prepare Remote Server (Docker, Docker Compose, Nginx)
###############################################################################

log "⚙️ Preparing remote server environment..."

ssh -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" << 'EOF'
    set -e

    echo "🔄 Updating system packages..."
    sudo apt update -y && sudo apt upgrade -y

    echo "🐳 Installing Docker..."
    if ! command -v docker &> /dev/null; then
        sudo apt install -y docker.io
        sudo systemctl enable --now docker
        echo "✅ Docker installed."
    else
        echo "ℹ️ Docker already installed."
    fi

    echo "📦 Installing Docker Compose..."
    if ! command -v docker-compose &> /dev/null; then
        sudo apt install -y docker-compose
        echo "✅ Docker Compose installed."
    else
        echo "ℹ️ Docker Compose already installed."
    fi

    echo "🌐 Installing NGINX (for reverse proxy)..."
    if ! command -v nginx &> /dev/null; then
        sudo apt install -y nginx
        sudo systemctl enable --now nginx
        echo "✅ Nginx installed."
    else
        echo "ℹ️ Nginx already installed."
    fi

    echo "👥 Adding user to Docker group..."
    sudo usermod -aG docker $USER
EOF

log "✅ Remote server environment prepared."
###############################################################################
# 5. Transfer Project & Deploy Application
###############################################################################

log "📤 Transferring project files to remote server..."

# Use rsync for efficient transfer — fallback to scp if rsync not available
if command -v rsync &> /dev/null; then
    # Always use the absolute path to ensure correct transfer and cd behavior
    LOCAL_PATH="$HOME/$REPO_DIR"

    log "[DEBUG] Using LOCAL_PATH = $LOCAL_PATH"

    rsync -avz -e "ssh -i $SSH_KEY_PATH" --delete "$LOCAL_PATH/" "$SSH_USER@$SERVER_IP:/home/$SSH_USER/$REPO_DIR/"
else
    scp -i "$SSH_KEY_PATH" -r "$HOME/$REPO_DIR" "$SSH_USER@$SERVER_IP:/home/$SSH_USER/"
fi

log "🚀 Deploying Docker application on remote server..."

ssh -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" << EOF
    set -e
    cd "/home/$SSH_USER/$REPO_DIR" || { echo "❌ Repo directory not found"; exit 1; }

    echo "🛑 Stopping any previous containers..."
    docker compose down 2>/dev/null || docker stop \$(docker ps -q --filter "ancestor=$REPO_DIR") 2>/dev/null || true
    docker rm \$(docker ps -aq --filter "ancestor=$REPO_DIR") 2>/dev/null || true

    echo "⚙️ Deploying application using Docker..."
    if [ -f docker-compose.yml ]; then
        docker compose up -d --build
    else
        docker build -t $REPO_DIR .
        docker run -d -p $APP_PORT:$APP_PORT --name hng_app $REPO_DIR
    fi

    echo "✅ Deployment complete. Checking container status..."
    docker ps --filter "ancestor=$REPO_DIR"
EOF

log "✅ Docker application deployed successfully."
###############################################################################
# 6. Configure NGINX Reverse Proxy
###############################################################################

log "🌐 Configuring NGINX reverse proxy..."

ssh -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" << EOF
    set -e

    echo "📝 Creating NGINX config..."
    sudo tee /etc/nginx/sites-available/hng_proxy > /dev/null <<EOL
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

    echo "🔗 Enabling NGINX config..."
    sudo ln -sf /etc/nginx/sites-available/hng_proxy /etc/nginx/sites-enabled/default

    echo "🔄 Testing and reloading NGINX..."
    sudo nginx -t && sudo systemctl reload nginx

    echo "🌍 Testing HTTP access via curl..."
    curl -I http://127.0.0.1 || echo "⚠️ Local curl check failed, please verify manually."
EOF

log "✅ NGINX reverse proxy configured successfully."
###############################################################################
# 7. Optional Cleanup (Idempotency Support)
###############################################################################

if [[ "${1:-}" == "--cleanup" ]]; then
    log "🧹 Cleanup flag detected — removing deployment artifacts..."

    ssh -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" << EOF
        set -e
        echo "🛑 Stopping containers..."
        docker compose down 2>/dev/null || docker stop \$(docker ps -q) || true
        docker rm \$(docker ps -aq) || true
        docker rmi -f \$(docker images -q) || true

        echo "🗑 Removing NGINX config..."
        sudo rm -f /etc/nginx/sites-available/hng_proxy
        sudo rm -f /etc/nginx/sites-enabled/hng_proxy
        sudo nginx -t && sudo systemctl reload nginx || true

        echo "✅ Cleanup completed."
EOF

    log "✅ Cleanup process executed successfully."
    exit 0
fi

