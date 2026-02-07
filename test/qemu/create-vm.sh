#!/bin/bash
# Create QEMU VM with LUKS encrypted root for testing TKey-LUKS
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="$SCRIPT_DIR/vm"
DISK_SIZE="10G"
DISK_IMAGE="$VM_DIR/test-vm.qcow2"
MOUNT_POINT="$VM_DIR/mnt"

echo "=== TKey-LUKS QEMU VM Creation ==="
echo ""

# Check dependencies
echo "[1/8] Checking dependencies..."
for cmd in qemu-img qemu-system-x86_64 cryptsetup debootstrap; do
    if ! command -v $cmd &> /dev/null; then
        echo "ERROR: $cmd not found. Please install required packages."
        exit 1
    fi
done

# Create VM directory
echo "[2/8] Creating VM directory..."
mkdir -p "$VM_DIR"
mkdir -p "$MOUNT_POINT"

# Create disk image
echo "[3/8] Creating disk image ($DISK_SIZE)..."
if [ -f "$DISK_IMAGE" ]; then
    read -p "Disk image exists. Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    rm -f "$DISK_IMAGE"
fi

qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"

# Set up loop device
echo "[4/8] Setting up loop device..."
LOOP_DEV=$(sudo losetup -f)
sudo losetup -P "$LOOP_DEV" "$DISK_IMAGE"

# Create partition table
echo "[5/8] Creating partition table..."
sudo parted -s "$LOOP_DEV" mklabel msdos
sudo parted -s "$LOOP_DEV" mkpart primary 1MiB 100%
sudo parted -s "$LOOP_DEV" set 1 boot on

# Wait for partition device
sleep 2
PART_DEV="${LOOP_DEV}p1"
if [ ! -e "$PART_DEV" ]; then
    # Try without 'p' (some systems)
    PART_DEV="${LOOP_DEV}1"
fi

# Set up LUKS encryption
echo "[6/8] Setting up LUKS encryption..."
echo "Using test password: 'test123' (for initial setup)"
echo -n "test123" | sudo cryptsetup luksFormat --type luks2 "$PART_DEV" -

# Open LUKS container
echo "Opening LUKS container..."
echo -n "test123" | sudo cryptsetup luksOpen "$PART_DEV" test-luks -

# Create filesystem
echo "[7/8] Creating ext4 filesystem..."
sudo mkfs.ext4 -L "test-root" /dev/mapper/test-luks

# Mount and install minimal system
echo "[8/8] Installing minimal system (this may take a while)..."
sudo mount /dev/mapper/test-luks "$MOUNT_POINT"

# Install minimal Debian system (change suite as needed)
echo "Running debootstrap (this will take several minutes)..."
sudo debootstrap --arch=amd64 stable "$MOUNT_POINT" http://deb.debian.org/debian

# Basic system configuration
echo "Configuring system..."
sudo chroot "$MOUNT_POINT" /bin/bash <<'CHROOT_EOF'
# Set root password
echo "root:test123" | chpasswd

# Configure hostname
echo "tkey-test-vm" > /etc/hostname

# Configure network
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Install required packages
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    grub-pc \
    cryptsetup \
    initramfs-tools \
    openssh-server \
    systemd-sysv

# Configure crypttab
echo "test-luks UUID=$(blkid -s UUID -o value /dev/vda1) none luks" > /etc/crypttab

# Install GRUB
grub-install /dev/vda
update-grub

CHROOT_EOF

# Cleanup
echo ""
echo "Cleaning up..."
sudo umount "$MOUNT_POINT"
sudo cryptsetup luksClose test-luks
sudo losetup -d "$LOOP_DEV"

echo ""
echo "=== VM Creation Complete ==="
echo ""
echo "VM disk image: $DISK_IMAGE"
echo "Test password: test123"
echo ""
echo "Next steps:"
echo "1. Build tkey-luks components: ../../scripts/build-all.sh"
echo "2. Install into VM: ./install-into-vm.sh"
echo "3. Run VM: ./run-vm.sh"
echo ""
echo "Note: TKey enrollment must be done after building tkey-luks client"
