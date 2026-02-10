# TKey-LUKS Initramfs Integration Guide

Complete guide for integrating TKey-LUKS with Ubuntu 24.04's initramfs for automatic boot-time LUKS unlock.

## Table of Contents

1. [Overview](#overview)
2. [How It Works](#how-it-works)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Testing in VM](#testing-in-vm)
7. [Deployment to Production](#deployment-to-production)
8. [Troubleshooting](#troubleshooting)
9. [Security Considerations](#security-considerations)

## Overview

TKey-LUKS initramfs integration allows your Ubuntu 24.04 system to:
- Unlock LUKS-encrypted root partitions using TKey hardware device at boot
- Present a "challenge" prompt instead of a password prompt
- Derive cryptographic keys using physical hardware (TKey) + touch confirmation
- Fall back to password unlock if TKEY is unavailable

**User Experience:**
1. System boots and shows: "TKey challenge for root_crypt:"
2. User enters challenge phrase
3. User touches TKey device (LED blinks for confirmation)
4. System automatically unlocks and continues booting

## How It Works

### Boot Sequence

```
1. BIOS/UEFI → Bootloader (GRUB)
   ↓
2. Kernel loads with initramfs
   ↓
3. udev detects TKey USB device (/dev/ttyACM0)
   ↓
4. TKey-LUKS script executes (local-top phase)
   ↓
5. Prompt user for challenge
   ↓
6. Wait for TKey device (max 30s)
   ↓
7. Load device app to TKey
   ↓
8. Send challenge to TKey
   ↓
9. User touches TKey → key derivation (Blake2b)
   ↓
10. Unlock LUKS with derived key
   ↓
11. If successful: continue boot
    If failed: fall back to password prompt
```

### Components

**1. Initramfs Hook** (`/etc/initramfs-tools/hooks/tkey-luks`)
- Runs when `update-initramfs` is executed
- Copies client binary and device app into initramfs image
- Ensures CDC-ACM kernel module is included

**2. Unlock Script** (`/etc/initramfs-tools/scripts/local-top/tkey-luks`)
- Runs during boot before cryptroot
- Detects TKey device
- Prompts for challenge
- Derives key and unlocks LUKS

**3. Client Binary** (`/usr/local/bin/tkey-luks-client`)
- Communicates with TKey via serial
- Implements TKey-LUKS protocol
- Derives 64-byte keys

**4. Device App** (`/usr/local/lib/tkey-luks/tkey-luks-device.bin`)
- Runs on TKey hardware (RISC-V)
- Performs key derivation using Blake2b
- Requires physical touch for security

## Prerequisites

### System Requirements

- Ubuntu 24.04 LTS (or compatible)
- LUKS-encrypted root partition
- TKey device (Tillitis MTA1-USB-V1)
- initramfs-tools

### Build Requirements

```bash
# For device app (RISC-V cross-compilation)
sudo apt-get install clang lld llvm

# For client (Go)
sudo apt-get install golang

# For testing
sudo apt-get install cryptsetup qemu-system-x86 genisoimage
```

## Installation

### Step 1: Build Components

```bash
# Clone repository
git clone https://github.com/No-0n3/tkey-luks.git
cd tkey-luks/

# Initialize submodules
git submodule update --init --recursive

# Build device app
cd device-app/
./build.sh
cd ..

# Build client
cd client/
make
cd ..
```

### Step 2: Test Components (Optional but Recommended)

```bash
# Test device app loads correctly
cd test/
python3 test-protocol.py

# Test key derivation
cd ../client/
echo "test challenge" | ./tkey-luks-client --challenge-from-stdin --output -
cd ..
```

### Step 3: Install Binaries

```bash
# Install device app
cd device-app/
sudo make install
# Installs to: /usr/local/lib/tkey-luks/tkey-luks-device.bin

# Install client
cd ../client/
sudo make install
# Installs to: /usr/local/bin/tkey-luks-client
```

### Step 4: Install Initramfs Hooks

```bash
cd ../initramfs-hooks/
sudo make install
```

This installs:
- `/etc/initramfs-tools/hooks/tkey-luks`
- `/etc/initramfs-tools/scripts/local-top/tkey-luks`

### Step 5: Update Initramfs

```bash
sudo make update-initramfs
```

### Step 6: Verify Installation

```bash
sudo make check
```

Should show:
```
[1/5] Checking prerequisites...
  ✓ Client installed
  ✓ Device app installed

[2/5] Checking hook installation...
  ✓ Hook installed

[3/5] Checking script installation...
  ✓ Script installed

[4/5] Checking initramfs contents...
  ✓ TKey client in initramfs

[5/5] Checking TKey device...
  ✓ TKey device present: /dev/ttyACM0
```

### Step 7: Add TKey Key to LUKS

```bash
# Find your LUKS partition
lsblk -f

# Add TKey-derived key to LUKS slot (example for /dev/sda2)
echo "my secret challenge" | \
  sudo tkey-luks-client --challenge-from-stdin --output - | \
  sudo cryptsetup luksAddKey /dev/sda2

# You'll be prompted for existing LUKS password first
# This adds the TKey key to a new LUKS slot
```

**Important:** Keep your original LUKS password in another slot as backup!

### Step 8: Verify LUKS Key Added

```bash
sudo cryptsetup luksDump /dev/sda2 | grep "Key Slot"
```

Should show multiple key slots (original password + TKey key).

## Configuration

### Default Settings

The initramfs script uses these defaults:

```bash
TKEY_CLIENT="/usr/local/bin/tkey-luks-client"
TKEY_DEVICE_APP="/usr/local/lib/tkey-luks/tkey-luks-device.bin"
TKEY_SERIAL="/dev/ttyACM0"
MAX_WAIT=30  # seconds to wait for TKey
```

### Enable/Disable TKey Unlock

Add to `/etc/default/grub`:

```bash
# Enable (default)
GRUB_CMDLINE_LINUX="TKEY_LUKS_ENABLED=yes"

# Disable (use password only)
GRUB_CMDLINE_LINUX="TKEY_LUKS_ENABLED=no"
```

Then update GRUB:
```bash
sudo update-grub
```

### Custom Challenge

The challenge is entered at boot time, but you can set a default hostname-based challenge by modifying `/etc/initramfs-tools/scripts/local-top/tkey-luks`.

## Testing in VM

**CRITICAL:** Test in a VM before deploying to production!

### Create Test VM

```bash
cd test/qemu/

# Create Ubuntu 24.04 VM with LUKS
sudo ./create-ubuntu-vm.sh

# Start installation
./run-ubuntu-vm.sh --install

# During install: Choose LUKS encryption with password: test123
```

### Install TKey-LUKS in VM

```bash
# Copy project to VM
tar czf /tmp/tkey-luks.tar.gz .
scp -P 2222 /tmp/tkey-luks.tar.gz tkey@localhost:~/

# In VM
ssh -p 2222 tkey@localhost
tar xzf tkey-luks.tar.gz
cd tkey-luks/

# Build and install (same steps as above)
```

### Test with TKey Passthrough

```bash
# Run VM with TKey device
./run-ubuntu-vm.sh --tkey-device /dev/ttyACM0
```

In VM:
1. Add TKey key to LUKS
2. Reboot
3. At boot prompt: enter challenge
4. Touch TKey when LED blinks
5. System should unlock and boot

See [test/qemu/README.md](../test/qemu/README.md) for detailed testing guide.

## Deployment to Production

### Pre-Deployment Checklist

- [ ] All components tested in VM
- [ ] TKey key successfully added to LUKS
- [ ] Original LUKS password retained in another slot
- [ ] Backup of important data
- [ ] Recovery USB with LUKS password prepared

### Deployment Steps

1. **Ensure backup access:**
   ```bash
   # Verify password slot still works
   echo "your_password" | sudo cryptsetup luksOpen --test-passphrase /dev/sdXY
   ```

2. **Install on production system** (same steps as Installation above)

3. **Test before rebooting:**
   ```bash
   # Verify TKey can derive key
   echo "test challenge" | tkey-luks-client --challenge-from-stdin --output - > /tmp/test.key
   
   # Verify key works (if possible on non-root partition)
   ```

4. **Reboot and test:**
   - First boot: Have live USB ready as backup
   - Successfully unlock with TKey
   - Verify system boots normally

5. **Document your challenge** (securely!)
   - Write down challenge phrase (not challenge itself!)
   - Store securely separate from TKey
   - DO NOT store on same system

### Rollback if Issues

If TKey unlock fails and you can't boot:

1. Boot from live USB
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
4. Reboot to normal system

## Troubleshooting

### TKey Not Detected at Boot

**Symptom:** "TKey device not found after 30s"

**Solutions:**
1. Check TKey is plugged in before boot
2. Try different USB port (USB 2.0 ports work best)
3. Check dmesg for CDC-ACM module:
   ```bash
   grep cdc_acm /var/log/kern.log
   ```

### Unlock Fails with Correct Challenge

**Symptom:** "Failed to unlock LUKS device"

**Solutions:**
1. Touch TKey when LED blinks
2. Verify key was added to LUKS:
   ```bash
   sudo cryptsetup luksDump /dev/sdXY
   ```
3. Test key derivation is deterministic:
   ```bash
   echo "challenge" | tkey-luks-client --challenge-from-stdin --output - | sha256sum
   # Run multiple times, should give same hash
   ```

### Boot Hangs at Plymouth/Graphics

**Symptom:** Graphical boot hangs, no prompt visible

**Solutions:**
1. Add to kernel command line: `nomodeset`
2. Disable plymouth: `plymouth=false`
3. Use console: `GRUB_CMDLINE_LINUX="console=tty1"`

### Emergency Access

**Lost TKey or doesn't work:**
1. At challenge prompt, type: `skip`
2. Standard password prompt will appear
3. Enter LUKS password
4. System boots normally

**Or boot from live USB and use password** (see Rollback above)

## Security Considerations

### Threat Model

**What TKey-LUKS Protects Against:**
- Stolen laptop with powered-off drive
- Cold boot attacks (requires physical TKey)
- Remote attacks (requires physical TKey touch)
- Casual physical access

**What TKey-LUKS Does NOT Protect Against:**
- Running system compromise (keys in memory)
- Evil maid attacks with malicious bootloader
- Very sophisticated physical attacks on TKey hardware
- Someone who has both TKey AND knows challenge

### Best Practices

1. **Keep strong password in separate LUKS slot** - TKey is augmentation, not replacement

2. **Challenge selection:**
   - Use memorable phrase, not written down
   - Not same as LUKS password
   - Long enough (16+ characters)
   - Unique to this system

3. **Physical security:**
   - Keep TKey on person
   - Not in laptop bag
   - Separate from challenge phrase

4. **Backup:**
   - Test password slot works BEFORE removing old one
   - Create recovery USB with LUKS password
   - Document recovery procedure

5. **Update strategy:**
   - Test in VM before production
   - Keep original password until TKey proven working
   - Have recovery USB ready during first deployment

### Key Derivation Security

The system uses Blake2b keyed hash:
- **Input:** Challenge string (user-provided)
- **Key:** TKey secret (derived from CDI + USS)
- **Output:** 64-byte LUKS key

**Security properties:**
- Different challenge → completely different key
- Same challenge + same TKey → always same key (deterministic)
- Impossible to derive key without physical TKey
- Requires physical touch = confirms user presence

## Advanced Topics

### Multiple Systems with One TKey

Same TKey can unlock multiple systems - use different challenge for each:
- System A: "work laptop challenge phrase"
- System B: "home server challenge phrase"

### User Supplied Secret (USS)

Add additional entropy during device app load:

```bash
# Generate USS
dd if=/dev/random of=my.uss bs=32 count=1

# Use with client
tkey-luks-client --uss my.uss --challenge "..."
```

**Important:** USS must be available in initramfs if used!

### Debugging Initramfs

Add to kernel command line:
```
debug ignore_loglevel break=top
```

View logs after boot:
```bash
journalctl -b | grep -i tkey
```

## References

- [Initramfs Hooks README](../initramfs-hooks/README.md)
- [QEMU Testing Guide](../test/qemu/README.md)
- [TKey Documentation](https://dev.tillitis.se/)
- [cryptsetup-initramfs](https://manpages.ubuntu.com/manpages/noble/man8/cryptsetup-initramfs.8.html)
