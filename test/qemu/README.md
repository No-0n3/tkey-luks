# TKey-LUKS QEMU/KVM Testing

This directory contains scripts for safely testing TKey-LUKS in a virtual machine before deploying to production.

## Overview

Testing in a VM provides:
- **Safety:** No risk to your actual system
- **Repeatability:** Easy to reset and retry
- **TKey Passthrough:** Real hardware testing in isolated environment
- **Fast Iteration:** Quick cycle for testing changes

## Quick Start

```bash
# 1. Create Ubuntu 24.04 VM with LUKS encryption
sudo ./create-ubuntu-vm.sh

# 2. Install Ubuntu in VM (with LUKS encryption)
./run-ubuntu-vm.sh --install

# 3. Boot VM and set up TKey-LUKS
./run-ubuntu-vm.sh

# 4. Test TKey unlock with passthrough
./run-ubuntu-vm.sh --tkey-device /dev/ttyACM0
```

## VM Creation

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get install qemu-system-x86 qemu-utils wget genisoimage

# Fedora/RHEL
sudo dnf install qemu-kvm qemu-img wget genisoimage
```

### Create VM

```bash
./create-ubuntu-vm.sh
```

This script:
1. Downloads Ubuntu 24.04 Server ISO (~2.5 GB)
2. Creates 20GB qcow2 disk image
3. Creates cloud-init configuration for automated setup
4. Generates helper script `run-ubuntu-vm.sh`

**Files created:**
- `vm/ubuntu-2404-tkey-test.qcow2` - VM disk (20 GB, sparse)
- `vm/ubuntu-24.04-server-amd64.iso` - Ubuntu installer ISO
- `vm/cloud-init.iso` - Automated configuration
- `run-ubuntu-vm.sh` - Helper script to run VM

## Ubuntu Installation in VM

### Manual Installation (Recommended for LUKS)

```bash
# Start VM in installation mode
./run-ubuntu-vm.sh --install
```

**During installation:**

1. **Boot Menu:**
   - Select "Try or Install Ubuntu Server"

2. **Language & Keyboard:**
   - Choose your preferences

3. **Network:**
   - Accept DHCP configuration

4. **Storage Configuration:**
   - Select "Custom storage layout"
   - Create partition table:
     - `/boot` - 1 GB ext4 (unencrypted)
     - `/` - Remaining space, **encrypted with LUKS**
   - Set LUKS passphrase: `test123` (for testing)

5. **Profile:**
   - Name: TKey Test User
   - Server name: tkey-test-vm
   - Username: `tkey`
   - Password: `test123`

6. **SSH:**
   - Install OpenSSH server
   - Allow password authentication

7. **Packages:**
   - Select "none" for now (we'll install manually)

8. **Complete Installation:**
   - Wait for installation to finish
   - Reboot

### Boot the VM

```bash
# After installation completes
./run-ubuntu-vm.sh
```

**Login:**
- Username: `tkey`
- Password: `test123`

### Access VM via SSH

```bash
# VM forwards port 22 to host port 2222
ssh -p 2222 tkey@localhost
```

## Installing TKey-LUKS in VM

### Method 1: Copy Project to VM

```bash
# On host: Create tarball
cd /path/to/tkey-luks
tar czf /tmp/tkey-luks.tar.gz \
    --exclude='.git' \
    --exclude='*.o' \
    --exclude='*.bin' \
    --exclude='test/qemu/vm' \
    .

# Copy to VM via SCP
scp -P 2222 /tmp/tkey-luks.tar.gz tkey@localhost:~/

# In VM: Extract and build
ssh -p 2222 tkey@localhost
tar xzf tkey-luks.tar.gz
cd tkey-luks/
```

### Method 2: Clone from GitHub (if published)

```bash
# In VM
git clone https://github.com/YOUR_USERNAME/tkey-luks.git
cd tkey-luks/
```

### Build and Install Components

```bash
# In VM

# 1. Install dependencies
sudo apt-get update
sudo apt-get install -y \
    golang \
    clang \
    lld \
    llvm \
    make \
    git \
    cryptsetup

