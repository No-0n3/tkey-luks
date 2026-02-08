#!/bin/bash
# Build all components of TKey-LUKS
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== Building TKey-LUKS ==="
echo ""
echo "Project root: $PROJECT_ROOT"
echo ""

# Initialize submodules if needed
if [ ! -d "submodules/tkey-libs/.git" ]; then
    echo "[0/3] Initializing git submodules..."
    git submodule update --init --recursive
    echo ""
fi

# Build device app
echo "[1/3] Building device application..."
if [ -f "device-app/Makefile" ]; then
    cd "$PROJECT_ROOT/device-app"
    make clean || true
    make
    echo "✓ Device app built"
else
    echo "⚠ Device app Makefile not found, skipping"
fi
echo ""

# Build client
echo "[2/3] Building client application..."
if [ -f "$PROJECT_ROOT/client/Makefile" ]; then
    cd "$PROJECT_ROOT/client"
    make clean || true
    make
    echo "✓ Client built"
elif [ -f "$PROJECT_ROOT/client/go.mod" ]; then
    cd "$PROJECT_ROOT/client"
    go build -o tkey-luks-client
    echo "✓ Client built (Go)"
else
    echo "⚠ Client build system not found, skipping"
fi
echo ""

# Verify builds
echo "[3/3] Verifying builds..."
cd "$PROJECT_ROOT"

if [ -f "client/tkey-luks-client" ]; then
    CLIENT_BIN="client/tkey-luks-client"
    echo "✓ Client binary: $CLIENT_BIN"
    ls -lh "$CLIENT_BIN"
    echo ""
    
    # Check if statically linked (force English locale for consistent output)
    LDD_OUTPUT=$(LC_ALL=C ldd "$CLIENT_BIN" 2>&1)
    if echo "$LDD_OUTPUT" | grep -q "not a dynamic executable"; then
        echo "✓ Binary is statically linked"
    elif echo "$LDD_OUTPUT" | grep -q "statically linked"; then
        echo "✓ Binary is statically linked"
    else
        echo "⚠ Binary has dynamic dependencies:"
        echo "$LDD_OUTPUT" | head -10
    fi
else
    echo "⚠ Client binary not found"
fi
echo ""

if [ -f "device-app/tkey-luks-device.bin" ]; then
    echo "✓ Device app binary: device-app/tkey-luks-device.bin"
    ls -lh device-app/tkey-luks-device.bin
else
    echo "⚠ Device app binary not found"
fi
echo ""

echo "=== Build Complete ==="
echo ""
echo "Next steps:"
echo "  1. Test installation: sudo ./scripts/install.sh"
echo "  2. Or test in QEMU: ./test/qemu/create-vm.sh"
