#!/bin/bash
set -e

# Podman Production Deployment Script for Made By Jake
# This script deploys the application to production using Podman

echo "======================================"
echo "Made By Jake - Production Deployment"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="mbjake-prod"
IMAGE_NAME="mbjake-prod:latest"
HOST_PORT="${HOST_PORT:-8006}"
NETWORK_NAME="mbjake-prod-network"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}⚠ Running as root. Consider using rootless Podman for better security.${NC}"
fi

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo -e "${RED}Error: Podman is not installed.${NC}"
    echo "Please run 'scripts/install-podman.sh' first."
    exit 1
fi

echo -e "${GREEN}✓ Podman is installed${NC}"

# Port registry integration
REGISTRY_DIR="${PODMAN_PORT_REGISTRY_DIR:-${HOME}/.local/share/podman-ports}"
REGISTRY_FILE="$REGISTRY_DIR/registry.json"
PROJECT_NAME="mbjake"
ENVIRONMENT="prod"

# Function to ensure port is registered
ensure_port_registered() {
    local PORT_TO_REGISTER="$HOST_PORT"
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠ jq not installed - skipping port registry${NC}"
        return 0
    fi
    
    # Check if registry exists
    if [ ! -f "$REGISTRY_FILE" ]; then
        echo -e "${YELLOW}⚠ Port registry not initialized${NC}"
        echo "Run 'scripts/setup-registry' to initialize the port registry"
        return 0
    fi
    
    # Check if this project-environment already has a port registered
    REGISTERED_PORT=$(jq -r ".ports | to_entries[] | select(.value.project == \"$PROJECT_NAME\" and .value.environment == \"$ENVIRONMENT\") | .key" "$REGISTRY_FILE" 2>/dev/null | head -n1)
    
    if [ -n "$REGISTERED_PORT" ]; then
        echo -e "${GREEN}✓ Port already registered for $PROJECT_NAME-$ENVIRONMENT: $REGISTERED_PORT${NC}"
        if [ "$REGISTERED_PORT" != "$PORT_TO_REGISTER" ]; then
            echo -e "${BLUE}Updating script to use registered port $REGISTERED_PORT${NC}"
            HOST_PORT="$REGISTERED_PORT"
        fi
        return 0
    fi
    
    # Port not registered - register it now
    echo -e "${BLUE}Registering port $PORT_TO_REGISTER for $PROJECT_NAME-$ENVIRONMENT...${NC}"
    
    # Check if port is already reserved by another project
    PORT_OWNER=$(jq -r ".ports.\"$PORT_TO_REGISTER\" // empty | if . then \"\(.project)-\(.environment)\" else \"\" end" "$REGISTRY_FILE" 2>/dev/null)
    
    if [ -n "$PORT_OWNER" ]; then
        echo -e "${RED}Error: Port $PORT_TO_REGISTER is already reserved by $PORT_OWNER${NC}"
        echo "Choose a different port or release the existing reservation"
        exit 1
    fi
    
    # Register the port
    TIMESTAMP=$(date -Iseconds)
    UPDATED_REGISTRY=$(jq ".ports.\"$PORT_TO_REGISTER\" = {
        \"project\": \"$PROJECT_NAME\",
        \"environment\": \"$ENVIRONMENT\",
        \"reserved_at\": \"$TIMESTAMP\",
        \"reserved_by\": \"$USER\"
    }" "$REGISTRY_FILE")
    
    echo "$UPDATED_REGISTRY" > "$REGISTRY_FILE"
    echo -e "${GREEN}✓ Port $PORT_TO_REGISTER registered successfully${NC}"
}

# Ensure port is registered before deployment
ensure_port_registered

# Function to stop and remove old container
cleanup_old() {
    echo "Cleaning up old container..."
    # Use force remove to avoid hanging on bad containers
    podman rm -f $CONTAINER_NAME 2>/dev/null || true
    echo -e "${GREEN}✓ Old container cleaned up${NC}"
}

# Function to build new image
build_image() {
    echo "Building new container image..."
    cd "$PROJECT_DIR"
    podman build -t $IMAGE_NAME -f Containerfile . --layers=true
    echo -e "${GREEN}✓ Image built successfully${NC}"
}

# Function to create networks
setup_networks() {
    echo "Setting up networks..."
    
    # Create network if it doesn't exist
    if ! podman network exists $NETWORK_NAME 2>/dev/null; then
        podman network create $NETWORK_NAME
        echo -e "${GREEN}✓ Created network: $NETWORK_NAME${NC}"
    else
        echo -e "${GREEN}✓ Network already exists: $NETWORK_NAME${NC}"
    fi
}

# Function to start new container
start_container() {
    echo "Starting new container..."
    
    podman run -d \
        --name $CONTAINER_NAME \
        --network $NETWORK_NAME \
        -p ${HOST_PORT}:8080 \
        --security-opt no-new-privileges:true \
        --restart unless-stopped \
        $IMAGE_NAME
    
    echo -e "${GREEN}✓ Container started${NC}"
}

# Function to verify deployment
verify_deployment() {
    echo "Verifying deployment..."
    
    # Check if container is running
    if ! podman ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${RED}✗ Container is not running${NC}"
        echo "Check logs with: podman logs $CONTAINER_NAME"
        return 1
    fi
    
    # Give container a moment to initialize
    sleep 2
    
    # Verify it's still running after initialization
    if podman ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${GREEN}✓ Container is running${NC}"
        return 0
    else
        echo -e "${RED}✗ Container stopped unexpectedly${NC}"
        echo "Last 20 lines of container logs:"
        podman logs --tail 20 $CONTAINER_NAME 2>/dev/null || true
        return 1
    fi
}

# Main deployment flow
main() {
    echo -e "${BLUE}Starting deployment process...${NC}"
    
    # Stop and remove old container
    cleanup_old
    
    # Build new image
    build_image
    
    # Setup networks
    setup_networks
    
    # Start new container
    start_container
    
    # Verify deployment
    if verify_deployment; then
        echo ""
        echo "======================================"
        echo -e "${GREEN}✓ Deployment Successful!${NC}"
        echo "======================================"
        
        # Display container info
        podman ps --filter name=$CONTAINER_NAME
        
        echo ""
        echo "Container is accessible at: http://localhost:${HOST_PORT}"
        echo "Or via domain (if reverse proxy is configured): https://mbjake.com"
        echo ""
        echo "Useful commands:"
        echo "  View logs:        podman logs -f $CONTAINER_NAME"
        echo "  Container stats:  podman stats $CONTAINER_NAME --no-stream"
        echo "  Stop container:   podman stop $CONTAINER_NAME"
    else
        echo -e "${RED}✗ Deployment failed${NC}"
        echo "Check logs with: podman logs $CONTAINER_NAME"
        exit 1
    fi
}

# Run main deployment
main
