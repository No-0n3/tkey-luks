#!/bin/bash
# Add TKey-derived key to LUKS image
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_FILE="${1:-test-luks-100mb.img}"
KEYFILE="${2:-tkey-derived-key.bin}"

if [ ! -f "$IMAGE_FILE" ]; then
    echo "ERROR: Image file not found: $IMAGE_FILE"
    echo "Create it first with: ./create-tkey-test-image.sh"
    exit 1
fi

if [ ! -f "$KEYFILE" ]; then
    echo "ERROR: Key file not found: $KEYFILE"
    echo "Generate it first with: ./derive-tkey-key.py"
    exit 1
fi

echo "=== Adding TKey Key to LUKS Image ==="
echo ""
echo "Image: $IMAGE_FILE"
echo "Key file: $KEYFILE"
echo "Key size: $(stat -c%s "$KEYFILE") bytes"
echo ""

# Show current slots
echo "Current LUKS key slots:"
sudo cryptsetup luksDump "$IMAGE_FILE" | grep "Key Slot" | head -5
echo ""

echo "Adding TKey-derived key to slot 1..."
echo "(You'll need to enter the existing password: test123)"
echo ""

sudo cryptsetup luksAddKey "$IMAGE_FILE" "$KEYFILE"

echo ""
echo "✓ TKey key added successfully!"
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
