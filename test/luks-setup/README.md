# TKey-LUKS Test Setup

This directory contains scripts to test TKey-LUKS with improved USS derivation.

## Quick Start

### Hardware Test (Requires Real TKey)

```bash
cd test
./test-improved-uss.sh
```

This performs comprehensive testing of USS derivation with hardware TKey device.

### Create and Test LUKS Image

```bash
cd test/luks-setup
./create-tkey-test-image.sh
./add-tkey-key.sh
./test-unlock.sh
```

## Available Scripts

### 1. Create Test Image

```bash
./create-tkey-test-image.sh [image-name]
```

Default: `test-luks-100mb.img`

Creates a 100MB LUKS2 encrypted image with:

- Cipher: AES-XTS-Plain64
- Key size: 512 bits
- Hash: SHA-512
- PBKDF: Argon2id
- Initial password: `test123`

### 2. Add TKey Key (Improved USS Derivation)

```bash
./add-tkey-key.sh [image-file] [password]
```

Enrolls TKey with improved USS derivation:

- Derives USS from password using PBKDF2 (100k iterations)
- Uses machine-id as salt
- Loads device app to TKey
- Waits for physical touch
- Derives LUKS key with double password protection
- Adds key to LUKS keyslot

**Requires:**

- TKey device connected at /dev/ttyACM0
- tkey-luks-client in PATH

### 3. Test Unlock

```bash
./test-unlock.sh [image-file] [use-tkey] [password]
```

Parameters:

- `image-file`: LUKS image to test (default: test-luks-100mb.img)
- `use-tkey`: yes/no (default: yes)
- `password`: Password for USS derivation (default: test123)

Tests LUKS unlock with:

- TKey mode: Uses improved USS derivation + physical touch
- Password mode: Standard LUKS password unlock

## Security Testing

The improved USS derivation provides multiple layers of security:

1. **Password Layer**: PBKDF2 with 100,000 iterations
2. **System Binding**: Machine-id as salt (system-unique)
3. **Hardware Binding**: TKey UDS (device-unique)
4. **Physical Authentication**: Touch required for unlock

### USS Derivation Properties

```text
USS = PBKDF2-HMAC-SHA256(password, machine-id, 100k iterations, 32 bytes)
CDI = Hash(UDS ⊕ DeviceApp ⊕ USS)
secret_key = Ed25519_KeyDerive(CDI)
LUKS_key = BLAKE2b(key=secret_key, data=password)
```

**Security Features:**

- Password used in **two independent layers**
- USS never written to disk
- System-specific (moving disk to new machine requires re-enrollment)
- Device-specific (requires physical TKey)
- Touch-to-unlock (prevents automation)

## Key Slot Strategy

LUKS2 supports 32 key slots. Recommended setup:

- **Slot 0**: Emergency password (user-chosen, independent of TKey)
- **Slot 1**: Primary TKey (improved USS derivation)
- **Slot 2**: Backup TKey (different device, same password)
- **Slots 3-31**: Available for additional keys

**Always maintain an emergency password keyslot independent of TKey!**

## Files in This Directory

- `create-tkey-test-image.sh` - Create 100MB LUKS2 test image
- `add-tkey-key.sh` - Enroll TKey with improved USS derivation
- `test-unlock.sh` - Test LUKS unlock with TKey or password
- `README.md` - This file

## Dependencies

### For image creation and testing

- `cryptsetup` (>= 2:2.0.0) - LUKS utilities
- `losetup` - Loop device management
- `mkfs.ext4` - Filesystem creation
- `tkey-luks-client` - Client application (from project root)

### For TKey hardware

- TKey device connected at /dev/ttyACM0
- Device firmware: tkey-luks-device.bin
- Physical access for touch authentication

## Example Session

```bash
# 1. Create test image (100MB, password: test123)
$ ./create-tkey-test-image.sh
=== LUKS Test Image Created Successfully ===
Image file: test-luks-100mb.img
Initial password: test123

# 2. Enroll TKey with improved USS derivation
$ ./add-tkey-key.sh test-luks-100mb.img test123
=== Adding TKey Key to LUKS Image (Improved USS Derivation) ===
Deriving key from TKey with improved USS...
(Touch the TKey when it blinks)
✓ TKey key added successfully using improved USS derivation!

# 3. Test unlock with TKey
$ ./test-unlock.sh test-luks-100mb.img yes test123
=== Testing LUKS Unlock (Improved USS Derivation) ===
Mode: TKey (--derive-uss)
Deriving key from TKey...
(Touch the TKey when it blinks)
✓ LUKS unlock successful!

# 4. Verify filesystem contents
Contents:
README.txt
timestamp.txt
test.txt
```

## Troubleshooting

### TKey not detected

```bash
# Check if TKey is connected
ls -la /dev/ttyACM0

# Check dmesg for USB events
dmesg | tail -20
```

### USS derivation fails

- Ensure password matches enrollment
- Verify machine-id hasn't changed: `cat /etc/machine-id`
- Check TKey is responding: power cycle the device

### LUKS unlock fails

- Ensure physical touch when TKey blinks
- Verify keyslot was added: `sudo cryptsetup luksDump <image>`
- Test with emergency password first

## Related Documentation

- [USS-DERIVATION.md](../../docs/USS-DERIVATION.md) - Detailed security analysis
- [SETUP.md](../../docs/SETUP.md) - Production setup guide
- [SECURITY.md](../../docs/SECURITY.md) - Security model and best practices
- [TESTING.md](../../docs/TESTING.md) - Comprehensive testing guide

## Next Steps

1. Build Go client to communicate with TKey device app
2. Test with actual TKey hardware (not just simulated CDI)
3. Implement challenge generation/storage
4. Create initramfs integration for boot-time unlock
5. Add error handling and retry logic

## Security Notes

⚠️ **Test Environment Only**

- Using fixed CDI (all zeros) is for testing only
- Real TKey provides unique CDI per device
- Do not use test keys in production

⚠️ **Keep Recovery Password**

- Always maintain slot 0 with a recovery password
- TKey can fail or be lost
- Recovery password allows emergency access