# 2. Initialize submodules
git submodule update --init --recursive

# 3. Build and install device app
cd device-app/
./build.sh
sudo make install
cd ..

# 4. Build and install client
cd client/
make
sudo make install
cd ..

# 5. Install initramfs hooks
cd initramfs-hooks/
sudo make install
sudo make update-initramfs
cd ..
```

### Add TKey Key to LUKS

```bash
# In VM

# Find your LUKS partition
sudo lsblk

# Usually /dev/vda2 for VM
LUKS_DEV="/dev/vda2"

# Derive key with TKey (requires TKey passthrough)
echo "my secret challenge" | \
  sudo tkey-luks-client --challenge-from-stdin | \
  sudo cryptsetup luksAddKey $LUKS_DEV

# You'll be prompted for existing LUKS password first
```

### Reboot and Test

```bash
# In VM
sudo reboot
```

The VM will:
1. Start booting
2. Detect LUKS partition
3. Run TKey-LUKS script
4. Prompt for "TKey challenge"
5. Wait for TKey (requires passthrough!)
6. Derive key and unlock

## TKey Passthrough

To test actual TKey hardware in the VM, you need USB passthrough.

### Find TKey Device

```bash
# On host
lsusb | grep -i tillitis
# Output: Bus 001 Device 005: ID 10c4:ea60 Tillitis TKey

# Or check serial device
ls -l /dev/ttyACM*
```

### Run VM with TKey Passthrough

```bash
# Pass TKey to VM
./run-ubuntu-vm.sh --tkey-device /dev/ttyACM0
```

**In VM, verify TKey is visible:**
```bash
lsusb | grep -i tillitis
ls -l /dev/ttyACM0
```

### Test TKey Communication

```bash
# In VM, test client can communicate
tkey-luks-client --verbose

# Should show:
# - TKey detected
# - Device app loaded
# - Public key derived
# - Key derivation successful
```

## Testing Scenarios

### Test 1: Manual Key Derivation

```bash
# In VM
echo "test challenge" | tkey-luks-client --challenge-from-stdin > /tmp/key.bin

# Check key was derived (should be 64 bytes)
ls -l /tmp/key.bin
# Output: -rw------- 1 tkey tkey 64 Feb  8 13:00 /tmp/key.bin

# Clean up
shred -u /tmp/key.bin
```

### Test 2: LUKS Unlock Test

```bash
# In VM (assumes TKey key was added)

# Create test LUKS device
sudo dd if=/dev/zero of=/tmp/test.img bs=1M count=100
sudo cryptsetup luksFormat /tmp/test.img
# Set password: test123

# Add TKey key
echo "test challenge" | tkey-luks-client --challenge-from-stdin | \
  sudo cryptsetup luksAddKey /tmp/test.img

# Test TKey unlock
echo "test challenge" | tkey-luks-client --challenge-from-stdin | \
  sudo cryptsetup luksOpen /tmp/test.img test_device

# Verify it worked
ls -l /dev/mapper/test_device

# Clean up
sudo cryptsetup luksClose test_device
sudo rm /tmp/test.img
```

### Test 3: Boot Unlock (Full Test)

```bash
# In VM with TKey passthrough

# 1. Ensure TKey key is in LUKS slot
echo "my challenge" | tkey-luks-client --challenge-from-stdin | \
  sudo cryptsetup luksAddKey /dev/vda2

# 2. Verify initramfs has TKey-LUKS
sudo lsinitramfs /boot/initrd.img-$(uname -r) | grep tkey-luks

# 3. Reboot
sudo reboot

# 4. At boot prompt:
#    - Enter "my challenge"
#    - Touch TKey when LED blinks
#    - System should unlock and boot
```

### Test 4: Fallback to Password

```bash
# In VM, reboot without TKey passthrough
# ./run-ubuntu-vm.sh (no --tkey-device)

# At boot prompt:
# - Type "skip" or wait for timeout
# - Standard password prompt will appear
# - Enter LUKS password: test123
# - System boots normally
```

## Debugging in VM

### Access the Initramfs Shell

If boot fails, you can access the initramfs shell to debug:

```bash
# Add to kernel command line (edit GRUB)
break=top
```

In the initramfs shell:
```bash
# Check if TKey is present
ls -l /dev/ttyACM*

