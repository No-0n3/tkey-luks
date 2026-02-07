# Setup Guide

## Prerequisites

### Hardware
- Tillitis TKey hardware device
- x86_64 Linux system
- USB port

### Software
- Linux kernel 5.x or later (with LUKS support)
- initramfs-tools (Debian/Ubuntu) or dracut (Fedora/RHEL)
- cryptsetup
- Build tools (gcc, make)
- QEMU (for testing)

### Optional
- Rust toolchain (if building client in Rust)
- RISC-V GCC toolchain (for device app development)

## Initial Setup

### 1. Clone Repository

```bash
git clone --recursive https://github.com/yourusername/tkey-luks.git
cd tkey-luks
```

### 2. Run Development Setup

```bash
./scripts/setup-dev.sh
```

This will:
- Install system dependencies
- Initialize git submodules
- Create build directories
- Check for TKey tools

### 3. Verify Submodules

Check that Tillitis repositories are properly referenced:

```bash
git submodule status
```

Current `.gitmodules` contains placeholder URLs. Update with correct URLs:

```bash
# Edit .gitmodules to add correct repository URLs
vim .gitmodules

# Update submodules
git submodule sync
git submodule update --init --recursive
```

Expected repositories:
- `tkey-libs`: https://github.com/tillitis/tkey-libs
- `tkey-sign`: Check Tillitis GitHub for correct URL
- `tkey-device-signer`: Part of Tillitis SDK

## Build

### Build All Components

```bash
./scripts/build-all.sh
```

This builds:
1. Device application (runs on TKey)
2. Client application (runs in initramfs)

### Build Individual Components

```bash
# Build client only
cd client
make

# Build device app only  
cd device-app
make
```

### Static Binary Verification

Check that client is statically linked:

```bash
file client/tkey-luks-unlock
ldd client/tkey-luks-unlock
```

Expected output: "statically linked" or "not a dynamic executable"

## Installation

### System-Wide Installation

```bash
sudo ./scripts/install.sh
```

This installs:
- Client binary to `/usr/lib/tkey-luks/`
- Device app to `/usr/lib/tkey-luks/`
- initramfs hooks to `/usr/share/initramfs-tools/hooks/`
- Boot scripts to `/usr/share/initramfs-tools/scripts/local-top/`
- Configuration to `/etc/tkey-luks/`

### Manual Installation

```bash
# Install binary
sudo install -D -m 755 client/tkey-luks-unlock /usr/lib/tkey-luks/tkey-luks-unlock

# Install device app
sudo install -D -m 644 device-app/tkey-luks-device.bin /usr/lib/tkey-luks/

# Copy initramfs hooks
sudo cp -r initramfs-hooks/hooks/* /usr/share/initramfs-tools/hooks/
sudo cp -r initramfs-hooks/scripts/* /usr/share/initramfs-tools/scripts/

# Update initramfs
sudo update-initramfs -u
```

## TKey Enrollment

### Enroll TKey with LUKS Partition

```bash
# Basic enrollment
sudo tkey-luks-enroll /dev/sdaX

# Specify keyslot
sudo tkey-luks-enroll --keyslot 0 /dev/sdaX

# Enroll with challenge
sudo tkey-luks-enroll --challenge-file challenge.bin /dev/sdaX
```

### Enroll Multiple TKeys

```bash
# Primary TKey (keyslot 0)
sudo tkey-luks-enroll --keyslot 0 /dev/sdaX

# Backup TKey (keyslot 1)
# Connect different TKey, then:
sudo tkey-luks-enroll --keyslot 1 /dev/sdaX
```

### Maintain Emergency Password

Always keep a password-based keyslot:

```bash
# Add password to keyslot 7  
sudo cryptsetup luksAddKey /dev/sdaX
# Enter existing key, then new password
```

## Configuration

### Edit Configuration

```bash
sudo vim /etc/tkey-luks/config
```

Configuration options:

```bash
# Device app path
DEVICE_APP=/usr/lib/tkey-luks/tkey-luks-device.bin

# Timeout for TKey detection (seconds)
TIMEOUT=30

# Enable fallback to password
FALLBACK=yes

# Maximum unlock attempts
MAX_ATTEMPTS=3

# Debug logging
DEBUG=no
```

