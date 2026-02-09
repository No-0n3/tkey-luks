#!/bin/bash
# Add TKey-derived key to LUKS image (using improved USS derivation)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_FILE="${1:-test-luks-100mb.img}"
PASSWORD="${2:-test123}"

if [ ! -f "$IMAGE_FILE" ]; then
    echo "ERROR: Image file not found: $IMAGE_FILE"
    echo "Create it first with: ./create-tkey-test-image.sh"
    exit 1
fi

# Check if tkey-luks-client exists
if ! command -v tkey-luks-client >/dev/null 2>&1; then
    echo "ERROR: tkey-luks-client not found in PATH"
    echo "Build it first: cd ../../client && make"
    exit 1
fi

# Check if TKey is connected
if [ ! -e /dev/ttyACM0 ]; then
    echo "ERROR: TKey not found at /dev/ttyACM0"
    echo "Please connect your TKey device"
    exit 1
fi

echo "=== Adding TKey Key to LUKS Image (Improved USS Derivation) ==="
echo ""
echo "Image: $IMAGE_FILE"
echo "Using --derive-uss (password-based USS derivation)"
echo ""

# Show current slots
echo "Current LUKS key slots:"
sudo cryptsetup luksDump "$IMAGE_FILE" | grep "Key Slot" | head -5
echo ""

echo "Deriving key from TKey with improved USS..."
echo "(You'll need to touch the TKey when it blinks)"
echo ""

# Derive key using improved USS derivation and add to LUKS
echo "$PASSWORD" | tkey-luks-client \
    --challenge-from-stdin \
    --derive-uss \
    --output - | \
sudo cryptsetup luksAddKey "$IMAGE_FILE" -

echo ""
echo "✓ TKey key added successfully using improved USS derivation!"
echo ""

# Show updated slots
echo "Updated LUKS key slots:"
sudo cryptsetup luksDump "$IMAGE_FILE" | grep "Key Slot" | head -5
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test unlock with TKey key:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "sudo cryptsetup luksOpen $IMAGE_FILE test --key-file $KEYFILE"
echo ""
