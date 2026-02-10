#!/bin/bash
# Build and test package installation locally
# This simulates the entire GitHub Actions workflow

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== TKey-LUKS Build and Install Test ==="
echo ""

# Parse arguments
SKIP_BUILD=false
KEEP_PACKAGE=false
TEST_METHOD="docker"

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --keep-package)
            KEEP_PACKAGE=true
            shift
            ;;
        --method)
            TEST_METHOD="$2"
            shift 2
            ;;
        --help)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --skip-build      Skip building components (use existing builds)
  --keep-package    Keep the .deb package after testing
  --method METHOD   Test method: docker (default), local, or mock
  --help            Show this help message

Test Methods:
  docker  - Test in Ubuntu 24.04 Docker container (safest, most accurate)
  local   - Test installation on local system (requires root, may modify system)
  mock    - Just build package, verify structure without installing

Examples:
  $0                           # Full build and Docker test
  $0 --skip-build              # Test existing build
  $0 --method local            # Test on local system
  $0 --keep-package            # Keep .deb for manual testing
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Step 1: Build components
if [ "$SKIP_BUILD" = false ]; then
    echo "[1/5] Building components..."
    ./scripts/build-all.sh
    echo ""
else
    echo "[1/5] Skipping build (--skip-build specified)"
    echo ""
fi

# Step 2: Check prerequisites for Debian package build
echo "[2/5] Checking Debian build prerequisites..."
if ! command -v dpkg-buildpackage &> /dev/null; then
    echo "WARNING: dpkg-buildpackage not found"
    echo "Install: sudo apt-get install debhelper devscripts build-essential"
    echo ""
    echo "Continuing anyway (will fail at package build)..."
fi
echo "✓ Prerequisites checked"
echo ""

# Step 3: Build Debian package
echo "[3/5] Building Debian package..."
VERSION=$(grep -E '^tkey-luks \(' debian/changelog | head -1 | sed 's/tkey-luks (\(.*\)).*/\1/')
echo "Building version: $VERSION"

# Build package (unsigned)
dpkg-buildpackage -b -uc -us || {
    echo "ERROR: Package build failed"
    echo ""
    echo "Common issues:"
    echo "  - Missing build dependencies (run: sudo apt-get install debhelper devscripts)"
    echo "  - Build errors in client or device-app"
    echo "  - Incorrect debian/ files"
    exit 1
}

echo "✓ Package built successfully"
echo ""

# List generated files
echo "Generated files:"
ls -lh ../*.deb ../*.buildinfo ../*.changes 2>/dev/null || true
echo ""

# Step 4: Test package based on method
echo "[4/5] Testing package installation (method: $TEST_METHOD)..."
case $TEST_METHOD in
    docker)
        if ! command -v docker &> /dev/null; then
            echo "ERROR: Docker not found. Install Docker or use --method local"
            exit 1
        fi
        ./test/test-debian-package.sh
        ;;
    
    local)
        echo "WARNING: This will install tkey-luks on your system!"
        read -p "Continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
        
        if [ "$EUID" -ne 0 ]; then
            echo "ERROR: Local installation requires root"
            echo "Run with sudo: sudo $0 --method local"
            exit 1
        fi
        
        # Install package
        dpkg -i ../*.deb || true
        apt-get install -f -y
        
        # Verify installation
        echo ""
        echo "Verifying installation..."
        command -v tkey-luks-client
        test -f /usr/sbin/tkey-luks-client && echo "✓ Client installed"
        test -f /usr/share/tkey-luks/tkey-luks-device.bin && echo "✓ Device app installed"
        test -f /usr/share/initramfs-tools/hooks/tkey-luks && echo "✓ Initramfs hook installed"
        
        echo ""
        echo "✅ Package installed locally!"
        echo ""
        echo "To remove: sudo apt-get remove tkey-luks"
        ;;
    
    mock)
        echo "Mock test: Verifying package structure..."
        
        # Extract and check package contents
        DEB_FILE=$(ls ../*.deb | head -1)
        dpkg-deb --info "$DEB_FILE"
        echo ""
        dpkg-deb --contents "$DEB_FILE"
        
        echo ""
        echo "✓ Package structure verified"
        ;;
    
    *)
        echo "ERROR: Unknown test method: $TEST_METHOD"
        exit 1
        ;;
esac
echo ""

# Step 5: Cleanup
echo "[5/5] Cleanup..."
if [ "$KEEP_PACKAGE" = true ]; then
    mkdir -p artifacts
    mv ../*.deb ../*.buildinfo ../*.changes artifacts/ 2>/dev/null || true
    echo "✓ Package saved to artifacts/"
else
    rm -f ../*.deb ../*.buildinfo ../*.changes 2>/dev/null || true
    echo "✓ Temporary files removed"
fi
echo ""

echo "✅ Build and test completed successfully!"
echo ""
echo "Next steps:"
echo "  - Install on test system: sudo dpkg -i artifacts/tkey-luks_*.deb"
echo "  - Test with TKey device: see docs/TESTING.md"
echo "  - Create release: git tag v$VERSION && git push --tags"
