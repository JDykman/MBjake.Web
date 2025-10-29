#!/bin/bash
set -e

# Podman Installation Script
# Supports: Ubuntu/Debian, RHEL/CentOS/Fedora, macOS, Windows (WSL2)

echo "======================================"
echo "Podman Installation Script"
echo "======================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            VER=$VERSION_ID
            
            # Handle Ubuntu derivatives (Linux Mint, Pop!_OS, etc.)
            if [[ "$ID_LIKE" == *"ubuntu"* ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
                # For Ubuntu derivatives, use the Ubuntu version they're based on
                if [ -n "$UBUNTU_CODENAME" ]; then
                    # Map Ubuntu codename to version for repository
                    case $UBUNTU_CODENAME in
                        jammy) VER="22.04" ;;
                        focal) VER="20.04" ;;
                        noble) VER="24.04" ;;
                        *) VER="22.04" ;;  # Default to 22.04
                    esac
                fi
                # Normalize to ubuntu for installation
                [[ "$OS" != "ubuntu" ]] && [[ "$OS" != "debian" ]] && OS="ubuntu"
            fi
        else
            echo -e "${RED}Cannot detect Linux distribution${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        echo -e "${RED}Unsupported operating system: $OSTYPE${NC}"
        exit 1
    fi
}

# Install on Ubuntu/Debian
install_ubuntu_debian() {
    echo -e "${BLUE}Installing Podman on Ubuntu/Debian...${NC}"
    
    # Update package list
    sudo apt-get update
    
    # Install dependencies
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        jq
    
    # Try Kubic repository for latest Podman (may not work on newer Ubuntu versions)
    KUBIC_URL="https://download.opensuse.org/repositories/devel:/kubic:/libpod:/stable/xUbuntu_${VER}"
    
    if curl -s --head "$KUBIC_URL/Release" | head -n 1 | grep -q "200 OK"; then
        echo -e "${BLUE}Adding Kubic repository for latest Podman...${NC}"
        
        echo "deb $KUBIC_URL/ /" | \
            sudo tee /etc/apt/sources.list.d/devel:kubic:libpod:stable.list
        
        curl -fsSL "${KUBIC_URL}/Release.key" | \
            gpg --dearmor | \
            sudo tee /etc/apt/trusted.gpg.d/devel_kubic_libpod_stable.gpg > /dev/null
        
        sudo apt-get update
    else
        echo -e "${YELLOW}⚠ Kubic repository not available for Ubuntu ${VER}, using default repositories${NC}"
    fi
    
    # Install Podman
    sudo apt-get install -y podman
    
    echo -e "${GREEN}✓ Podman installed${NC}"
}

# Install on RHEL/CentOS/Fedora
install_rhel_fedora() {
    echo -e "${BLUE}Installing Podman on RHEL/CentOS/Fedora...${NC}"
    
    if [[ "$OS" == "fedora" ]]; then
        sudo dnf install -y podman jq
    else
        sudo yum install -y podman jq
    fi
    
    echo -e "${GREEN}✓ Podman installed${NC}"
}

# Install on macOS
install_macos() {
    echo -e "${BLUE}Installing Podman on macOS...${NC}"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew is not installed. Installing Homebrew first...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install Podman and jq
    brew install podman jq
    
    # Initialize Podman machine
    echo -e "${YELLOW}Initializing Podman machine...${NC}"
    podman machine init
    podman machine start
    
    echo -e "${GREEN}✓ Podman installed and machine started${NC}"
}

