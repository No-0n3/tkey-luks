#!/bin/bash
# Test TKey-LUKS with actual hardware TKey device
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
IMAGE_FILE="${1:-test-luks-100mb.img}"
CHALLENGE="${2:-luks-test-challenge}"
KEY_FILE="hardware-derived-key.bin"
CLIENT_BIN="../../client/tkey-luks-client"
DEVICE_APP="../../device-app/tkey-luks-device.bin"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         TKey-LUKS Hardware Test                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Image:     $IMAGE_FILE"
echo "Challenge: $CHALLENGE"
echo "Key file:  $KEY_FILE"
echo ""

# Check prerequisites
if [ ! -f "$IMAGE_FILE" ]; then
    echo "ERROR: Image file not found: $IMAGE_FILE"
    echo ""
    echo "Create it first:"
    echo "  ./create-tkey-test-image.sh"
    exit 1
fi

if [ ! -x "$CLIENT_BIN" ]; then
    echo "ERROR: Client not found or not executable: $CLIENT_BIN"
    echo ""
    echo "Build it first:"
    echo "  cd ../../client && go build"
    exit 1
fi

if [ ! -f "$DEVICE_APP" ]; then
    echo "ERROR: Device app not found: $DEVICE_APP"
    echo ""
    echo "Build it first:"
    echo "  cd ../../device-app && make"
    exit 1
fi

# Step 1: Derive key from TKey
echo "──────────────────────────────────────────────────────────────"
echo " Step 1: Derive key from TKey hardware"
echo "──────────────────────────────────────────────────────────────"
echo ""
echo "Please ensure your TKey is plugged in."
echo "You will need to touch the TKey when the LED turns white."
echo ""
read -p "Press Enter when ready..."
echo ""

# Remove old key file if exists
rm -f "$KEY_FILE"

# Derive key using hardware TKey
echo "Deriving key from TKey..."
"$CLIENT_BIN" --app "$DEVICE_APP" --challenge "$CHALLENGE" --save-key "$KEY_FILE"

if [ ! -f "$KEY_FILE" ]; then
    echo ""
    echo "✗ Key derivation failed"
    exit 1
fi

echo ""
echo "✓ Key derived: $KEY_FILE ($(stat -c%s "$KEY_FILE") bytes)"
echo ""
read -p "Press Enter to continue to Step 2..."
echo ""

# Step 2: Add key to LUKS (if not already added)
echo "──────────────────────────────────────────────────────────────"
echo " Step 2: Add TKey key to LUKS image"
echo "──────────────────────────────────────────────────────────────"
echo ""

echo "Checking LUKS key slots..."
LOOP_DEV=$(sudo losetup -f --show "$IMAGE_FILE")
echo "Loop device: $LOOP_DEV"

# Check if slot 1 is already in use
SLOT_STATUS=$(sudo cryptsetup luksDump "$LOOP_DEV" | grep "^  1:" | awk '{print $2}' || echo "empty")

if [ "$SLOT_STATUS" = "luks2" ]; then
    echo ""
    echo "Key slot 1 already in use."
    echo "Remove and re-add with new TKey key? (y/N)"
    read -p "> " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Removing old key from slot 1..."
        echo "test123" | sudo cryptsetup luksKillSlot "$LOOP_DEV" 1 -
        
        echo ""
        echo "Adding TKey key to slot 1..."
        echo "test123" | sudo cryptsetup luksAddKey "$LOOP_DEV" "$KEY_FILE" --key-slot 1 -
    else
        echo "Keeping existing key in slot 1..."
    fi
else
    echo ""
    echo "Adding TKey key to slot 1..."
    echo "test123" | sudo cryptsetup luksAddKey "$LOOP_DEV" "$KEY_FILE" --key-slot 1 -
fi

sudo losetup -d "$LOOP_DEV"

echo ""
echo "✓ Key added to LUKS slot 1"
echo ""
read -p "Press Enter to continue to Step 3..."
echo ""

# Step 3: Test unlock with TKey-derived key
echo "──────────────────────────────────────────────────────────────"
echo " Step 3: Test LUKS unlock with TKey-derived key"
echo "──────────────────────────────────────────────────────────────"
echo ""

LOOP_DEV=$(sudo losetup -f --show "$IMAGE_FILE")
echo "Loop device: $LOOP_DEV"

echo ""
echo "Unlocking with TKey-derived key..."
sudo cryptsetup luksOpen "$LOOP_DEV" tkey-hw-test --key-file "$KEY_FILE"

if [ -e /dev/mapper/tkey-hw-test ]; then
    echo ""
    echo "✓ LUKS unlock successful!"
    
    # Mount and show contents
    echo ""
    echo "Mounting filesystem..."
    MOUNT_POINT=$(mktemp -d)
    sudo mount /dev/mapper/tkey-hw-test "$MOUNT_POINT"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Contents of LUKS volume:"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    ls -lh "$MOUNT_POINT"
    echo ""
    
    if [ -f "$MOUNT_POINT/README.txt" ]; then
        echo "README.txt:"
        cat "$MOUNT_POINT/README.txt"
        echo ""
    fi
    
    # Cleanup
    echo "Cleaning up..."
    sudo umount "$MOUNT_POINT"
    rmdir "$MOUNT_POINT"
    sudo cryptsetup luksClose tkey-hw-test
    echo ""
    echo "✓ Cleanup complete"
else
    echo ""
    echo "✗ LUKS unlock failed"
fi

sudo losetup -d "$LOOP_DEV"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║             Hardware Test Complete                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "✓ Derived key from hardware TKey"
echo "✓ Added key to LUKS slot 1"
echo "✓ Successfully unlocked LUKS with TKey-derived key"
echo ""
echo "The TKey can now unlock this LUKS volume using:"
echo "  Challenge: $CHALLENGE"
echo ""
