# TKey-LUKS Initramfs Integration

This directory contains initramfs hooks and scripts for integrating TKey-LUKS with Ubuntu 24.04's boot process.

## Overview

The initramfs integration allows TKey to unlock LUKS-encrypted root partitions during boot:

1. **User Experience:** At boot, user is prompted for "TKey challenge" (what appears to be a password)
2. **Behind the Scenes:** 
   - TKey device is detected on USB
   - Device app is loaded to TKey
   - Challenge is sent to TKey
   - User must physically touch TKey (security feature)
   - TKey derives 64-byte key using Blake2b
   - LUKS volume is unlocked with derived key
3. **Fallback:** If TKey fails or is unplugged, falls back to standard LUKS password

## Architecture

```
Boot Process:
  ┌─────────────────────────────────┐
  │ Kernel loads                     │
  │ Initramfs unpacks               │
  └────────────┬────────────────────┘
               │
  ┌────────────▼────────────────────┐
  │ udev: Detect TKey USB device    │
  │ Module: Load cdc-acm driver     │
  └────────────┬────────────────────┘
               │
  ┌────────────▼────────────────────┐
  │ local-top: Run tkey-luks script │
  │ • Wait for /dev/ttyACM0         │
  │ • Prompt for challenge          │
  │ • Load device app to TKey       │
  │ • Derive key (requires touch)   │
  │ • Unlock LUKS with key          │
  └────────────┬────────────────────┘
               │
               ├─ Success ──→ Continue boot
               │
               └─ Failure ──→ Cryptsetup password prompt
```

## Components

### 1. Hook: `/etc/initramfs-tools/hooks/tkey-luks`

**Purpose:** Runs when `update-initramfs` is executed. Copies necessary files into initramfs image.

**What it does:**
- Copies `tkey-luks-client` binary into initramfs
- Copies `tkey-luks-device.bin` (device app) into initramfs
- Ensures `cdc-acm` kernel module is included (for USB-serial)
- Verifies all components are present

**Source:** [hooks/tkey-luks](hooks/tkey-luks)

### 2. Script: `/etc/initramfs-tools/scripts/local-top/tkey-luks`

**Purpose:** Runs during boot before cryptsetup, handles LUKS unlocking with TKey.

**What it does:**
- Waits for TKey device at `/dev/ttyACM0` (30s timeout)
- Prompts user for challenge (via plymouth or console)
- Runs `tkey-luks-client` to derive key
- Attempts to unlock LUKS device with derived key
- Falls back to password if TKey unlock fails
- Allows user to type "skip" to bypass TKey

**Source:** [scripts/local-top/tkey-luks](scripts/local-top/tkey-luks)

## Installation

### Prerequisites

1. **Built and Installed Binaries:**
   ```bash
   # Build and install client
   cd client/
   make
   sudo make install
   
   # Build and install device app
   cd ../device-app/
   make
   sudo make install
   ```

2. **System Requirements:**
   - Ubuntu 24.04 with initramfs-tools
   - LUKS-encrypted partition
   - TKey device

### Install Hooks

```bash
# From this directory
sudo make install
```

This installs:
- `/etc/initramfs-tools/hooks/tkey-luks`
- `/etc/initramfs-tools/scripts/local-top/tkey-luks`

### Rebuild Initramfs

```bash
sudo make update-initramfs
```

This rebuilds initramfs for all installed kernels, including TKey-LUKS components.

### Verify Installation

```bash
sudo make check
```

Checks:
- Binaries are installed
- Hooks are in place
- Initramfs contains TKey components
- TKey device is detected

## Usage

### First-Time Setup

1. **Add TKey Key to LUKS:**
   ```bash
   # Generate key with TKey and add to LUKS slot
   sudo tkey-luks-client --challenge "my secret challenge" | \
     sudo cryptsetup luksAddKey /dev/sdXY
   ```

2. **Update Initramfs:**
   ```bash
   sudo make update-initramfs
   ```

3. **Test in VM First:**
   ```bash
   # Set up test VM
   cd ../test/qemu/
   sudo ./create-ubuntu-vm.sh
   
   # Run VM with TKey passthrough
   ./run-vm.sh --tkey-device /dev/ttyACM0
   ```

### Boot Process

1. **Normal Boot:**
   - System boots
   - Prompt appears: "TKey challenge for root_crypt:"
   - Enter your challenge phrase
   - Touch TKey when LED blinks
   - System unlocks and continues booting

2. **Fallback (if TKey unavailable):**
   - Prompt appears: "TKey challenge for root_crypt:"
   - Type "skip" or wait for timeout
   - Standard LUKS password prompt appears
   - Enter LUKS password
   - System continues booting

### Configuration

**Enable/Disable TKey Unlock:**

Add to kernel command line in `/etc/default/grub`:
```bash
# Enable (default)
GRUB_CMDLINE_LINUX="TKEY_LUKS_ENABLED=yes"

# Disable
GRUB_CMDLINE_LINUX="TKEY_LUKS_ENABLED=no"
```

Then run:
```bash
sudo update-grub
```

