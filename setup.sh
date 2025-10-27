#!/bin/bash
set -e

# Podman Deployment Template Setup Script
# One-time bootstrap that generates BOTH dev and prod environments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
PROJECT_TYPES_DIR="$SCRIPT_DIR/project-types"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "Podman Deployment Template Setup"
echo "========================================"
echo ""

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "One-time bootstrap script that generates deployment files for BOTH dev and prod environments."
    echo ""
    echo "Options:"
    echo "  -o, --output DIR       Output directory (default: current directory)"
    echo "  -d, --dry-run          Show what would be done without making changes"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - Copy and edit podman.config.dev and podman.config.prod"
    echo "  - Install jq: sudo apt-get install jq"
    echo ""
    echo "This script will:"
    echo "  1. Generate dev environment files (compose-dev.yaml, scripts/podman-dev.sh, etc.)"
    echo "  2. Generate prod environment files (compose-prod.yaml, scripts/podman-prod.sh, etc.)"
    echo "  3. Clean up template infrastructure"
    echo "  4. Remove itself"
    echo ""
    exit 1
}

# Parse command line arguments
OUTPUT_DIR="$SCRIPT_DIR"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check for required config files
CONFIG_DEV="$SCRIPT_DIR/podman.config.dev"
CONFIG_PROD="$SCRIPT_DIR/podman.config.prod"

MISSING_CONFIGS=()
if [ ! -f "$CONFIG_DEV" ]; then
    MISSING_CONFIGS+=("podman.config.dev")
fi
if [ ! -f "$CONFIG_PROD" ]; then
    MISSING_CONFIGS+=("podman.config.prod")
fi

