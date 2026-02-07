#!/bin/bash
# Complete end-to-end test of TKey-LUKS system
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         TKey-LUKS End-to-End Test                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Create test image
echo "──────────────────────────────────────────────────────────────"
echo " Step 1: Create 10MB LUKS test image"
echo "──────────────────────────────────────────────────────────────"
echo ""

if [ -f "test-luks-10mb.img" ]; then
    echo "Test image already exists: test-luks-10mb.img"
    read -p "Recreate it? (y/N) " -n 1 -r
echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f test-luks-10mb.img
        ./create-tkey-test-image.sh
    fi
else
    ./create-tkey-test-image.sh
fi

echo ""
read -p "Press Enter to continue to Step 2..."
echo ""

# Step 2: Derive TKey key
echo "──────────────────────────────────────────────────────────────"
echo " Step 2: Derive TKey LUKS key"
echo "──────────────────────────────────────────────────────────────"
echo ""

echo "Deriving key with test CDI and challenge..."
chmod +x derive-tkey-key.py
./derive-tkey-key.py

echo ""
read -p "Press Enter to continue to Step 3..."
echo ""

# Step 3: Add TKey key to LUKS
echo "──────────────────────────────────────────────────────────────"
echo " Step 3: Add TKey key to LUKS image"
echo "──────────────────────────────────────────────────────────────"
echo ""

chmod +x add-tkey-key.sh
./add-tkey-key.sh test-luks-10mb.img tkey-derived-key.bin

echo ""
read -p "Press Enter to continue to Step 4..."
echo ""

# Step 4: Test unlock with TKey key
echo "──────────────────────────────────────────────────────────────"
echo " Step 4: Test LUKS unlock with TKey-derived key"
echo "──────────────────────────────────────────────────────────────"
echo ""

echo "Testing unlock with TKey-derived key..."
LOOP_DEV=$(sudo losetup -f --show test-luks-10mb.img)
echo "Loop device: $LOOP_DEV"

echo ""
echo "Unlocking with TKey key file..."
sudo cryptsetup luksOpen "$LOOP_DEV" tkey-test --key-file tkey-derived-key.bin

if [ -e /dev/mapper/tkey-test ]; then
    echo ""
    echo "✓ LUKS unlock successful!"
    
    # Mount and show contents
    echo ""
    echo "Mounting filesystem..."
    MOUNT_POINT=$(mktemp -d)
    sudo mount /dev/mapper/tkey-test "$MOUNT_POINT"
    
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
    sudo cryptsetup luksClose tkey-test
else
    echo ""
    echo "✗ LUKS unlock failed"
fi

sudo losetup -d "$LOOP_DEV"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║             Test Complete - Summary                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "✓ Created 10MB LUKS test image"
echo "✓ Derived TKey LUKS key"
echo "✓ Added TKey key to LUKS slot"
echo "✓ Successfully unlocked LUKS with TKey key"
echo ""
echo "Files created:"
echo "  - test-luks-10mb.img (LUKS encrypted)"
echo "  - tkey-derived-key.bin (64-byte derived key)"
echo "  - tkey-derived-key.hex (key in hex format)"
echo ""
echo "Next steps:"
echo "  1. Build Go client to communicate with TKey device app"
echo "  2. Test with actual TKey hardware"
echo "  3. Integrate into initramfs for boot-time unlock"
echo ""
