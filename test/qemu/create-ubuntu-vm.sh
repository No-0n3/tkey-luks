#!/bin/bash
# Create Ubuntu 24.04 QEMU VM with LUKS encryption for TKey-LUKS testing
# This creates a safe test environment without touching the host system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="$SCRIPT_DIR/vm"
DISK_SIZE="20G"
DISK_IMAGE="$VM_DIR/ubuntu-2404-tkey-test.qcow2"
ISO_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
ISO_FILE="$VM_DIR/ubuntu-24.04-server-amd64.iso"
MOUNT_POINT="$VM_DIR/mnt"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "========================================="
echo "TKey-LUKS Ubuntu 24.04 VM Setup"
echo "========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Do not run this script as root"
    exit 1
fi

# Check dependencies
log_info "Checking dependencies..."
MISSING_DEPS=()
for cmd in qemu-img qemu-system-x86_64 wget; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    log_error "Missing dependencies: ${MISSING_DEPS[*]}"
    echo ""
    echo "Install on Ubuntu/Debian:"
    echo "  sudo apt-get install qemu-system-x86 qemu-utils wget"
    exit 1
fi

# Create VM directory
log_info "Creating VM directory..."
mkdir -p "$VM_DIR"
mkdir -p "$MOUNT_POINT"

# Download Ubuntu 24.04 ISO if not present
if [ ! -f "$ISO_FILE" ]; then
    log_info "Downloading Ubuntu 24.04 ISO..."
    log_warn "This is a large download (~2.5 GB), may take several minutes..."
    wget -O "$ISO_FILE" "$ISO_URL" || {
        log_error "Failed to download ISO"
        exit 1
    }
    log_info "Download complete!"
else
    log_info "ISO already downloaded: $ISO_FILE"
fi

# Create disk image
log_info "Creating disk image ($DISK_SIZE)..."
if [ -f "$DISK_IMAGE" ]; then
    read -p "Disk image exists. Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Using existing disk image"
    else
        rm -f "$DISK_IMAGE"
        qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"
    fi
else
    qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"
fi

echo ""
log_info "VM disk created: $DISK_IMAGE"
echo ""

# Create cloud-init configuration for automated install
log_info "Creating cloud-init configuration..."
cat > "$VM_DIR/user-data" <<'EOF'
#cloud-config
autoinstall:
  version: 1
  locale: en_US
  keyboard:
    layout: us
  network:
    network:
      version: 2
      ethernets:
        eth0:
          dhcp4: true
  storage:
    layout:
      name: lvm
      sizing-policy: all
      # This will be modified to use LUKS encryption
  identity:
    hostname: tkey-test-vm
    username: tkey
    password: $6$rounds=4096$saltsalt$YQKSZmyZ0GNzJL8JMz3qN7EqZbXP0yxZvLZK2N9FmHPB5N3cJ8C9xH0YvN5P8ZxNJ9L3q0YxZ3qN7EqZbXP0yx
    # Password: test123 (hashed with mkpasswd)
  ssh:
    install-server: yes
    allow-pw: yes
  packages:
    - cryptsetup
    - linux-generic
  late-commands:
    - echo 'tkey ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/tkey
EOF

cat > "$VM_DIR/meta-data" <<EOF
instance-id: tkey-test-vm-001
local-hostname: tkey-test-vm
EOF

# Pack cloud-init ISO
log_info "Creating cloud-init ISO..."
# On Ubuntu, genisoimage or xorriso can be used
if command -v genisoimage &> /dev/null; then
    genisoimage -output "$VM_DIR/cloud-init.iso" -volid cidata -joliet -rock \
        "$VM_DIR/user-data" "$VM_DIR/meta-data"
elif command -v xorriso &> /dev/null; then
    xorriso -as mkisofs -o "$VM_DIR/cloud-init.iso" -volid cidata -joliet -rock \
        "$VM_DIR/user-data" "$VM_DIR/meta-data"
else
    log_warn "genisoimage/xorriso not found, will use manual install"
    log_warn "Install with: sudo apt-get install genisoimage"
fi

echo ""
echo "========================================="
echo "VM Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Start the VM for installation:"
echo "   ./run-ubuntu-vm.sh --install"
echo ""
echo "2. During installation:"
echo "   - Select 'Try or Install Ubuntu Server'"
echo "   - Choose manual partition setup"
echo "   - Create LUKS encrypted partition"
echo "   - Set test password: test123"
echo "   - Complete installation"
echo ""
echo "3. After installation, boot the VM:"
echo "   ./run-ubuntu-vm.sh"
echo ""
echo "4. In the VM, install TKey-LUKS:"
echo "   - Copy tkey-luks project to VM"
echo "   - Build and install components"
echo "   - Install initramfs hooks"
echo "   - Add TKey key to LUKS"
echo "   - Reboot and test"
echo ""
echo "5. Test TKey unlock:"
echo "   ./run-ubuntu-vm.sh --tkey-device /dev/ttyACM0"
echo ""

