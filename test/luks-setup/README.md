# TKey-LUKS Test Setup

This directory contains scripts to test the TKey-LUKS system.

## Quick Start

Run the complete end-to-end test:

```bash
cd test/luks-setup
./test-end-to-end.sh
```

This will:
1. Create a 10MB LUKS test image
2. Derive the TKey LUKS key
3. Add the key to the LUKS image
4. Test unlocking with the derived key

## Manual Testing

### 1. Create Test Image

```bash
./create-tkey-test-image.sh [image-name] [size]
```

Default: `test-luks-10mb.img` at 10MB

This creates a LUKS2 encrypted image with:
- Cipher: AES-XTS-Plain64
- Key size: 512 bits
- Hash: SHA-512
- Initial password: `test123`

### 2. Derive TKey Key

```bash
./derive-tkey-key.py [CDI_HEX] [CHALLENGE_HEX]
```

This simulates what the TKey device app does:
1. Takes CDI (32 bytes) - default: all zeros for testing
2. Derives Ed25519 keypair from CDI
3. Uses secret key + challenge with BLAKE2s to derive LUKS key (64 bytes)

**Output files:**
- `tkey-derived-key.bin` - Binary key file (64 bytes)
- `tkey-derived-key.hex` - Hex representation

**Example with custom values:**
```bash
./derive-tkey-key.py \
  0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef \
  aabbccddaabbccddaa bbccddaabbccddaabbccddaabbccddaabbccddaabbccdd
```

### 3. Add TKey Key to LUKS

```bash
./add-tkey-key.sh [image-file] [key-file]
```

This adds the derived key to LUKS key slot 1.
You'll need the initial password (`test123`).

### 4. Test Unlock

```bash
# Test with key file
sudo cryptsetup luksOpen test-luks-10mb.img test --key-file tkey-derived-key.bin
sudo mount /dev/mapper/test /mnt
ls /mnt
sudo umount /mnt
sudo cryptsetup luksClose test
```

## Understanding the Key Derivation

The TKey device app derives the LUKS key as follows:

```c
// Device app (main.c:336)
blake2s(derived_key, 64,           // Output: 64-byte key    
        ctx->secret_key, 64,       // Key material from CDI
        ctx->challenge,            // Challenge from client
        ctx->challenge_size);      // Challenge length
```

Where:
- **CDI** = Compound Device Identifier (unique per TKey + USS)
- **secret_key** = Derived from CDI via Ed25519 key generation
- **challenge** = Sent by client (can be random or fixed)
- **derived_key** = 64-byte (512-bit) LUKS key

## Key Points for Production

### Challenge Strategy

The challenge can be:

1. **Random** (recommended for security):
   - Generate random challenge each time
   - Store encrypted challenge on disk
   - TKey derives key from (secret + challenge)

2. **Fixed** (simpler but less secure):
   - Use a known challenge value
   - Same derived key every time
   - Easier for testing

### USS (User Supplied Secret)

The CDI can be personalized with USS:
- USS is mixed into CDI by TKey firmware
- Different USS = different derived keys
- Allows user to personalize their LUKS key

### Key Slot Strategy

LUKS2 supports 32 key slots. Recommended setup:

- **Slot 0**: Recovery password (user-chosen)
- **Slot 1**: TKey-derived key
- **Slots 2-31**: Available for additional keys

## Files

- `create-tkey-test-image.sh` - Create 10MB LUKS test image
- `derive-tkey-key.py` - Derive key matching device app behavior
- `add-tkey-key.sh` - Add derived key to LUKS image  
- `test-end-to-end.sh` - Complete automated test
- `create-test-image.sh` - Original test image script (100MB)
- `test-unlock.sh` - Original unlock test script

## Dependencies

### For image creation:
- `cryptsetup` - LUKS utilities
- `losetup` - Loop device management
- `mkfs.ext4` - Filesystem creation

### For key derivation:
- Python 3
- `pynacl` - For Ed25519: `pip install pynacl`
- `cryptography` - Standard library

### Optional:
- `monocypher` - Python bindings (not required, fallback available)

## Example Session

```bash
# Create test image
$ ./create-tkey-test-image.sh
[Creates test-luks-10mb.img with password test123]

# Derive key with test CDI
$ ./derive-tkey-key.py
[Creates tkey-derived-key.bin]

# Add key to LUKS
$ ./add-tkey-key.sh test-luks-10mb.img tkey-derived-key.bin
Enter existing password: test123
[Key added to slot 1]

# Test unlock
$ sudo cryptsetup luksOpen test-luks-10mb.img test --key-file tkey-derived-key.bin
$ sudo mount /dev/mapper/test /mnt
$ ls /mnt
README.txt  test.txt  timestamp.txt
$ sudo umount /mnt
$ sudo cryptsetup luksClose test
```

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
