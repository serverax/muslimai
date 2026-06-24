#!/bin/bash

################################################################################
# Project Sakina - Linux (Ubuntu/Debian) Complete Setup
# Installs all prerequisites and initializes the project
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}══════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if running with sudo
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo "Please run: sudo $0"
        exit 1
    fi
}

# Update system
update_system() {
    print_header "Updating System"
    
    apt update
    apt upgrade -y
    
    print_success "System updated"
}

# Install Git
install_git() {
    print_header "Installing Git"
    
    if command -v git &> /dev/null; then
        print_success "Git already installed: $(git --version)"
    else
        apt install -y git
        print_success "Git installed"
    fi
}

# Install Docker
install_docker() {
    print_header "Installing Docker"
    
    if command -v docker &> /dev/null; then
        print_success "Docker already installed: $(docker --version)"
    else
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        
        # Add user to docker group
        if id "$SUDO_USER" &>/dev/null; then
            usermod -aG docker "$SUDO_USER"
            print_warning "Added $SUDO_USER to docker group. Please re-login."
        fi
        
        rm get-docker.sh
        print_success "Docker installed"
    fi
}

# Install kubectl
install_kubectl() {
    print_header "Installing kubectl"
    
    if command -v kubectl &> /dev/null; then
        print_success "kubectl already installed: $(kubectl version --client --short)"
    else
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
        print_success "kubectl installed"
    fi
}

# Install Rust
install_rust() {
    print_header "Installing Rust"
    
    if command -v cargo &> /dev/null; then
        print_success "Rust already installed: $(rustc --version)"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
        print_success "Rust installed"
    fi
}

# Install Flutter
install_flutter() {
    print_header "Installing Flutter"
    
    if command -v flutter &> /dev/null; then
        print_success "Flutter already installed: $(flutter --version)"
    else
        apt install -y git curl build-essential libssl-dev libffi-dev python3-dev
        
        git clone https://github.com/flutter/flutter.git -b stable --depth 1 /opt/flutter
        export PATH="$PATH:/opt/flutter/bin"
        
        echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bashrc
        source ~/.bashrc
        
        flutter doctor
        print_success "Flutter installed"
    fi
}

# Install Make
install_make() {
    print_header "Installing Make"
    
    if command -v make &> /dev/null; then
        print_success "Make already installed"
    else
        apt install -y build-essential
        print_success "Make installed"
    fi
}

# Main setup
main() {
    print_header "Project Sakina - Linux (Ubuntu/Debian) Complete Setup"
    
    check_sudo
    update_system
    install_git
    install_docker
    install_kubectl
    install_rust
    install_flutter
    install_make
    
    print_header "Prerequisites Installed!"
    
    echo -e "${GREEN}All prerequisites installed successfully!${NC}"
    echo ""
    echo "Important: Please logout and login again for Docker group changes to take effect"
    echo ""
    echo "Next steps:"
    echo "1. Logout and login: exit"
    echo "2. Verify Docker: docker ps"
    echo "3. Clone project: git clone https://github.com/sakina-project/sakina-al.git"
    echo "4. Enter directory: cd SakinaAL"
    echo "5. Run setup: chmod +x setup-sakina.sh && ./setup-sakina.sh"
    echo ""
}

main "$@"
