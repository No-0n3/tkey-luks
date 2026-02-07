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
            clang \
            lld \
            llvm \
            golang \
            pkg-config \
            libusb-1.0-0-dev \
            cryptsetup \
            initramfs-tools \
            qemu-system-x86 \
            qemu-utils \
            debootstrap \
            git \
            curl
        
        echo "✓ Installed build tools and TKey dependencies"
        ;;
    
    fedora|rhel|centos)
        sudo dnf install -y \
            clang \
            lld \
            llvm \
            golang \
            make \
            pkgconfig \
            libusb-devel \
            cryptsetup \
            dracut \
            qemu-system-x86 \
            qemu-img \
            git \
            curl
        
        echo "✓ Installed build tools and TKey dependencies"
        ;;
    
    arch)
        sudo pacman -Sy --noconfirm \
            clang \
            lld \
            llvm \
            go \
            libusb \
            cryptsetup \
            mkinitcpio \
            qemu-system-x86 \
            gitt \
            go
        ;;
    
    *)clang, lld, llvm (version 15+ with riscv32 support)"
        echo "  - golang (version 1.20+)"
        echo "  - libusb-1.0-dev"
        echo "  - cryptsetup"
        echo "  - initramfs-tools or dracut"
        echo "  - qemu-system-x86"
        echo "  - git"
        echo ""
        echo "See https://dev.tillitis.se/tools/ for detailed instructionsptsetup"
        echo "  - initramfs-tools or dracut"
        echo "  - qemu-system-x86"
echo "Initializing TKey libraries and tools..."
if git submodule update --init --recursive; then
    echo "✓ Submodules initialized"
    
    # Build tkey-libs
    if [ -d "submodules/tkey-libs" ]; then
        echo ""
        echo "Building tkey-libs..."
        cd submodules/tkey-libs
        make
        cd ../..
        echo "✓ tkey-libs built"
    fi
    
    # Build tkey-devtools (needs Go)
    if [ -d "submodules/tkey-devtools" ] && command -v go &> /dev/null; then
        echo ""
        echo "Building tkey-devtools..."
        cd submodules/tkey-devtools
        make
        cd ../..
        echo "✓ tkey-devtools built (includes tkey-runapp)"
    figo &> /dev/null && [ -x "submodules/tkey-devtools/tkey-runapp" ]; then
    echo "✓ TKey tools ready (tkey-runapp found)"
elif command -v go &> /dev/null; then
    echo "⚠ tkey-runapp not built yet"
    echo "  Build with: cd submodules/tkey-devtools && make"
else
    echo "⚠ Go not installed - required for TKey client development"
    echo "  Install: sudo apt-get install golang (Ubuntu/Debian)"
fi

# Check for LLVM/Clang with riscv32 support
if command -v clang &> /dev/null; then
    CLANG_VERSION=$(clang --version | head -1 | grep -oP '\d+' | head -1)
    if [ "$CLANG_VERSION" -ge 15 ]; then
        echo "✓ Clang $CLANG_VERSION found (device app compilation ready)"
    else
        echo "⚠ Clang $CLANG_VERSION found (version 15+ recommended)"
    fi
else
    echo "⚠ Clang not found (required for device app development)
    ecTKey development:"
echo "  submodules/tkey-devtools/tkey-runapp  - Load and run device apps"
echo "  submodules/tkey-libs/                 - Device app libraries"
echo ""
echo "Next steps:"
echo "  1. Review PLAN.md for project overview"
echo "  2. Examine submodules/tkey-device-signer for reference"
echo "  3. Implement device app (device-app/src/)"
echo "  4. Implement client (client/main.go.example -> main.go)"
echo "  5. Test: ./test/luks-setup/create-test-image.sh"
echo ""
echo "Documentation:"
echo "  - PLAN.md: Implementation plan"
echo "  - docs/SECURITY.md: Security considerations"
echo "  - docs/TESTING.md: Testing guide"
echo "  - https://dev.tillitis.se/: TKey Developer Handbook
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
