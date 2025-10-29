#!/bin/bash
set -e

# Podman Development Script for Made By Jake
# This script sets up the local development environment using Podman

echo "======================================"
echo "Made By Jake - Podman Development Setup"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo -e "${RED}Error: Podman is not installed.${NC}"
    echo "Please run 'scripts/install-podman.sh' first or install Podman manually."
    exit 1
fi

echo -e "${GREEN}✓ Podman is installed${NC}"

# Port registry integration
REGISTRY_DIR="${PODMAN_PORT_REGISTRY_DIR:-${HOME}/.local/share/podman-ports}"
REGISTRY_FILE="$REGISTRY_DIR/registry.json"
PROJECT_NAME="mbjake"
ENVIRONMENT="dev"
PORT_HOST=8005

# Function to ensure port is registered
ensure_port_registered() {
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
        if [ "$REGISTERED_PORT" != "$PORT_HOST" ]; then
            echo -e "${BLUE}Updating script to use registered port $REGISTERED_PORT${NC}"
            PORT_HOST="$REGISTERED_PORT"
        fi
        return 0
    fi
    
    # Port not registered - register it now
    echo -e "${BLUE}Registering port $PORT_HOST for $PROJECT_NAME-$ENVIRONMENT...${NC}"
    
    # Check if port is already reserved by another project
    PORT_OWNER=$(jq -r ".ports.\"$PORT_HOST\" // empty | if . then \"\(.project)-\(.environment)\" else \"\" end" "$REGISTRY_FILE" 2>/dev/null)
    
    if [ -n "$PORT_OWNER" ]; then
        echo -e "${RED}Error: Port $PORT_HOST is already reserved by $PORT_OWNER${NC}"
        echo "Choose a different port or release the existing reservation"
        exit 1
    fi
    
    # Register the port
    TIMESTAMP=$(date -Iseconds)
    UPDATED_REGISTRY=$(jq ".ports.\"$PORT_HOST\" = {
        \"project\": \"$PROJECT_NAME\",
        \"environment\": \"$ENVIRONMENT\",
        \"reserved_at\": \"$TIMESTAMP\",
        \"reserved_by\": \"$USER\"
    }" "$REGISTRY_FILE")
    
    echo "$UPDATED_REGISTRY" > "$REGISTRY_FILE"
    echo -e "${GREEN}✓ Port $PORT_HOST registered successfully${NC}"
}

# Ensure port is registered before deployment
ensure_port_registered

# Note: We don't check for port conflicts here because stop_existing() 
# will free up the port by removing any existing container

# Check if podman-compose is available (optional but recommended)
if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
    echo -e "${GREEN}✓ Using podman-compose${NC}"
elif command -v docker-compose &> /dev/null; then
    # Configure docker-compose to use Podman socket
    export DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock
    
    # Check if Podman socket is available
    if [ ! -S "${DOCKER_HOST#unix://}" ]; then
        echo -e "${YELLOW}⚠ Podman socket not found, enabling it...${NC}"
        systemctl --user enable --now podman.socket
        sleep 2
    fi
    
    if [ -S "${DOCKER_HOST#unix://}" ]; then
        COMPOSE_CMD="docker-compose"
        echo -e "${GREEN}✓ Using docker-compose with Podman socket${NC}"
    else
        echo -e "${YELLOW}⚠ Could not enable Podman socket${NC}"
        echo "Using podman commands directly..."
        COMPOSE_CMD=""
    fi
else
    echo -e "${YELLOW}⚠ Neither podman-compose nor docker-compose found${NC}"
    echo "Using podman commands directly..."
    COMPOSE_CMD=""
fi

# Function to stop existing containers
stop_existing() {
    echo "Stopping existing containers..."
    podman stop mbjake-dev 2>/dev/null || true
    podman rm mbjake-dev 2>/dev/null || true
    echo -e "${GREEN}✓ Cleaned up existing containers${NC}"
}

# Function to build and run with compose
run_with_compose() {
    echo "Building container with $COMPOSE_CMD..."
    $COMPOSE_CMD -f compose-dev.yaml build
    
    echo "Starting container..."
    $COMPOSE_CMD -f compose-dev.yaml up -d
    
    echo -e "${GREEN}✓ Container started successfully${NC}"
}

# Function to build and run with podman directly
run_with_podman() {
    echo "Building container with Podman..."
    podman build -t mbjake-dev:latest -f Containerfile .
    
    echo "Creating network if it doesn't exist..."
    podman network create mbjake-dev-network 2>/dev/null || true
    
    echo "Starting container..."
    podman run -d \
        --name mbjake-dev \
        --network mbjake-dev-network \
        -p 8005:8080 \
        --security-opt no-new-privileges:true \
        --restart unless-stopped \
        mbjake-dev:latest
    
    echo -e "${GREEN}✓ Container started successfully${NC}"
}

# Main execution
stop_existing

if [ -n "$COMPOSE_CMD" ]; then
    run_with_compose
else
    run_with_podman
fi

# Wait for container to be healthy
echo "Waiting for container to be healthy (max 60 seconds)..."
max_attempts=30
attempt=0
container_healthy=false

while [ $attempt -lt $max_attempts ]; do
    # Check if container is running
    if ! podman ps --format "{{.Names}}" | grep -q "^mbjake-dev$"; then
        echo ""
        echo -e "${RED}✗ Container is not running${NC}"
        echo "Check logs with: podman logs mbjake-dev"
        exit 1
    fi
    
    # Query health status using inspect (safe, doesn't trigger checks)
    health_status=$(podman inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' mbjake-dev 2>/dev/null)
    
    if [ "$health_status" = "none" ]; then
        # Container doesn't have a health check configured
        echo ""
        echo -e "${YELLOW}⚠ No health check configured for this container${NC}"
        echo -e "${GREEN}✓ Container is running${NC}"
        container_healthy=true
        break
    elif [ "$health_status" = "healthy" ]; then
        echo ""
        echo -e "${GREEN}✓ Container is healthy${NC}"
        container_healthy=true
        break
    elif [ "$health_status" = "unhealthy" ]; then
        echo ""
        echo -e "${RED}✗ Container is unhealthy${NC}"
        echo "Last 20 lines of container logs:"
        podman logs --tail 20 mbjake-dev
        exit 1
    fi
    
    # Status is "starting" or other - keep waiting
    attempt=$((attempt + 1))
    echo -n "."
    sleep 2
done

if [ "$container_healthy" = false ]; then
    echo ""
    echo -e "${YELLOW}⚠ Health check timed out - container may still be starting${NC}"
    echo "Current health status: $(podman inspect --format '{{.State.Health.Status}}' mbjake-dev 2>/dev/null || echo 'unknown')"
    echo ""
    echo "Last 20 lines of container logs:"
    podman logs --tail 20 mbjake-dev
fi

# Display container info
echo ""
echo "======================================"
echo "Container Information"
echo "======================================"
podman ps --filter name=mbjake-dev --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo -e "${GREEN}✓ Development environment is ready!${NC}"
echo ""
echo "Access your site at: http://localhost:8005"
echo "Or via domain (if Traefik is configured): https://dev.mbjake.com"
echo ""
echo "Useful commands:"
echo "  View logs:        podman logs -f mbjake-dev"
echo "  Stop container:   podman stop mbjake-dev"
echo "  Remove container: podman rm mbjake-dev"
echo "  Shell access:     podman exec -it mbjake-dev sh"
echo "  Health check:     curl http://localhost:8005/health"
