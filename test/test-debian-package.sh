#!/bin/bash
# Test Debian package installation locally using Docker
# This simulates the test-package job from GitHub Actions

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== TKey-LUKS Debian Package Test ==="
echo ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    echo "Install Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

# Check if package exists
DEB_PACKAGE=$(ls ../tkey-luks_*.deb 2>/dev/null | head -1)
if [ -z "$DEB_PACKAGE" ]; then
    echo "ERROR: No .deb package found in parent directory"
    echo "Build the package first:"
    echo "  cd $PROJECT_ROOT"
    echo "  dpkg-buildpackage -b -uc -us"
    exit 1
fi

DEB_BASENAME=$(basename "$DEB_PACKAGE")
echo "Testing package: $DEB_BASENAME"
echo ""

# Create test Dockerfile
echo "[1/4] Creating test environment..."
cat > /tmp/tkey-luks-test.dockerfile <<'EOF'
FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    cryptsetup \
    initramfs-tools \
    udev \
    file \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy package
COPY *.deb /tmp/

WORKDIR /tmp
EOF

# Build test image
echo "[2/4] Building Docker test image..."
docker build -t tkey-luks-test -f /tmp/tkey-luks-test.dockerfile "$(dirname "$DEB_PACKAGE")" || {
    echo "ERROR: Failed to build Docker image"
    exit 1
}

# Run installation test
echo ""
echo "[3/4] Testing package installation..."
docker run --rm tkey-luks-test bash -c '
set -e
echo "Installing package..."
dpkg -i /tmp/*.deb || true
apt-get install -f -y

echo ""
echo "Verifying installation..."

# Check binary
if ! command -v tkey-luks-client >/dev/null; then
    echo "ERROR: tkey-luks-client not found in PATH"
    exit 1
fi
echo "✓ Binary: $(which tkey-luks-client)"

# Check files
test -f /usr/sbin/tkey-luks-client && echo "✓ Client binary installed"
test -f /usr/share/tkey-luks/tkey-luks-device.bin && echo "✓ Device app installed"
test -f /usr/share/initramfs-tools/hooks/tkey-luks && echo "✓ Initramfs hook installed"
test -f /usr/share/initramfs-tools/scripts/local-top/00-tkey-luks && echo "✓ Initramfs script installed"

# Check documentation
if [ ! -f /usr/share/doc/tkey-luks/USS-DERIVATION.md ] && [ ! -f /usr/share/doc/tkey-luks/docs/USS-DERIVATION.md ]; then
    echo "ERROR: USS-DERIVATION.md not found"
    ls -la /usr/share/doc/tkey-luks/ || true
    exit 1
fi
echo "✓ Documentation installed"

# Check permissions
test -x /usr/sbin/tkey-luks-client && echo "✓ Client is executable"
test -x /usr/share/initramfs-tools/hooks/tkey-luks && echo "✓ Hook is executable"
test -x /usr/share/initramfs-tools/scripts/local-top/00-tkey-luks && echo "✓ Script is executable"

echo ""
echo "Running tkey-luks-client --version..."
/usr/sbin/tkey-luks-client --version || echo "(Version not available)"

echo ""
echo "Package contents:"
dpkg -L tkey-luks | head -20

echo ""
echo "✅ All package installation tests passed!"
' || {
    echo ""
    echo "❌ Package installation test FAILED"
    exit 1
}

# Cleanup
echo ""
echo "[4/4] Cleanup..."
docker rmi tkey-luks-test >/dev/null 2>&1 || true
rm -f /tmp/tkey-luks-test.dockerfile

echo ""
echo "✅ Package test completed successfully!"
echo ""
echo "To test package removal:"
echo "  docker run --rm tkey-luks-test bash -c 'dpkg -i /tmp/*.deb && apt-get remove -y tkey-luks'"
