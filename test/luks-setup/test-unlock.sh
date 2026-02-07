#!/bin/bash
# Test LUKS unlock with password or TKey
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_FILE="${1:-test-luks.img}"
USE_TKEY="${2:-no}"

if [ ! -f "$IMAGE_FILE" ]; then
    echo "ERROR: Image file not found: $IMAGE_FILE"
    echo "Usage: $0 <image-file> [yes|no]"
    echo "Create image first with: ./create-test-image.sh"
    exit 1
fi

echo "=== Testing LUKS Unlock ==="
echo ""
echo "Image: $IMAGE_FILE"
echo "Mode: $([ "$USE_TKEY" = "yes" ] && echo "TKey" || echo "Password")"
echo ""

# Set up loop device
LOOP_DEV=$(sudo losetup -f --show "$IMAGE_FILE")
echo "Loop device: $LOOP_DEV"

# Test unlock
if [ "$USE_TKEY" = "yes" ]; then
    echo ""
    echo "Testing TKey unlock..."
    
    # Check if tkey-luks-unlock exists
    if [ -x "../../client/tkey-luks-unlock" ]; then
        echo "Running tkey-luks-unlock..."
        sudo ../../client/tkey-luks-unlock "$LOOP_DEV" test-unlock
    else
        echo "ERROR: tkey-luks-unlock not found"
        echo "Build it first: cd ../../client && make"
        sudo losetup -d "$LOOP_DEV"
        exit 1
    fi
else
    echo ""
    echo "Testing password unlock..."
    echo "Enter password (default: testpassword):"
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
