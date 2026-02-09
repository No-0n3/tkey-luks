# TKey-LUKS Initramfs Integration

This directory contains initramfs hooks and scripts for integrating TKey-LUKS with Ubuntu 24.04's boot process.

## Overview

The initramfs integration allows TKey to unlock LUKS-encrypted root partitions during boot using improved USS derivation (v1.1.0+):

1. **User Experience:** At boot, user is prompted for password
2. **Behind the Scenes (Improved USS Derivation):**
   - TKey device is detected on USB
   - Password → USS derivation using PBKDF2 (100k iterations, machine-id salt)
   - Device app loaded to TKey with derived USS
   - CDI generated: `CDI = Hash(UDS ⊕ App ⊕ USS)`
   - Password sent as challenge data (same password, two layers!)
   - User must physically touch TKey (security feature)
   - TKey derives 64-byte LUKS key using BLAKE2b
   - LUKS volume unlocked with derived key
3. **Security:** Password used in TWO independent layers (USS derivation + BLAKE2b)
4. **Fallback:** If TKey fails or is unplugged, falls back to emergency LUKS password

## Architecture

```text
Boot Process (v1.1.0 with Improved USS Derivation):
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
  │ • Prompt for password           │
  │ • Derive USS from password      │
  │   (PBKDF2, machine-id salt)     │
  │ • Load device app with USS      │
  │ • Send password as challenge    │
  │ • Wait for physical touch       │
  │ • Derive key (BLAKE2b)          │
  │ • Unlock LUKS with key          │
  └────────────┬────────────────────┘
               │
               ├─ Success ──→ Continue boot
               │
               └─ Failure ──→ Emergency password prompt
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

1. **Add TKey Key to LUKS (Improved USS Derivation):**

   ```bash
   # Generate key with TKey using improved USS derivation
   echo "YourPassword" | sudo tkey-luks-client \
     --challenge-from-stdin \
     --derive-uss \
     --output - | \
   sudo cryptsetup luksAddKey /dev/sdXY -
   ```

2. **Update Initramfs:**

   ```bash
   sudo make update-initramfs
   ```

3. **Test with Test Image First:**

   ```bash
   # Create test LUKS image
   cd ../test/luks-setup/
   ./create-tkey-test-image.sh
   
   # Add TKey key with improved USS
   ./add-tkey-key.sh test-luks-100mb.img YourPassword
   
   # Test unlock
   ./test-unlock.sh test-luks-100mb.img yes YourPassword
   ```

### Boot Process

1. **Normal Boot (Improved USS Derivation):**
   - System boots
   - Prompt appears: "Enter password for root_crypt:"
   - Enter your password (used for USS derivation + BLAKE2b)
   - Touch TKey when LED blinks
   - System derives USS from password using PBKDF2
   - System derives LUKS key from TKey
   - System unlocks and continues booting

2. **Fallback (if TKey unavailable):**
   - Prompt appears: "Enter password for root_crypt:"
   - Type "skip" or wait for timeout
   - Emergency LUKS password prompt appears
   - Enter emergency LUKS password (different from TKey password)
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

5. Check machine-id (USS salt source):

   ```bash
   cat /etc/machine-id
   # If empty or changed, USS derivation will produce different keys!
   ```

### Unlock Fails

**Problem:** "Failed to unlock LUKS device"

**Solutions:**

1. Verify TKey key is added to LUKS:

   ```bash
   sudo cryptsetup luksDump /dev/sdXY | grep "Key Slot"
   ```

2. Test key derivation manually (with improved USS):

   ```bash
   echo "YourPassword" | tkey-luks-client \
     --challenge-from-stdin --derive-uss --output /tmp/key.bin
   sudo cryptsetup luksOpen /dev/sdXY test --key-file=/tmp/key.bin
   sudo cryptsetup luksClose test
   shred -u /tmp/key.bin  # Secure deletion
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

2. **Improved USS Derivation (v1.1.0):**
   - USS derived from password using PBKDF2 (100,000 iterations)
   - Machine-id used as salt (system-unique binding)
   - USS never stored on disk (ephemeral, password-based)
   - Password used in TWO layers: USS derivation + BLAKE2b challenge

3. **Password Security:** Choose strong password (16+ characters)
   - Password affects USS derivation (PBKDF2)
   - Same password used as BLAKE2b challenge
   - Different from emergency LUKS password

4. **Key Slots:** Always maintain emergency password in separate slot as backup

5. **System Binding:** Moving encrypted disk to new system requires re-enrollment
   - USS derivation uses machine-id as salt
   - Different machine = different USS = different key

6. **Fallback Security:** Emergency password prompt appears if TKey fails

7. **Device App Integrity:** Always verify binary integrity before installation

## Testing

### Test with LUKS Test Images

Safe way to test without modifying your actual system:

```bash
cd ../test/luks-setup/

# Create 100MB LUKS2 test image
./create-tkey-test-image.sh

# Enroll TKey with improved USS derivation
./add-tkey-key.sh test-luks-100mb.img YourPassword

# Test unlock
./test-unlock.sh test-luks-100mb.img yes YourPassword
```

See [../test/luks-setup/README.md](../test/luks-setup/README.md) for details.

### Manual Test Without Rebooting

Test the unlock script in a running system:

```bash
# Create test LUKS device
dd if=/dev/zero of=/tmp/test.img bs=1M count=100
sudo cryptsetup luksFormat /tmp/test.img

# Add TKey-derived key (improved USS derivation)
echo "test password" | tkey-luks-client --derive-uss --challenge-from-stdin | \
  sudo cryptsetup luksAddKey /tmp/test.img

# Test unlock
echo "test password" | tkey-luks-client --derive-uss --challenge-from-stdin | \
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

# Test with LUKS image
cd ../test/luks-setup && ./test-unlock.sh
```

## References

- **initramfs-tools:** <https://manpages.ubuntu.com/manpages/noble/man8/initramfs-tools.8.html>
- **cryptsetup:** <https://gitlab.com/cryptsetup/cryptsetup>
- **TKey Documentation:** <https://dev.tillitis.se/>
- **Ubuntu 24.04 Boot Process:** <https://wiki.ubuntu.com/Initramfs>
