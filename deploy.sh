#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Podman-based Deployment Script for Made By Jake
# This script pulls the latest code and deploys using Podman

echo "======================================"
echo "Made By Jake - Podman Deployment"
echo "======================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR=""

# Navigate to the project directory
cd "$PROJECT_DIR" || { echo -e "${RED}Deployment failed: Project directory not found.${NC}"; exit 1; }
echo -e "${GREEN}✓ Changed to project directory${NC}"

# Pull the latest changes from the git repository
echo "Pulling latest changes from Git..."
git pull origin develop
echo -e "${GREEN}✓ Latest changes pulled successfully${NC}"

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo -e "${RED}Error: Podman is not installed.${NC}"
    echo "Please run 'scripts/install-podman.sh' first."
    exit 1
fi

echo -e "${BLUE}Deploying with Podman...${NC}"

# Run the production deployment script
bash scripts/podman-prod.sh

echo ""
echo "======================================"
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo "======================================"
