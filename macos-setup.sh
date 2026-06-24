#!/bin/bash

################################################################################
# Project Sakina - macOS Complete Setup
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

# Check if Homebrew is installed
check_homebrew() {
    print_header "Checking Homebrew"
    
    if ! command -v brew &> /dev/null; then
        print_warning "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        print_success "Homebrew installed"
    else
        print_success "Homebrew found"
    fi
}

# Install Git
install_git() {
    print_header "Installing Git"
    
    if command -v git &> /dev/null; then
        print_success "Git already installed: $(git --version)"
    else
        brew install git
        print_success "Git installed"
    fi
}

# Install Docker
install_docker() {
    print_header "Installing Docker Desktop"
    
    if command -v docker &> /dev/null; then
        print_success "Docker already installed: $(docker --version)"
    else
        print_warning "Docker Desktop not found. Installing via Homebrew..."
        brew install --cask docker
        print_success "Docker Desktop installed. Opening it..."
        open /Applications/Docker.app
        sleep 10
        print_warning "Please wait for Docker Desktop to fully start..."
    fi
}

# Install Rust
install_rust() {
    print_header "Installing Rust"
    
    if command -v cargo &> /dev/null; then
        print_success "Rust already installed: $(rustc --version)"
    else
        print_warning "Rust not found. Installing..."
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
        print_warning "Flutter not found. Installing..."
        brew install flutter
        flutter doctor
        print_success "Flutter installed"
    fi
}

# Install kubectl
install_kubectl() {
    print_header "Installing kubectl"
    
    if command -v kubectl &> /dev/null; then
        print_success "kubectl already installed: $(kubectl version --client --short)"
    else
        brew install kubectl
        print_success "kubectl installed"
    fi
}

# Install Make
install_make() {
    print_header "Installing Make"
    
    if command -v make &> /dev/null; then
        print_success "Make already installed"
    else
        # macOS usually comes with make, but just in case
        xcode-select --install 2>/dev/null || true
        print_success "Make available"
    fi
}

# Wait for Docker
wait_for_docker() {
    print_header "Waiting for Docker"
    
    local count=0
    while ! docker ps &> /dev/null; do
        count=$((count + 1))
        if [ $count -gt 60 ]; then
            print_error "Docker did not start within 60 seconds"
            print_warning "Please manually start Docker Desktop from Applications"
            exit 1
        fi
        echo "Waiting for Docker... ($count/60)"
        sleep 1
    done
    
    print_success "Docker is running"
}

# Setup project structure
setup_project() {
    print_header "Creating Project Structure"
    
    local project_dir="${1:-.}"
    
    # This will be done by the main setup-sakina.sh script
    print_success "Project structure setup delegated to setup-sakina.sh"
}

# Main setup
main() {
    print_header "Project Sakina - macOS Complete Setup"
    
    check_homebrew
    install_git
    install_docker
    wait_for_docker
    install_kubectl
    install_rust
    install_flutter
    install_make
    
    print_header "Prerequisites Installed!"
    
    echo -e "${GREEN}All prerequisites installed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Clone the project: git clone https://github.com/sakina-project/sakina-al.git"
    echo "2. Enter directory: cd SakinaAL"
    echo "3. Run setup script: ./setup-sakina.sh"
    echo "4. Follow the instructions"
    echo ""
}

main "$@"
