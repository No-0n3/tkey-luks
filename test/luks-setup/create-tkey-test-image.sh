#!/bin/bash
# Create a 100MB LUKS test image for TKey-LUKS testing
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_FILE="${1:-test-luks-100mb.img}"
IMAGE_SIZE="100M"

echo "=== Creating TKey-LUKS Test Image ==="
echo ""
echo "Parameters:"
echo "  Image: $IMAGE_FILE"
echo "  Size: $IMAGE_SIZE"
echo ""

# Create empty image file
echo "[1/6] Creating 100MB image file..."
dd if=/dev/zero of="$IMAGE_FILE" bs=1M count=100 status=progress

# Set up loop device
echo ""
echo "[2/6] Setting up loop device..."
LOOP_DEV=$(sudo losetup -f --show "$IMAGE_FILE")
echo "Loop device: $LOOP_DEV"

# For testing, we'll use a simple test password initially
# Then we'll show how to add the TKey-derived key
TEST_PASSWORD="test123"

# Create LUKS container
echo ""
echo "[3/6] Creating LUKS2 container..."
echo -n "$TEST_PASSWORD" | sudo cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha512 \
    --pbkdf argon2id \
    --pbkdf-memory 65536 \
    --pbkdf-parallel 1 \
    "$LOOP_DEV" -

# Open LUKS container
echo ""
echo "[4/6] Opening LUKS container..."
echo -n "$TEST_PASSWORD" | sudo cryptsetup luksOpen "$LOOP_DEV" tkey-test -

# Create filesystem
echo ""
echo "[5/6] Creating ext4 filesystem..."
sudo mkfs.ext4 -L "tkey-luks-test" /dev/mapper/tkey-test >/dev/null 2>&1

# Create test content
echo ""
echo "[6/6] Creating test content..."
MOUNT_POINT=$(mktemp -d)
sudo mount /dev/mapper/tkey-test "$MOUNT_POINT"
sudo sh -c "echo '=== TKey-LUKS Test Image ===' > $MOUNT_POINT/README.txt"
sudo sh -c "echo 'Created: $(date)' >> $MOUNT_POINT/README.txt"
sudo sh -c "echo 'This image is for testing TKey-based LUKS unlock' >> $MOUNT_POINT/README.txt"
sudo sh -c "date > $MOUNT_POINT/timestamp.txt"
sudo sh -c "echo 'Testing TKey LUKS unlock...' > $MOUNT_POINT/test.txt"
sudo umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

# Clean up
echo "Cleaning up..."
sudo cryptsetup luksClose tkey-test
sudo losetup -d "$LOOP_DEV"

echo ""
echo "=== LUKS Test Image Created Successfully ==="
echo ""
echo "Image file: $IMAGE_FILE"
echo "Size: 100M"
echo "Initial password: $TEST_PASSWORD"
echo ""
echo "LUKS Header Information:"
sudo cryptsetup luksDump "$IMAGE_FILE" | head -25
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Add TKey key using improved USS derivation:"
echo "   ./add-tkey-key.sh $IMAGE_FILE $TEST_PASSWORD"
echo ""
echo "2. Test unlocking with TKey:"
echo "   ./test-unlock.sh $IMAGE_FILE"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Derive TKey key with:"
echo "   ./derive-tkey-key.sh"
echo ""
echo "2. Add TKey-derived key to LUKS slot 1:"
echo "   ./add-tkey-key.sh $IMAGE_FILE"
echo ""
echo "3. Test unlock with password:"
echo "   sudo cryptsetup luksOpen $IMAGE_FILE test"
echo "   (Password: $TEST_PASSWORD)"
echo ""
echo "4. Test unlock with TKey (when client is ready):"
echo "   sudo ../../client/tkey-luks-unlock $IMAGE_FILE"
echo ""
echo "Available LUKS key slots:"
sudo cryptsetup luksDump "$IMAGE_FILE" | grep "Key Slot"
echo ""