# Install podman-compose
install_podman_compose() {
    echo -e "${BLUE}Installing podman-compose...${NC}"
    
    # Check if already installed
    if command -v podman-compose &> /dev/null; then
        echo -e "${GREEN}✓ podman-compose is already installed${NC}"
        return 0
    fi
    
    # Try apt first (for Ubuntu/Debian)
    if command -v apt-get &> /dev/null; then
        if apt-cache show podman-compose &> /dev/null; then
            echo -e "${BLUE}Installing via apt...${NC}"
            sudo apt-get install -y podman-compose
            echo -e "${GREEN}✓ podman-compose installed${NC}"
            return 0
        fi
    fi
    
    # Try pipx (recommended for externally-managed Python environments)
    if command -v pipx &> /dev/null; then
        echo -e "${BLUE}Installing via pipx...${NC}"
        pipx install podman-compose
        echo -e "${GREEN}✓ podman-compose installed${NC}"
        return 0
    fi
    
    # Try pip with --user flag (installs to user's home directory)
    if command -v pip3 &> /dev/null; then
        echo -e "${BLUE}Installing via pip3 --user...${NC}"
        pip3 install --user podman-compose
        echo -e "${GREEN}✓ podman-compose installed${NC}"
        echo -e "${YELLOW}Note: Make sure ~/.local/bin is in your PATH${NC}"
        return 0
    elif command -v pip &> /dev/null; then
        echo -e "${BLUE}Installing via pip --user...${NC}"
        pip install --user podman-compose
        echo -e "${GREEN}✓ podman-compose installed${NC}"
        echo -e "${YELLOW}Note: Make sure ~/.local/bin is in your PATH${NC}"
        return 0
    fi
    
    # If all else fails
    echo -e "${YELLOW}⚠ Could not install podman-compose automatically.${NC}"
    echo "You can install it manually with one of these commands:"
    echo "  sudo apt install podman-compose         (if available)"
    echo "  pipx install podman-compose             (recommended)"
    echo "  pip3 install --user podman-compose      (user install)"
}

# Configure rootless Podman
configure_rootless() {
    echo -e "${BLUE}Configuring rootless Podman...${NC}"
    
    if [[ "$OS" != "macos" ]]; then
        # Enable user namespaces
        if [ -f /etc/sysctl.conf ]; then
            if ! grep -q "user.max_user_namespaces" /etc/sysctl.conf; then
                echo "user.max_user_namespaces=28633" | sudo tee -a /etc/sysctl.conf
                sudo sysctl -p
            fi
        fi
        
        # Set up subuid and subgid
        if ! grep -q "^$USER:" /etc/subuid; then
            echo "$USER:100000:65536" | sudo tee -a /etc/subuid
        fi
        
        if ! grep -q "^$USER:" /etc/subgid; then
            echo "$USER:100000:65536" | sudo tee -a /etc/subgid
        fi
        
        # Enable lingering for systemd
        if command -v loginctl &> /dev/null; then
            loginctl enable-linger $USER
        fi
        
        echo -e "${GREEN}✓ Rootless configuration complete${NC}"
    fi
}

# Verify installation
verify_installation() {
    echo -e "${BLUE}Verifying installation...${NC}"
    
    if command -v podman &> /dev/null; then
        PODMAN_VERSION=$(podman --version)
        echo -e "${GREEN}✓ $PODMAN_VERSION${NC}"
        
        # Test rootless
        if podman info --format '{{.Host.Security.Rootless}}' | grep -q true; then
            echo -e "${GREEN}✓ Rootless mode is enabled${NC}"
        else
            echo -e "${YELLOW}⚠ Running in rootful mode${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}✗ Podman installation failed${NC}"
        return 1
    fi
}

# Main installation
main() {
    detect_os
    
    echo "Detected OS: $OS"
    echo ""
    
    # Check if already installed
    SKIP_INSTALL=false
    if command -v podman &> /dev/null; then
        echo -e "${YELLOW}Podman is already installed: $(podman --version)${NC}"
        echo "This script can still install podman-compose and configure rootless mode."
        read -p "Skip Podman reinstallation and just configure? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            SKIP_INSTALL=true
        fi
    fi
    
    # Install based on OS (only if not skipping)
    if [ "$SKIP_INSTALL" = false ]; then
        case $OS in
            ubuntu|debian)
                install_ubuntu_debian
                ;;
            rhel|centos|fedora)
                install_rhel_fedora
                ;;
            macos)
                install_macos
                ;;
            *)
                echo -e "${RED}Unsupported OS: $OS${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${BLUE}Skipping Podman installation...${NC}"
    fi
    
    # Install podman-compose
    install_podman_compose
    
    # Configure rootless (skip for macOS)
    if [[ "$OS" != "macos" ]]; then
        configure_rootless
    fi
    
    # Verify installation
    if verify_installation; then
        echo ""
        echo "======================================"
        echo -e "${GREEN}✓ Installation Complete!${NC}"
        echo "======================================"
        echo ""
        echo "Next steps:"
        echo "1. Run 'podman info' to see your Podman configuration"
        echo "2. Run 'scripts/podman-dev.sh' to start development environment"
        echo "3. Visit: https://docs.podman.io for more information"
        echo ""
        
        if [[ "$OS" != "macos" ]]; then
            echo -e "${YELLOW}Note: You may need to log out and log back in for all changes to take effect.${NC}"
        fi
    else
        exit 1
    fi
}

# Run main installation
main

