#!/bin/bash
# Install TKey-LUKS system-wide
set -e

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must run as root"
    echo "Usage: sudo $0"
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== Installing TKey-LUKS ==="
echo ""

# Check if built
CLIENT_BIN="client/tkey-luks-client"
if [ ! -f "$CLIENT_BIN" ]; then
    echo "ERROR: Client binary not found at $CLIENT_BIN"
    echo "Build first: ./scripts/build-all.sh"
    exit 1
fi

# Installation paths (matching individual Makefiles)
INSTALL_DIR="/usr/local/lib/tkey-luks"
BIN_DIR="/usr/local/bin"
HOOKS_DIR="/etc/initramfs-tools/hooks"
SCRIPTS_DIR="/etc/initramfs-tools/scripts/local-top"
CONFIG_DIR="/etc/tkey-luks"

# Create directories
echo "[1/6] Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$HOOKS_DIR"
mkdir -p "$SCRIPTS_DIR"

# Install client binary
echo "[2/6] Installing client binary..."
install -D -m 755 "$CLIENT_BIN" "$BIN_DIR/tkey-luks-client"
echo "✓ Installed: $BIN_DIR/tkey-luks-client"

# Install device app
echo "[3/6] Installing device application..."
if [ -f "device-app/tkey-luks-device.bin" ]; then
    install -D -m 644 "device-app/tkey-luks-device.bin" "$INSTALL_DIR/tkey-luks-device.bin"
    echo "✓ Installed: $INSTALL_DIR/tkey-luks-device.bin"
else
    echo "⚠ Device app not found, skipping"
fi

# Install initramfs hooks
echo "[4/6] Installing initramfs hooks..."
if [ -f "initramfs-hooks/hooks/tkey-luks" ]; then
    install -D -m 755 "initramfs-hooks/hooks/tkey-luks" "$HOOKS_DIR/tkey-luks"
    echo "✓ Installed: $HOOKS_DIR/tkey-luks"
else
    echo "⚠ Hook script not found, creating minimal version"
    cat > "$HOOKS_DIR/tkey-luks" <<'HOOK_EOF'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in
    prereqs) prereqs; exit 0;;
esac

. /usr/share/initramfs-tools/hook-functions

# Copy the binary
mkdir -p "${DESTDIR}/usr/local/bin"
cp -p /usr/local/bin/tkey-luks-client "${DESTDIR}/usr/local/bin/"
chmod +x "${DESTDIR}/usr/local/bin/tkey-luks-client"

# Copy device app
if [ -f /usr/local/lib/tkey-luks/tkey-luks-device.bin ]; then
    mkdir -p "${DESTDIR}/usr/local/lib/tkey-luks"
    cp /usr/local/lib/tkey-luks/tkey-luks-device.bin "${DESTDIR}/usr/local/lib/tkey-luks/"
fi

# Copy config if exists
if [ -f /etc/tkey-luks/config ]; then
    mkdir -p ${DESTDIR}/etc/tkey-luks
    cp /etc/tkey-luks/config ${DESTDIR}/etc/tkey-luks/
fi
HOOK_EOF
    chmod 755 "$HOOKS_DIR/tkey-luks"
fi

# Install boot script
echo "[5/6] Installing boot script..."
if [ -f "initramfs-hooks/scripts/local-top/00-tkey-luks" ]; then
    install -D -m 755 "initramfs-hooks/scripts/local-top/00-tkey-luks" "$SCRIPTS_DIR/00-tkey-luks"
    echo "✓ Installed: $SCRIPTS_DIR/00-tkey-luks"
else
    echo "⚠ Boot script not found, creating minimal version"
    cat > "$SCRIPTS_DIR/00-tkey-luks" <<'BOOT_EOF'
#!/bin/sh
PREREQ="cryptroot"
prereqs() { echo "$PREREQ"; }
case $1 in
    prereqs) prereqs; exit 0;;
esac

# TKey-LUKS unlock will be called by cryptroot hooks
# This is a placeholder for custom unlock logic
BOOT_EOF
    chmod 755 "$SCRIPTS_DIR/00-tkey-luks"
fi

# Install default config
echo "[6/6] Installing configuration..."
if [ ! -f "$CONFIG_DIR/config" ]; then
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/config" <<'CONFIG_EOF'
# TKey-LUKS Configuration

# Device app path
DEVICE_APP=/usr/local/lib/tkey-luks/tkey-luks-device.bin

# Timeout for TKey detection (seconds)
TIMEOUT=30

# Enable fallback to password
FALLBACK=yes

# Maximum unlock attempts
MAX_ATTEMPTS=3

# Debug logging
DEBUG=no
CONFIG_EOF
    echo "✓ Created: $CONFIG_DIR/config"
else
    echo "✓ Config exists: $CONFIG_DIR/config"
fi

# Update initramfs
echo ""
echo "Updating initramfs..."
update-initramfs -u

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed files:"
echo "  Binary: $BIN_DIR/tkey-luks-client"
echo "  Library: $INSTALL_DIR/"
echo "  Config: $CONFIG_DIR/config"
echo "  Hooks: $HOOKS_DIR/tkey-luks"
echo "  Scripts: $SCRIPTS_DIR/00-tkey-luks"
echo ""
echo "Next steps:"
echo "  1. Add TKey key to LUKS partition (see README.md)"
echo "  2. Update /etc/crypttab to add 'initramfs' option"
echo "  3. Test: ./test/qemu/run-vm.sh"
echo ""
echo "Documentation:"
echo "  Setup: docs/SETUP.md"
echo "  Security: docs/SECURITY.md"