if [ ${#MISSING_CONFIGS[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required config files:${NC}"
    for config in "${MISSING_CONFIGS[@]}"; do
        echo "  - $config"
    done
    echo ""
    echo "Please create config files by copying the examples:"
    echo "  cp podman.config.dev.example podman.config.dev"
    echo "  cp podman.config.prod.example podman.config.prod"
    echo "  # Edit both files with your project details"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Found both config files${NC}"

# Check if jq is installed (required for port registry)
PORT_REGISTRY="$SCRIPT_DIR/bin/podman-port-registry"
if [ -f "$PORT_REGISTRY" ]; then
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required for port registry but not installed${NC}"
        echo ""
        echo "Install jq:"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  RHEL/Fedora:   sudo dnf install jq"
        echo "  macOS:         brew install jq"
        echo ""
        exit 1
    fi
    echo -e "${GREEN}✓ jq is installed${NC}"
fi

# Function to replace placeholders in content
replace_placeholders() {
    local content="$1"
    
    # Replace all placeholders
    content="${content//\{\{PROJECT_NAME\}\}/$PROJECT_NAME}"
    content="${content//\{\{CONTAINER_NAME\}\}/$CONTAINER_NAME}"
    content="${content//\{\{ENVIRONMENT\}\}/$ENVIRONMENT}"
    content="${content//\{\{PROJECT_DISPLAY_NAME\}\}/$PROJECT_DISPLAY_NAME}"
    content="${content//\{\{PROJECT_TYPE\}\}/$PROJECT_TYPE}"
    content="${content//\{\{DOMAIN\}\}/$DOMAIN}"
    content="${content//\{\{FULL_DOMAIN\}\}/$FULL_DOMAIN}"
    content="${content//\{\{PORT_CONTAINER\}\}/$PORT_CONTAINER}"
    content="${content//\{\{PORT_HOST\}\}/$PORT_HOST}"
    content="${content//\{\{BUILD_COMMAND\}\}/$BUILD_COMMAND}"
    content="${content//\{\{BUILD_OUTPUT\}\}/$BUILD_OUTPUT}"
    content="${content//\{\{NODE_VERSION\}\}/$NODE_VERSION}"
    content="${content//\{\{MEMORY_LIMIT\}\}/$MEMORY_LIMIT}"
    content="${content//\{\{CPU_LIMIT\}\}/$CPU_LIMIT}"
    content="${content//\{\{PROCESS_LIMIT\}\}/$PROCESS_LIMIT}"
    content="${content//\{\{HEALTH_PATH\}\}/$HEALTH_PATH}"
    content="${content//\{\{HEALTH_INTERVAL\}\}/$HEALTH_INTERVAL}"
    content="${content//\{\{HEALTH_TIMEOUT\}\}/$HEALTH_TIMEOUT}"
    content="${content//\{\{HEALTH_RETRIES\}\}/$HEALTH_RETRIES}"
    content="${content//\{\{HEALTH_START_PERIOD\}\}/$HEALTH_START_PERIOD}"
    content="${content//\{\{DEPLOY_DIR\}\}/$DEPLOY_DIR}"
    content="${content//\{\{GIT_BRANCH\}\}/$GIT_BRANCH}"
    content="${content//\{\{TIMEZONE\}\}/$TIMEZONE}"
    content="${content//\{\{NETWORK_NAME\}\}/$NETWORK_NAME}"
    content="${content//\{\{PROXY_NETWORK\}\}/$PROXY_NETWORK}"
    content="${content//\{\{REVERSE_PROXY\}\}/$REVERSE_PROXY}"
    content="${content//\{\{ENABLE_SSL\}\}/$ENABLE_SSL}"
    content="${content//\{\{SSL_RESOLVER\}\}/$SSL_RESOLVER}"
    content="${content//\{\{TRAEFIK_ENABLE\}\}/$TRAEFIK_ENABLE}"
    content="${content//\{\{TRAEFIK_MIDDLEWARE\}\}/$TRAEFIK_MIDDLEWARE}"
    content="${content//\{\{DEV_IP_WHITELIST\}\}/$DEV_IP_WHITELIST}"
    content="${content//\{\{READONLY_ROOTFS\}\}/$READONLY_ROOTFS}"
    content="${content//\{\{NO_NEW_PRIVILEGES\}\}/$NO_NEW_PRIVILEGES}"
    content="${content//\{\{SELINUX_LABEL\}\}/$SELINUX_LABEL}"
    content="${content//\{\{CONTAINER_USER\}\}/$CONTAINER_USER}"
    content="${content//\{\{CONTAINER_UID\}\}/$CONTAINER_UID}"
    content="${content//\{\{GITHUB_REPO\}\}/$GITHUB_REPO}"
    content="${content//\{\{DEPLOY_USER\}\}/$DEPLOY_USER}"
    content="${content//\{\{DEPLOY_HOST\}\}/$DEPLOY_HOST}"
    
    echo "$content"
}

# Function to process a template file
process_template() {
    local template_file="$1"
    local output_file="$2"
    
    if [ ! -f "$template_file" ]; then
        echo -e "${RED}Warning: Template not found: $template_file${NC}"
        return
    fi
    
    # Read template
    local content=$(cat "$template_file")
    
    # Replace placeholders
    content=$(replace_placeholders "$content")
    
    # Strip any ANSI color codes that may have leaked in
    content=$(echo "$content" | sed 's/\x1b\[[0-9;]*m//g')
    
    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${BLUE}Would create: $output_file${NC}"
    else
        # Create directory if needed
        mkdir -p "$(dirname "$output_file")"
        
        # Write output
        echo "$content" > "$output_file"
        echo -e "${GREEN}  ✓ Created: $(basename $output_file)${NC}"
        
        # Make scripts executable
        if [[ "$output_file" == *.sh ]]; then
            chmod +x "$output_file"
        fi
    fi
}

# Function to process one environment
process_environment() {
    local env="$1"
    local config_file="$SCRIPT_DIR/podman.config.$env"
    
    echo ""
    echo "========================================"
    echo "Processing $env environment"
    echo "========================================"
    
    # Load configuration
    echo "Loading configuration from $config_file..."
    source "$config_file"
    
    # Validate required configuration
    REQUIRED_VARS=(
        "PROJECT_NAME"
        "PROJECT_DISPLAY_NAME"
        "PROJECT_TYPE"
        "DOMAIN"
        "BUILD_COMMAND"
        "BUILD_OUTPUT"
        "PORT_CONTAINER"
    )
    
    MISSING_VARS=()
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            MISSING_VARS+=("$var")
        fi
    done
    
    if [ ${#MISSING_VARS[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required variables in $config_file:${NC}"
        for var in "${MISSING_VARS[@]}"; do
            echo "  - $var"
        done
        exit 1
    fi
    
    echo -e "${GREEN}✓ Configuration validated${NC}"
    
    # Set defaults
    : ${NODE_VERSION:=20}
    : ${MEMORY_LIMIT:=512M}
    : ${CPU_LIMIT:=1.0}
    : ${PROCESS_LIMIT:=100}
    : ${HEALTH_PATH:=/health}
    : ${HEALTH_INTERVAL:=30s}
    : ${HEALTH_TIMEOUT:=5s}
    : ${HEALTH_RETRIES:=3}
    : ${HEALTH_START_PERIOD:=10s}
    : ${DEPLOY_DIR:=/home/user/projects/${PROJECT_NAME}}
    : ${GIT_BRANCH:=main}
    : ${TIMEZONE:=America/Chicago}
    : ${NETWORK_NAME:=${PROJECT_NAME}-network}
    : ${PROXY_NETWORK:=proxy-network}
    : ${REVERSE_PROXY:=traefik}
    : ${ENABLE_SSL:=true}
    : ${SSL_RESOLVER:=letsencrypt}
    : ${READONLY_ROOTFS:=true}
    : ${NO_NEW_PRIVILEGES:=true}
    : ${SELINUX_LABEL:=container_runtime_t}
    : ${CONTAINER_USER:=nginx-rootless}
    : ${CONTAINER_UID:=101}
    : ${GITHUB_REPO:=username/repo}
    : ${DEPLOY_USER:=user}
    : ${DEPLOY_HOST:=server.example.com}
    : ${DEV_IP_WHITELIST:=127.0.0.1/8,100.64.0.0/10}
    
    # Set environment-specific values
    ENVIRONMENT="$env"
    CONTAINER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
    NETWORK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-network"
    
    # Set domain with environment prefix for dev
    if [ "$ENVIRONMENT" == "dev" ]; then
        FULL_DOMAIN="dev.${DOMAIN}"
    else
        FULL_DOMAIN="${DOMAIN}"
    fi
    
    # Set Traefik enable based on reverse proxy type
    if [ "$REVERSE_PROXY" == "traefik" ]; then
        TRAEFIK_ENABLE=true
    else
        TRAEFIK_ENABLE=false
    fi
    
    # Set Traefik middleware for dev environment
    if [ "$ENVIRONMENT" == "dev" ]; then
        TRAEFIK_MIDDLEWARE="${PROJECT_NAME}-dev-ipwhitelist@file"
    else
        TRAEFIK_MIDDLEWARE=""
    fi
    
    # Port registry integration
    if [ -f "$PORT_REGISTRY" ]; then
        echo "Integrating with port registry..."
        
        if [ -z "$PORT_HOST" ]; then
            echo "Requesting auto-allocation for $env..."
            if [ "$DRY_RUN" == "false" ]; then
                PORT_HOST=$("$PORT_REGISTRY" reserve "$PROJECT_NAME" "$ENVIRONMENT" 2>/dev/null)
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Error: Failed to allocate port${NC}"
                    exit 1
                fi
                echo -e "${GREEN}✓ Allocated port: $PORT_HOST${NC}"
            else
                PORT_HOST=8080  # Dummy port for dry-run
                echo -e "${BLUE}Would allocate port via registry${NC}"
            fi
        else
            if [ "$DRY_RUN" == "false" ]; then
                RESERVED_PORT=$("$PORT_REGISTRY" reserve "$PROJECT_NAME" "$ENVIRONMENT" "$PORT_HOST" 2>/dev/null)
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Error: Failed to reserve port $PORT_HOST${NC}"
                    exit 1
                fi
                PORT_HOST="$RESERVED_PORT"
                echo -e "${GREEN}✓ Reserved port: $PORT_HOST${NC}"
            else
                echo -e "${BLUE}Would reserve port $PORT_HOST via registry${NC}"
            fi
        fi
    fi
    
    # Display configuration summary
    echo "Configuration for $env:"
    echo "  Container:     $CONTAINER_NAME"
    echo "  Domain:        $FULL_DOMAIN"
    echo "  Port:          $PORT_HOST"
    echo "  Network:       $NETWORK_NAME"
    
    # Generate files
    echo "Generating files..."
    
    # Main files with environment suffix
    process_template "$TEMPLATE_DIR/compose.yaml.template" "$OUTPUT_DIR/compose-${env}.yaml"
    
    # Scripts
    mkdir -p "$OUTPUT_DIR/scripts"
    if [ "$env" == "dev" ]; then
        process_template "$TEMPLATE_DIR/scripts/podman-dev.sh.template" "$OUTPUT_DIR/scripts/podman-dev.sh"
    else
        process_template "$TEMPLATE_DIR/scripts/podman-prod.sh.template" "$OUTPUT_DIR/scripts/podman-prod.sh"
    fi
    
    # Systemd services
    process_template "$TEMPLATE_DIR/scripts/{{PROJECT_NAME}}.service.template" "$OUTPUT_DIR/scripts/${CONTAINER_NAME}.service"
    process_template "$TEMPLATE_DIR/scripts/{{PROJECT_NAME}}-user.service.template" "$OUTPUT_DIR/scripts/${CONTAINER_NAME}-user.service"
    
    # Traefik middleware for dev environment
    if [ "$ENVIRONMENT" == "dev" ] && [ "$REVERSE_PROXY" == "traefik" ]; then
        mkdir -p "$OUTPUT_DIR/traefik"
        process_template "$TEMPLATE_DIR/traefik-middleware.yaml.template" "$OUTPUT_DIR/traefik/middleware-${PROJECT_NAME}-dev.yaml"
    fi
    
    echo -e "${GREEN}✓ $env environment complete${NC}"
}

# Process common files (only once)
echo "Generating common files..."
# These files are shared and generated from the first config (dev)
source "$CONFIG_DEV"

# Set defaults for common file generation
: ${NODE_VERSION:=20}
: ${MEMORY_LIMIT:=512M}
: ${CPU_LIMIT:=1.0}
: ${PROCESS_LIMIT:=100}
: ${HEALTH_PATH:=/health}
: ${HEALTH_INTERVAL:=30s}
: ${HEALTH_TIMEOUT:=5s}
: ${HEALTH_RETRIES:=3}
: ${HEALTH_START_PERIOD:=10s}
: ${PORT_CONTAINER:=8080}

# Set minimal required variables for common files
PROJECT_NAME="${PROJECT_NAME}"
PROJECT_DISPLAY_NAME="${PROJECT_DISPLAY_NAME}"
PROJECT_TYPE="${PROJECT_TYPE}"
DOMAIN="${DOMAIN}"
BUILD_COMMAND="${BUILD_COMMAND}"
BUILD_OUTPUT="${BUILD_OUTPUT}"
NODE_VERSION="${NODE_VERSION}"

process_template "$TEMPLATE_DIR/Containerfile.template" "$OUTPUT_DIR/Containerfile"
process_template "$TEMPLATE_DIR/nginx.conf.template" "$OUTPUT_DIR/nginx.conf"
process_template "$TEMPLATE_DIR/deploy.sh.template" "$OUTPUT_DIR/deploy.sh"
process_template "$TEMPLATE_DIR/.containerignore.template" "$OUTPUT_DIR/.containerignore" 2>/dev/null || true

# Copy install script
mkdir -p "$OUTPUT_DIR/scripts"
if [ -f "$TEMPLATE_DIR/scripts/install-podman.sh" ]; then
    cp "$TEMPLATE_DIR/scripts/install-podman.sh" "$OUTPUT_DIR/scripts/install-podman.sh"
    [ "$DRY_RUN" == "false" ] && chmod +x "$OUTPUT_DIR/scripts/install-podman.sh"
    echo -e "${GREEN}  ✓ Created: install-podman.sh${NC}"
fi

# Process CI/CD
mkdir -p "$OUTPUT_DIR/.github/workflows"
process_template "$TEMPLATE_DIR/ci-cd/podman-build.yml.template" "$OUTPUT_DIR/.github/workflows/podman-build.yml" 2>/dev/null || true

# Process static-site starter files if needed
if [ "$PROJECT_TYPE" == "static-site" ] && [ ! -f "$OUTPUT_DIR/src/index.html" ]; then
    echo "Copying static-site starter files..."
    if [ -d "$TEMPLATE_DIR/static-site-starter" ]; then
        mkdir -p "$OUTPUT_DIR/src"
        process_template "$TEMPLATE_DIR/static-site-starter/package.json.template" "$OUTPUT_DIR/package.json"
        process_template "$TEMPLATE_DIR/static-site-starter/src/index.html.template" "$OUTPUT_DIR/src/index.html"
        process_template "$TEMPLATE_DIR/static-site-starter/src/style.css.template" "$OUTPUT_DIR/src/style.css"
        process_template "$TEMPLATE_DIR/static-site-starter/src/script.js.template" "$OUTPUT_DIR/src/script.js"
    fi
fi

# Process both environments
process_environment "dev"
process_environment "prod"

# Cleanup template files
if [ "$DRY_RUN" == "false" ]; then
    ABS_OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)
    ABS_SCRIPT_DIR=$(cd "$SCRIPT_DIR" && pwd)
    
    if [ "$ABS_OUTPUT_DIR" == "$ABS_SCRIPT_DIR" ]; then
        echo ""
        echo "Cleaning up template files..."
        
        rm -rf "$OUTPUT_DIR/templates" 2>/dev/null || true
        rm -rf "$OUTPUT_DIR/project-types" 2>/dev/null || true
        rm -rf "$OUTPUT_DIR/bin" 2>/dev/null || true
        rm -f "$OUTPUT_DIR/podman.config.*.example" 2>/dev/null || true
        rm -f "$OUTPUT_DIR/QUICKSTART.md" 2>/dev/null || true
        rm -f "$OUTPUT_DIR/SETUP.md" 2>/dev/null || true
        rm -f "$OUTPUT_DIR/TEMPLATE-COMPLETE.md" 2>/dev/null || true
        rm -f "$OUTPUT_DIR/TEMPLATE-SUMMARY.md" 2>/dev/null || true
        
        echo -e "${GREEN}✓ Template files cleaned up${NC}"
        
        # Remove setup scripts
        echo "Removing setup scripts..."
        rm -f "$OUTPUT_DIR/setup.sh" 2>/dev/null || true
        rm -f "$OUTPUT_DIR/setup-new.sh" 2>/dev/null || true
        
        echo -e "${GREEN}✓ Setup scripts removed${NC}"
    fi
fi

echo ""
echo "========================================"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo "========================================"
echo ""
echo "Generated environments:"
echo "  - Development: compose-dev.yaml, scripts/podman-dev.sh"
echo "  - Production:  compose-prod.yaml, scripts/podman-prod.sh"
echo ""
echo "Next steps:"
echo "  1. Review the generated files"
echo "  2. Deploy dev:  bash scripts/podman-dev.sh"
echo "  3. Deploy prod: bash scripts/podman-prod.sh"
echo ""
echo "Port registry:"
echo "  View allocations: ~/.local/share/podman-ports/registry.json"
echo ""

