#!/bin/bash
# Set up development environment for TKey-LUKS
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== TKey-LUKS Development Setup ==="
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
else
    OS="unknown"
fi

echo "Detected OS: $OS $OS_VERSION"
echo ""

# Install dependencies
echo "[1/4] Installing system dependencies..."
case $OS in
    ubuntu|debian)
        sudo apt-get update
        sudo apt-get install -y \
            build-essential \
            gcc \
            make \
            pkg-config \
            libusb-1.0-0-dev \
            cryptsetup \
            initramfs-tools \
            qemu-system-x86 \
            qemu-utils \
            debootstrap \
            git \
            curl
        
        # Optional: Rust for client development
        if ! command -v cargo &> /dev/null; then
            echo "Installing Rust..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
        fi
        ;;
    
    fedora|rhel|centos)
        sudo dnf install -y \
            gcc \
            make \
            pkgconfig \
            libusb-devel \
            cryptsetup \
            dracut \
            qemu-system-x86 \
            qemu-img \
            git \
            curl
        
        if ! command -v cargo &> /dev/null; then
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
        fi
        ;;
    
    arch)
        sudo pacman -Sy --noconfirm \
            base-devel \
            libusb \
            cryptsetup \
            mkinitcpio \
            qemu-system-x86 \
            git \
            rust
        ;;
    
    *)
        echo "Warning: Unknown OS, please install dependencies manually"
        echo "Required packages:"
        echo "  - build-essential (gcc, make)"
        echo "  - libusb-1.0-dev"
        echo "  - cryptsetup"
        echo "  - initramfs-tools or dracut"
        echo "  - qemu-system-x86"
        echo "  - git"
        ;;
esac

echo ""
echo "[2/4] Setting up git submodules..."
git submodule update --init --recursive || {
    echo "Warning: Failed to initialize submodules"
    echo "You may need to add correct Tillitis repository URLs to .gitmodules"
    echo ""
    echo "Expected repositories:"
    echo "  - tkey-libs: Core TKey libraries"
    echo "  - tkey-sign: Reference signing implementation"
    echo ""
    echo "Check https://github.com/tillitis for correct URLs"
}

echo ""
echo "[3/4] Creating development directories..."
mkdir -p build
mkdir -p test/qemu/vm
mkdir -p docs

echo ""
echo "[4/4] Checking TKey tools..."
if command -v tkey-runapp &> /dev/null; then
    echo "✓ TKey tools found"
else
    echo "⚠ TKey tools not found"
    echo "  Install Tillitis TKey SDK for hardware testing"
    echo "  Visit: https://dev.tillitis.se/"
fi

echo ""
echo "=== Development Environment Ready ==="
echo ""
echo "Available commands:"
echo "  ./scripts/build-all.sh       - Build all components"
echo "  ./scripts/install.sh         - Install system-wide"
echo "  ./test/qemu/create-vm.sh     - Create test VM"
echo "  ./test/qemu/run-vm.sh        - Run test VM"
echo ""
echo "Next steps:"
echo "  1. Review PLAN.md for project overview"
echo "  2. Check .gitmodules for correct submodule URLs"
echo "  3. Implement device app in device-app/src/"
echo "  4. Implement client in client/src/"
echo "  5. Run tests: ./test/luks-setup/create-test-image.sh"
echo ""
echo "Documentation:"
echo "  - PLAN.md: Implementation plan"
echo "  - docs/SECURITY.md: Security considerations"
echo "  - docs/TESTING.md: Testing guide"