# Check if binaries are available
ls -l /usr/local/bin/tkey-luks-client
ls -l /usr/local/lib/tkey-luks/tkey-luks-device.bin

# Test TKey manually
/usr/local/bin/tkey-luks-client --verbose

# Exit shell to continue boot
exit
```

### View Boot Logs

After successful boot:
```bash
# In VM
journalctl -b | grep -i tkey
dmesg | grep -i tkey
```

### Test Script Directly

```bash
# In VM, simulate initramfs environment
sudo sh -x /etc/initramfs-tools/scripts/local-top/tkey-luks
```

## VM Management

### Snapshot VM

Before making changes, create a snapshot:
```bash
qemu-img snapshot -c presnapshot vm/ubuntu-2404-tkey-test.qcow2
```

Restore if something breaks:
```bash
qemu-img snapshot -a presnapshot vm/ubuntu-2404-tkey-test.qcow2
```

### Reset VM

Start over with fresh install:
```bash
rm -rf vm/
./create-ubuntu-vm.sh
./run-ubuntu-vm.sh --install
```

### Clean Up

Remove all VM files:
```bash
rm -rf vm/
rm -f run-ubuntu-vm.sh
```

## Performance Tips

### Enable KVM Acceleration

KVM is automatically used if available. Verify:
```bash
# Check KVM support
lsmod | grep kvm

# If not loaded, load module
sudo modprobe kvm-intel  # Intel CPUs
# or
sudo modprobe kvm-amd    # AMD CPUs
```

Add user to kvm group:
```bash
sudo usermod -a -G kvm $USER
# Log out and back in
```

### Adjust CPU/Memory

```bash
# More resources for faster builds
./run-ubuntu-vm.sh --memory 8G --cpus 4
```

## Troubleshooting

### VM Won't Boot

**Problem:** VM hangs or shows errors

**Solutions:**
1. Check disk image exists:
   ```bash
   ls -l vm/ubuntu-2404-tkey-test.qcow2
   ```

2. Check disk isn't corrupted:
   ```bash
   qemu-img check vm/ubuntu-2404-tkey-test.qcow2
   ```

3. Try with VNC instead of console:
   ```bash
   ./run-ubuntu-vm.sh --vnc :0
   # Connect with VNC client to localhost:5900
   ```

### TKey Not Visible in VM

**Problem:** TKey passthrough not working

**Solutions:**
1. Check TKey is visible on host:
   ```bash
   lsusb | grep -i tillitis
   ls -l /dev/ttyACM0
   ```

2. Check permissions:
   ```bash
   sudo chmod 666 /dev/ttyACM0
   ```

3. Try different USB port

4. Check QEMU USB options:
   ```bash
   # Manual command with USB passthrough
   qemu-system-x86_64 -usb \
     -device usb-host,vendorid=0x10c4,productid=0xea60
   ```

### SSH Connection Refused

**Problem:** Can't SSH to VM

**Solutions:**
1. Check VM is running:
   ```bash
   ps aux | grep qemu
   ```

2. Wait for VM to fully boot (can take 1-2 minutes)

3. Check SSH service in VM (via console):
   ```bash
   systemctl status ssh
   ```

4. Verify port forwarding:
   ```bash
   netstat -ln | grep 2222
   ```

## Advanced: Network Bridge

For direct network access (instead of port forwarding):

```bash
# Create bridge (one time setup)
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip addr add 192.168.100.1/24 dev br0

# Run VM with bridge
qemu-system-x86_64 \
  -netdev bridge,id=net0,br=br0 \
  -device virtio-net-pci,netdev=net0 \
  ...
```

VM will get IP on 192.168.100.0/24 network.

## References

- **QEMU Documentation:** https://www.qemu.org/docs/master/
- **KVM:** https://www.linux-kvm.org/
- **Ubuntu Server Guide:** https://ubuntu.com/server/docs
- **LUKS:** https://gitlab.com/cryptsetup/cryptsetup/-/wikis/home