## Troubleshooting

### TKey Not Detected

**Problem:** "TKey device not found after 30s"

**Solutions:**
1. Check TKey is plugged in:
   ```bash
   lsusb | grep -i tillitis
   ```

2. Check serial device:
   ```bash
   ls -l /dev/ttyACM0
   ```

3. Check cdc-acm module:
   ```bash
   lsmod | grep cdc_acm
   ```

4. Verify initramfs includes module:
   ```bash
   lsinitramfs /boot/initrd.img-$(uname -r) | grep cdc-acm
   ```

### Unlock Fails

**Problem:** "Failed to unlock LUKS device"

**Solutions:**
1. Verify TKey key is added to LUKS:
   ```bash
   sudo cryptsetup luksDump /dev/sdXY | grep "Key Slot"
   ```

2. Test key derivation manually:
   ```bash
   echo "my challenge" | tkey-luks-client --challenge-from-stdin > /tmp/key.bin
   sudo cryptsetup luksOpen /dev/sdXY test --key-file=/tmp/key.bin
   sudo cryptsetup luksClose test
   rm /tmp/key.bin
   ```

3. Check device app loads correctly:
   ```bash
   tkey-luks-client --verbose
   ```

### Challenge Prompt Not Appearing

**Problem:** Boot skips TKey prompt entirely

**Solutions:**
1. Check script is executable:
   ```bash
   ls -l /etc/initramfs-tools/scripts/local-top/tkey-luks
   ```

2. Verify script is in initramfs:
   ```bash
   lsinitramfs /boot/initrd.img-$(uname -r) | grep tkey-luks
   ```

3. Check kernel command line:
   ```bash
   cat /proc/cmdline | grep TKEY_LUKS_ENABLED
   ```

### Emergency Access

**Problem:** TKey lost/broken and can't boot

**Solution:** Use standard LUKS password
1. At "TKey challenge" prompt, type: `skip`
2. System will fall back to password prompt
3. Enter your LUKS password
4. System boots normally

**Alternative:** Boot from live USB
1. Boot Ubuntu live USB
2. Unlock with password:
   ```bash
   sudo cryptsetup luksOpen /dev/sdXY root_crypt
   sudo mount /dev/mapper/root_crypt /mnt
   ```
3. Remove TKey hooks:
   ```bash
   sudo rm /mnt/etc/initramfs-tools/hooks/tkey-luks
   sudo rm /mnt/etc/initramfs-tools/scripts/local-top/tkey-luks
   sudo chroot /mnt update-initramfs -u
   ```
4. Reboot to system (will use password only)

## Uninstallation

```bash
# Remove hooks
sudo make uninstall

# Rebuild initramfs without TKey-LUKS
sudo update-initramfs -u -k all
```

## Security Considerations

1. **Physical Access Required:** TKey requires physical touch to derive key, preventing remote attacks

2. **Challenge Storage:** Choose a memorable challenge that's not stored anywhere

3. **Key Slots:** Keep LUKS password in another slot as backup

4. **Fallback Security:** Standard password prompt appears if TKey fails

5. **Device App Integrity:** Verify SHA-512 hash of device app before installation

## Testing

### Test in QEMU VM

Safe way to test without risking your actual system:

```bash
cd ../test/qemu/

# Create Ubuntu 24.04 VM with LUKS encryption
sudo ./create-ubuntu-vm.sh

# Run VM with TKey passthrough
./run-vm.sh --tkey-device /dev/ttyACM0 --console
```

See [../test/qemu/README.md](../test/qemu/README.md) for details.

### Manual Test Without Rebooting

Test the unlock script in a running system:

```bash
# Create test LUKS device
dd if=/dev/zero of=/tmp/test.img bs=1M count=100
sudo cryptsetup luksFormat /tmp/test.img

# Add TKey-derived key
echo "test challenge" | tkey-luks-client | \
  sudo cryptsetup luksAddKey /tmp/test.img

# Test unlock
echo "test challenge" | tkey-luks-client | \
  sudo cryptsetup luksOpen /tmp/test.img test_device

# Clean up
sudo cryptsetup luksClose test_device
rm /tmp/test.img
```

## Development

### Debugging Initramfs Boot

Add debug output to kernel command line:
```bash
# In /etc/default/grub
GRUB_CMDLINE_LINUX="debug ignore_loglevel"
```

View boot logs after system starts:
```bash
journalctl -b | grep -i tkey
```

### Testing Hook Changes

```bash
# Edit hook
vi hooks/tkey-luks

# Reinstall
sudo make install

# Rebuild initramfs
sudo make update-initramfs

# Test in VM
cd ../test/qemu && ./run-vm.sh
```

## References

- **initramfs-tools:** https://manpages.ubuntu.com/manpages/noble/man8/initramfs-tools.8.html
- **cryptsetup:** https://gitlab.com/cryptsetup/cryptsetup
- **TKey Documentation:** https://dev.tillitis.se/
- **Ubuntu 24.04 Boot Process:** https://wiki.ubuntu.com/Initramfs
