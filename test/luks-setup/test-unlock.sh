#!/bin/bash
# Test LUKS unlock with password or TKey (using improved USS derivation)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_FILE="${1:-test-luks-100mb.img}"
USE_TKEY="${2:-yes}"
PASSWORD="${3:-test123}"

if [ ! -f "$IMAGE_FILE" ]; then
    echo "ERROR: Image file not found: $IMAGE_FILE"
    echo "Usage: $0 <image-file> [yes|no] [password]"
    echo "Create image first with: ./create-test-image.sh"
    exit 1
fi

echo "=== Testing LUKS Unlock (Improved USS Derivation) ==="
echo ""
echo "Image: $IMAGE_FILE"
echo "Mode: $([ "$USE_TKEY" = "yes" ] && echo "TKey (--derive-uss)" || echo "Password")"
echo ""

# Set up loop device
LOOP_DEV=$(sudo losetup -f --show "$IMAGE_FILE")
echo "Loop device: $LOOP_DEV"

# Test unlock
if [ "$USE_TKEY" = "yes" ]; then
    echo ""
    echo "Testing TKey unlock with improved USS derivation..."
    
    # Check if tkey-luks-client exists
    if ! command -v tkey-luks-client >/dev/null 2>&1; then
        echo "ERROR: tkey-luks-client not found in PATH"
        echo "Build it first: cd ../../client && make"
        sudo losetup -d "$LOOP_DEV"
        exit 1
    fi
    
    # Check if TKey is connected
    if [ ! -e /dev/ttyACM0 ]; then
        echo "ERROR: TKey not found at /dev/ttyACM0"
        echo "Please connect your TKey device"
        sudo losetup -d "$LOOP_DEV"
        exit 1
    fi
    
    echo "Deriving key from TKey..."
    echo "(Touch the TKey when it blinks)"
    echo ""
    
    # Derive key and unlock
    echo "$PASSWORD" | tkey-luks-client \
        --challenge-from-stdin \
        --derive-uss \
        --output - | \
    sudo cryptsetup luksOpen "$LOOP_DEV" test-unlock --key-file=-
else
    echo ""
    echo "Testing password unlock..."
    echo "Enter password (default: $PASSWORD):"
    sudo cryptsetup luksOpen "$LOOP_DEV" test-unlock
fi

# Mount and verify
if [ -e /dev/mapper/test-unlock ]; then
    echo ""
    echo "✓ LUKS unlock successful!"
    echo ""
    echo "Mounting filesystem..."
    MOUNT_POINT=$(mktemp -d)
    sudo mount /dev/mapper/test-unlock "$MOUNT_POINT"
    
    echo "Contents:"
    ls -la "$MOUNT_POINT"
    
    if [ -f "$MOUNT_POINT/README.txt" ]; then
        echo ""
        cat "$MOUNT_POINT/README.txt"
    fi
    
    # Cleanup
    echo ""
    echo "Cleaning up..."
    sudo umount "$MOUNT_POINT"
    rmdir "$MOUNT_POINT"
    sudo cryptsetup luksClose test-unlock
else
    echo ""
    echo "✗ LUKS unlock failed"
fi

sudo losetup -d "$LOOP_DEV"

echo ""
echo "=== Test Complete ==="
