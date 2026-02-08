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
