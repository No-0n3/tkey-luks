# USS Derivation: Improved Security Implementation

## Overview

This document describes the improved USS (User Supplied Secret) derivation approach that enhances the security of TKey-LUKS by deriving the USS from the user's password using a strong Key Derivation Function (KDF) rather than storing it as a file.

## Table of Contents

- [Security Problem](#security-problem)
- [Improved Solution](#improved-solution)
- [Technical Implementation](#technical-implementation)
- [Usage](#usage)
- [Migration Guide](#migration-guide)
- [Security Analysis](#security-analysis)

## Security Problem

### Original Implementation (Insecure)

In the original implementation, USS could be:

1. **Not used at all** (least secure)
2. **Stored in a file** and passed via `--uss PATH`

**Critical Weakness:** If USS is stored in initramfs (unencrypted `/boot` partition):

- An attacker with physical access to the disk can extract USS
- USS extraction: `unmkinitramfs /boot/initrd.img && cat usr/local/lib/tkey-luks/uss.bin`
- With stolen laptop + TKey + extracted USS, the attacker only needs to guess the password
- **3-factor authentication becomes 1-factor!**

**Attack Scenario:**

```text
Attacker steals: Laptop + TKey
Attacker extracts: USS from /boot/initramfs
Attacker only needs: Password (via brute force or social engineering)
```

## Improved Solution

### Password-Derived USS

The improved implementation derives USS from the user's password using PBKDF2:

```text
USS = PBKDF2(password, salt, iterations=100000, length=32)
```

**Key Benefits:**

- ✅ USS is **never stored on disk**
- ✅ USS is **deterministic** (same password + salt = same USS)
- ✅ USS is **unique per system** (via system-specific salt)
- ✅ Password is used in **TWO layers**:
  - USS derivation (affects CDI in TKey firmware)
  - Challenge data (affects BLAKE2b in device app)
- ✅ Strong KDF makes brute-force attacks harder
- ✅ TKey still required (cannot emulate without UDS)

**Attack Now Requires:**

```text
Physical TKey (UDS inside) +
User password (cannot extract from disk) +
Physical touch +
Correct system salt (easy to get, but useless alone)
```

## Technical Implementation

### Cryptographic Flow

```text
Stage 1: User Input
└─> User Password

Stage 2: USS Derivation (Client)
└─> USS = PBKDF2(password, salt, 100000 iterations)
    ├─> Salt sources (in order):
    │   1. /etc/machine-id (systemd)
    │   2. /var/lib/dbus/machine-id
    │   3. /sys/class/dmi/id/product_uuid (hardware UUID)
    │   4. hostname (fallback)
    └─> USS = 32 bytes, never written to disk

Stage 3: Device Setup (TKey Firmware)
└─> CDI = Hash(UDS ⊕ App ⊕ USS_derived)
    └─> CDI now incorporates password!

Stage 4: Key Derivation (Device App)
└─> secret_key = Ed25519_derive(CDI)
└─> LUKS_key = BLAKE2b(key=secret_key, data=password)
    └─> Password used in BOTH layers!

Stage 5: Volume Unlock
└─> cryptsetup luksOpen --key-file=<LUKS_key>
```

### Double Password Protection

The password is used in **two independent cryptographic operations**:

- **USS Derivation** (affects TKey CDI):

  ```text
  USS = PBKDF2(password, system_salt, 100k iterations)
  CDI = Hash(UDS ⊕ Device_App ⊕ USS)
  ```

- **Challenge Data** (affects BLAKE2b):

  ```text
  secret_key = derive_from(CDI)  // Contains USS
  LUKS_key = BLAKE2b(key=secret_key, data=password)
  ```

This provides **defense in depth**: compromising one layer doesn't compromise the other.

## Usage

### New Approach (Recommended)

```bash
# At boot time (initramfs automatically uses this)
tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --device /dev/ttyACM0 \
  --device-app /usr/local/lib/tkey-luks/tkey-luks-device.bin \
  --output /tmp/luks-key.bin
```

The `--derive-uss` flag enables USS derivation from password automatically.

### Advanced Options

#### Custom Salt

```bash
# Use custom salt (stored in /etc/tkey-luks/salt)
tkey-luks-client \
  --challenge "my-password" \
  --derive-uss \
  --salt "$(cat /etc/tkey-luks/salt)" \
  --output key.bin
```

#### Different USS Password

```bash
# Use different password for USS vs challenge (not recommended)
tkey-luks-client \
  --uss-password "USS-password-123" \
  --challenge "challenge-password-456" \
  --derive-uss \
  --output key.bin
```

#### Custom PBKDF2 Iterations

```bash
# Increase iterations for stronger security (slower boot)
tkey-luks-client \
  --challenge "my-password" \
  --derive-uss \
  --pbkdf2-iterations 200000 \
  --output key.bin
```

### Backward Compatibility (Deprecated)

```bash
# Old approach: USS from file (LESS SECURE)
tkey-luks-client \
  --challenge "my-password" \
  --uss /path/to/uss.bin \
  --output key.bin
```

**Warning:** This approach is deprecated and will show security warnings.

## Migration Guide

### For New Installations

- **Build and Install** with new code:

   ```bash
   ./scripts/build-all.sh
   sudo make -C client install
   sudo make -C device-app install
   sudo make -C initramfs-hooks install
   ```

- **Add LUKS Key** using derived USS:

   ```bash
   echo "your-password" | sudo tkey-luks-client \
     --challenge-from-stdin \
     --derive-uss \
     --output - | \
   sudo cryptsetup luksAddKey /dev/nvme0n1p6 -
   ```

- **Configure** `/etc/crypttab`:

  ```text
  luks-<uuid> UUID=<uuid> none luks,discard,initramfs
  ```

- **Update** initramfs:

   ```bash
   sudo update-initramfs -u -k all
   ```

- **Test** unlock:

   ```bash
   # The system will automatically use --derive-uss
   # Just enter your password at boot
   ```

### For Existing Installations

#### Option 1: Fresh Setup (Recommended)

1. Add new key with derived USS
2. Remove old USS file-based key
3. Update initramfs

```bash
# Add new key
echo "your-password" | sudo tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --output - | \
sudo cryptsetup luksAddKey /dev/nvme0n1p6 -

# Test new key works
echo "your-password" | sudo tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --output /tmp/test-key.bin

sudo cryptsetup luksOpen /dev/nvme0n1p6 test-mapper \
  --key-file=/tmp/test-key.bin

# If successful, remove old key
sudo cryptsetup luksRemoveKey /dev/nvme0n1p6

# Clean up USS files
sudo rm -f /etc/tkey-luks/uss.bin
sudo rm -f /usr/local/lib/tkey-luks/uss.bin

# Update initramfs
sudo update-initramfs -u -k all
```

#### Option 2: Parallel Keys (Safe Transition)

Keep both old USS file key and new derived USS key for a transition period:

1. Add new derived USS key (different password)
2. Test thoroughly
3. Eventually remove old key

## Security Analysis

### Comparison Table

|Aspect|Old (USS File)|New (Derived USS)|
|------|--------------|-----------------|
|USS Storage|File in /boot|Never stored|
|Extractable|✗ Yes (unmkinitramfs)|✓ No|
|Password Use|1 layer (challenge)|2 layers (USS + challenge)|
|Salt|None|System-specific|
|KDF|None|PBKDF2 (100k iterations)|
|Attack Resistance|Low|High|
|Boot Speed|Fast|~Same (KDF done once)|

### Attack Scenarios

#### Scenario 1: Stolen Laptop + TKey

**Old Approach:**

```text
1. Extract USS from initramfs ✓
2. Read disk (encrypted) ✗
3. Guess password → Unlock!
Result: 1-factor security
```

**New Approach:**

```text
1. Extract USS from initramfs ✗ (not stored)
2. Read disk (encrypted) ✗
3. Guess password → Need TKey + Touch
Result: Still 2-factor security
```

#### Scenario 2: Stolen Laptop Only (No TKey)

**Both Approaches:**

```text
Cannot derive key without TKey (UDS) ✓
Still secure
```

#### Scenario 3: Stolen TKey Only (No Disk)

**Both Approaches:**

```text
Cannot derive key without password ✓
Still secure
```

### Remaining Considerations

#### Salt Security

**Q: Can attacker get the salt?**
**A:** Yes, salt is typically readable from:

- `/etc/machine-id` (world-readable)
- DMI UUID (accessible via sudo/root)

**But:** Salt is **not** a secret! Its purpose is:

- Unique USS per system (same password on different machines = different USS)
- Prevent rainbow table attacks on USS derivation

**Important:** Salt doesn't need to be secret; it just needs to be system-unique.

#### Custom Salts

For maximum security paranoia, you can use a **custom secret salt**:

```bash
# Generate and store secret salt
head -c 32 /dev/urandom | base64 > /etc/tkey-luks/secret-salt

# Use in enrollment
cat /etc/tkey-luks/secret-salt | sudo tkey-luks-client \
  --challenge "password" \
  --derive-uss \
  --salt-from-stdin \
  --output - | \
sudo cryptsetup luksAddKey /dev/nvme0n1p6 -
```

**Trade-off:** If you lose the salt file, you cannot unlock the disk!

## Best Practices

### Recommended Configuration

1. **Use `--derive-uss`** (always, unless backward compatibility needed)
2. **Use default system salt** (machine-id)
3. **Use same password** for USS and challenge (simpler, same security)
4. **Increase iterations** if boot time allows (200k-500k)
5. **Test thoroughly** before removing old keys

### Security Checklist

- [ ] USS derivation enabled (`--derive-uss`)
- [ ] No USS files in `/boot` or initramfs
- [ ] System salt is stable (machine-id won't change)
- [ ] Backup recovery key in safe location
- [ ] Test unlock before removing old keys
- [ ] Document salt location/source

### Performance Tuning

PBKDF2 iterations vs boot time (approximate on modern CPU):

|Iterations|Security|Boot Delay|
|---------|--------|----------|
|100,000|Good|~100ms|
|200,000|Better|~200ms|
|500,000|Best|~500ms|
|1,000,000|Overkill|~1s|

**Recommendation:** 100k-200k iterations for boot use case.

## Future Enhancements

### Possible Improvements

1. **Argon2id Support**: More modern KDF (memory-hard)
2. **TPM Integration**: Combine TKey + TPM for 3-factor auth
3. **USB Token USS**: Store USS on separate USB token
4. **Yubikey USS**: Use Yubikey HMAC-SHA1 challenge-response for USS
5. **Multi-TKey**: Support multiple TKeys for redundancy

### True 3-Factor Authentication

For maximum security, use:

1. **TKey** (UDS - hardware secret)
2. **USS USB Token** (stored on separate USB drive)
3. **Password** (challenge phrase)

All three required to unlock!

## References

- [SECURITY.md](SECURITY.md) - Overall security model
- [improved-implementation-flow.puml](improved-implementation-flow.puml) - Visual diagram
- [current-implementation-flow.puml](current-implementation-flow.puml) - Original flow
- [PBKDF2 Specification](https://datatracker.ietf.org/doc/html/rfc2898)
- [Tillitis TKey Documentation](https://tillitis.se/)

## Support

For questions or issues:

- GitHub Issues: <https://github.com/No-0n3/tkey-luks/issues>
- Security concerns: See [SECURITY.md](SECURITY.md)
