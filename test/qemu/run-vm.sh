#!/bin/bash
# Run TKey-LUKS test VM in QEMU
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="$SCRIPT_DIR/vm"
DISK_IMAGE="$VM_DIR/test-vm.qcow2"

# Default options
MEMORY="2G"
CPUS="2"
DISPLAY="-nographic"
SERIAL="-serial mon:stdio"
USB_OPTIONS=""
DEBUG=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --cpus)
            CPUS="$2"
            shift 2
            ;;
        --vnc)
            DISPLAY="-vnc $2"
            shift 2
            ;;
        --console)
            DISPLAY=""
            SERIAL="-serial mon:stdio"
            shift
            ;;
        --tkey-device)
            TKEY_DEV="$2"
            USB_OPTIONS="-usb -device usb-host,hostbus=${TKEY_DEV#/dev/bus/usb/},hostaddr=${TKEY_DEV##*/}"
            shift 2
            ;;
        --debug)
            DEBUG=1
            shift
            ;;
        --uefi)
            UEFI=1
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --memory SIZE       Set RAM size (default: 2G)"
            echo "  --cpus N            Set CPU count (default: 2)"
            echo "  --vnc DISPLAY       Use VNC display"
            echo "  --console           Use console output"
            echo "  --tkey-device DEV   Pass through specific TKey device"
            echo "  --debug             Enable debug output"
            echo "  --uefi              Use UEFI boot"
            echo "  --help              Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if disk image exists
if [ ! -f "$DISK_IMAGE" ]; then
    echo "ERROR: VM disk image not found: $DISK_IMAGE"
    echo "Please run ./create-vm.sh first"
    exit 1
fi

# Auto-detect TKey if not specified
if [ -z "$USB_OPTIONS" ]; then
    echo "Searching for TKey device..."
    # Look for Tillitis TKey (adjust vendor/product ID as needed)
    TKEY_DEV=$(lsusb | grep -i "Tillitis\|TKey" | head -1 | awk '{print $2,$4}' | tr -d ':')
    if [ -n "$TKEY_DEV" ]; then
        BUS=$(echo $TKEY_DEV | cut -d' ' -f1)
        ADDR=$(echo $TKEY_DEV | cut -d' ' -f2)
        USB_OPTIONS="-usb -device usb-host,hostbus=$BUS,hostaddr=$ADDR"
        echo "Found TKey at bus $BUS, address $ADDR"
    else
        echo "WARNING: No TKey device found"
        echo "VM will boot but LUKS unlock will require password fallback"
        USB_OPTIONS="-usb"
    fi
fi

# UEFI options
if [ "$UEFI" = "1" ]; then
    if [ -f /usr/share/ovmf/OVMF.fd ]; then
        BIOS_OPTIONS="-bios /usr/share/ovmf/OVMF.fd"
    elif [ -f /usr/share/edk2/ovmf/OVMF_CODE.fd ]; then
        BIOS_OPTIONS="-drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd"
    else
        echo "WARNING: OVMF not found, using BIOS boot"
        BIOS_OPTIONS=""
    fi
else
    BIOS_OPTIONS=""
fi

# Debug options
if [ "$DEBUG" = "1" ]; then
    DEBUG_OPTIONS="-d guest_errors -D $VM_DIR/qemu-debug.log"
else
    DEBUG_OPTIONS=""
fi

# Build QEMU command
QEMU_CMD="qemu-system-x86_64 \
    -m $MEMORY \
    -smp $CPUS \
    -drive file=$DISK_IMAGE,format=qcow2,if=virtio \
    -net nic,model=virtio \
    -net user,hostfwd=tcp::2222-:22 \
    $USB_OPTIONS \
    $BIOS_OPTIONS \
    $DISPLAY \
    $SERIAL \
    $DEBUG_OPTIONS \
    -enable-kvm"

echo "=== Starting TKey-LUKS Test VM ==="
echo ""
echo "Configuration:"
echo "  Memory: $MEMORY"
echo "  CPUs: $CPUS"
echo "  Disk: $DISK_IMAGE"
echo ""
echo "Network:"
echo "  SSH: ssh -p 2222 root@localhost"
echo ""
echo "Expected boot sequence:"
echo "  1. GRUB bootloader"
echo "  2. Kernel loads"
echo "  3. initramfs starts"
echo "  4. TKey-LUKS attempts unlock"
echo "  5. Root filesystem mounts"
echo "  6. System boots"
echo ""
echo "Press Ctrl+A then X to exit QEMU"
echo ""
echo "Starting VM..."
echo ""

# Run QEMU
$QEMU_CMD
