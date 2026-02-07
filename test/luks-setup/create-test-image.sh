#!/bin/bash
# Create a LUKS encrypted test image for testing unlock mechanisms
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_FILE="${1:-test-luks.img}"
IMAGE_SIZE="${2:-100M}"
PASSWORD="${3:-testpassword}"

echo "=== Creating LUKS Test Image ==="
echo ""
echo "Parameters:"
echo "  Image: $IMAGE_FILE"
echo "  Size: $IMAGE_SIZE"
echo "  Password: $PASSWORD"
echo ""

# Create empty image file
echo "[1/5] Creating image file..."
dd if=/dev/zero of="$IMAGE_FILE" bs=1 count=0 seek="$IMAGE_SIZE" 2>/dev/null

# Set up loop device
echo "[2/5] Setting up loop device..."
LOOP_DEV=$(sudo losetup -f --show "$IMAGE_FILE")
echo "Loop device: $LOOP_DEV"

# Create LUKS container
echo "[3/5] Creating LUKS container..."
echo -n "$PASSWORD" | sudo cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha256 \
    --pbkdf argon2id \
    "$LOOP_DEV" -

# Open LUKS container
echo "[4/5] Opening LUKS container..."
echo -n "$PASSWORD" | sudo cryptsetup luksOpen "$LOOP_DEV" test-luks-image -

# Create filesystem
echo "[5/5] Creating ext4 filesystem..."
sudo mkfs.ext4 -L "test-luks" /dev/mapper/test-luks-image

# Create test content
echo "Creating test content..."
MOUNT_POINT=$(mktemp -d)
sudo mount /dev/mapper/test-luks-image "$MOUNT_POINT"
sudo sh -c "echo 'TKey-LUKS Test Image' > $MOUNT_POINT/README.txt"
sudo sh -c "date > $MOUNT_POINT/created.txt"
sudo umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

# Clean up
echo "Cleaning up..."
sudo cryptsetup luksClose test-luks-image
sudo losetup -d "$LOOP_DEV"

echo ""
echo "=== LUKS Test Image Created ==="
echo ""
echo "Image file: $IMAGE_FILE"
echo "Password: $PASSWORD"
echo ""
echo "LUKS information:"
sudo cryptsetup luksDump "$IMAGE_FILE" | head -20
echo "..."
echo ""
echo "To test unlock:"
echo "  sudo cryptsetup luksOpen $IMAGE_FILE test"
echo "  sudo mount /dev/mapper/test /mnt"
echo "  ls /mnt"
echo "  sudo umount /mnt"
echo "  sudo cryptsetup luksClose test"