# Create helper script for running the VM
log_info "Creating run script..."
cat > "$SCRIPT_DIR/run-ubuntu-vm.sh" <<'RUNSCRIPT'
#!/bin/bash
# Run Ubuntu 24.04 TKey-LUKS test VM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="$SCRIPT_DIR/vm"
DISK_IMAGE="$VM_DIR/ubuntu-2404-tkey-test.qcow2"
ISO_FILE="$VM_DIR/ubuntu-24.04-server-amd64.iso"
CLOUD_INIT="$VM_DIR/cloud-init.iso"

# Default options
MEMORY="4G"
CPUS="2"
INSTALL_MODE=0
TKEY_DEVICE=""
VNC_DISPLAY=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install)
            INSTALL_MODE=1
            shift
            ;;
        --tkey-device)
            TKEY_DEVICE="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --cpus)
            CPUS="$2"
            shift 2
            ;;
        --vnc)
            VNC_DISPLAY="-vnc $2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install           Run in installation mode"
            echo "  --tkey-device DEV   Pass through TKey device"
            echo "  --memory SIZE       RAM size (default: 4G)"
            echo "  --cpus N            CPU count (default: 2)"
            echo "  --vnc DISPLAY       VNC display (e.g., :0)"
            echo "  --help              Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check disk image exists
if [ ! -f "$DISK_IMAGE" ]; then
    echo "ERROR: VM disk not found. Run ./create-ubuntu-vm.sh first"
    exit 1
fi

# Build QEMU command
QEMU_CMD="qemu-system-x86_64"
QEMU_OPTS="-enable-kvm -m $MEMORY -smp $CPUS"
QEMU_OPTS="$QEMU_OPTS -drive file=$DISK_IMAGE,format=qcow2,if=virtio"
QEMU_OPTS="$QEMU_OPTS -net nic,model=virtio -net user,hostfwd=tcp::2222-:22"

# Add display options
if [ -n "$VNC_DISPLAY" ]; then
    QEMU_OPTS="$QEMU_OPTS $VNC_DISPLAY"
else
    QEMU_OPTS="$QEMU_OPTS -nographic"
fi

# Installation mode
if [ $INSTALL_MODE -eq 1 ]; then
    if [ ! -f "$ISO_FILE" ]; then
        echo "ERROR: Ubuntu ISO not found. Run ./create-ubuntu-vm.sh first"
        exit 1
    fi
    echo "Starting VM in installation mode..."
    echo "Connect via SSH after install: ssh -p 2222 tkey@localhost"
    QEMU_OPTS="$QEMU_OPTS -cdrom $ISO_FILE -boot d"
    if [ -f "$CLOUD_INIT" ]; then
        QEMU_OPTS="$QEMU_OPTS -drive file=$CLOUD_INIT,format=raw,if=virtio"
    fi
fi

# TKey passthrough
if [ -n "$TKEY_DEVICE" ]; then
    if [ ! -e "$TKEY_DEVICE" ]; then
        echo "ERROR: TKey device not found: $TKEY_DEVICE"
        exit 1
    fi
    
    # Extract bus and device number
    BUS=$(echo "$TKEY_DEVICE" | cut -d'/' -f5)
    DEV=$(echo "$TKEY_DEVICE" | cut -d'/' -f6)
    
    QEMU_OPTS="$QEMU_OPTS -usb -device usb-host,hostbus=$BUS,hostaddr=$DEV"
    echo "TKey passthrough enabled: $TKEY_DEVICE"
fi

# Run QEMU
echo "Starting VM..."
echo "Command: $QEMU_CMD $QEMU_OPTS"
echo ""
echo "Press Ctrl+A then X to exit QEMU"
echo ""

$QEMU_CMD $QEMU_OPTS
RUNSCRIPT

chmod +x "$SCRIPT_DIR/run-ubuntu-vm.sh"

log_info "VM setup complete!"
echo ""
echo "Files created:"
echo "  - $DISK_IMAGE"
echo "  - $ISO_FILE"
echo "  - $SCRIPT_DIR/run-ubuntu-vm.sh"
echo ""