### Update crypttab

Ensure your encrypted device is in `/etc/crypttab`:

```bash
# /etc/crypttab
# <target> <source> <key file> <options>
cryptroot UUID=xxxx-xxxx-xxxx none luks,tkey
```

The `tkey` option triggers TKey unlock in initramfs.

## Testing

### Create Test Environment

```bash
# Create QEMU test VM
cd test/qemu
./create-vm.sh

# This creates a 10GB LUKS encrypted VM
```

### Create Simple Test Image

```bash
# Create small LUKS test image
cd test/luks-setup
./create-test-image.sh test.img 100M testpassword
```

### Test Unlock

```bash
# Test password unlock
./test-unlock.sh test.img no

# Test TKey unlock (after building client)
./test-unlock.sh test.img yes
```

### Run Test VM

```bash
cd test/qemu
./run-vm.sh

# With options:
./run-vm.sh --console --debug
```

## Troubleshooting

### TKey Not Detected

**Problem:** TKey device not found during boot

**Solutions:**
1. Check USB connection
2. Try different USB port
3. Check dmesg for USB errors:
   ```bash
   dmesg | grep -i tkey
   dmesg | grep -i usb
   ```
4. Verify TKey is working:
   ```bash
   lsusb | grep Tillitis
   ```

### Build Fails

**Problem:** Compilation errors

**Solutions:**
1. Check dependencies installed:
   ```bash
   ./scripts/setup-dev.sh
   ```
2. Update submodules:
   ```bash
   git submodule update --remote
   ```
3. Check compiler version:
   ```bash
   gcc --version
   ```

### initramfs Hook Not Running

**Problem:** TKey unlock not attempted at boot

**Solutions:**
1. Verify hooks installed:
   ```bash
   ls -la /usr/share/initramfs-tools/hooks/tkey-luks
   ```
2. Rebuild initramfs:
   ```bash
   sudo update-initramfs -u -k all
   ```
3. Check hook is in initramfs:
   ```bash
   lsinitramfs /boot/initrd.img-$(uname -r) | grep tkey
   ```
4. Enable debug mode and check logs:
   ```bash
   # Add to kernel command line: debug break=mount
   ```

### Static Linking Fails

**Problem:** Binary has dynamic dependencies

**Solutions:**
1. Install musl-libc:
   ```bash
   sudo apt-get install musl-tools
   ```
2. Build with musl:
   ```bash
   cd client
   CC=musl-gcc make
   ```
3. Verify:
   ```bash
   ldd client/tkey-luks-unlock
   ```

### Device App Won't Load

**Problem:** TKey rejects device app

**Solutions:**
1. Rebuild device app:
   ```bash
   cd device-app
   make clean && make
   ```
2. Check binary size:
   ```bash
   ls -lh device-app/tkey-luks-device.bin
   ```
3. Test with tkey-runapp:
   ```bash
   tkey-runapp device-app/tkey-luks-device.bin
   ```

## Verification

### Verify Installation

```bash
# Check files installed
ls -la /usr/lib/tkey-luks/
ls -la /usr/share/initramfs-tools/hooks/tkey-luks
ls -la /etc/tkey-luks/

# Check initramfs contains tkey-luks
lsinitramfs /boot/initrd.img-$(uname -r) | grep tkey

# Verify binary
/usr/lib/tkey-luks/tkey-luks-unlock --help
```

### Verify TKey

```bash
# Check TKey is detected
lsusb | grep Tillitis

# Check TKey serial port
ls -la /dev/ttyACM*

# Test TKey communication
tkey-runapp --version
```

## Next Steps

After successful setup:

1. **Test in VM:** Use QEMU VM for safe testing
2. **Enroll TKey:** Add TKey to test LUKS device
3. **Test Boot:** Verify automatic unlock works
4. **Backup:** Create system backup before production use
5. **Emergency Access:** Ensure emergency password works
6. **Documentation:** Read security considerations

## See Also

- [TESTING.md](TESTING.md) - Comprehensive testing guide
- [SECURITY.md](SECURITY.md) - Security considerations
- [PLAN.md](../PLAN.md) - Project implementation plan
- Tillitis Documentation: https://dev.tillitis.se/
