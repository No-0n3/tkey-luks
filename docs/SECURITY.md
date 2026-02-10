# TKey-LUKS Security Guide

> **Complete security documentation including USS derivation, threat model, implementation, and troubleshooting**

## Table of Contents

1. [Security Model Overview](#security-model-overview)
2. [Threat Model](#threat-model)
3. [USS Derivation Implementation](#uss-derivation-implementation)
4. [Usage & Configuration](#usage--configuration)
5. [Migration Guide](#migration-guide)
6. [Attack Scenarios & Mitigations](#attack-scenarios--mitigations)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)
9. [Compliance & Audit](#compliance--audit)

---

## Security Model Overview

**TKey-LUKS v1.1.1+** uses an **improved USS (User Supplied Secret) derivation** approach that provides defense-in-depth by using your password in two independent cryptographic layers.

### Key Security Features

1. **Password-Derived USS** - USS is derived from your password using PBKDF2, never stored
2. **Double Password Protection** - Password used in both USS derivation and challenge
3. **Hardware Root of Trust** - TKey's UDS (Unique Device Secret) cannot be extracted
4. **Physical Touch Requirement** - Prevents remote/automated attacks
5. **System-Specific** - Machine-id salt makes USS unique per installation

### Version History

- **v1.0.0**: USS stored in files (insecure - extractable from `/boot`)
- **v1.1.0**: Improved USS derivation using PBKDF2 (never stored)
- **v1.1.1**: Fixed salt availability in initramfs (machine-id copy)

---

## Threat Model

### What This System Protects Against

1. **Unauthorized Boot Access**
   - Stolen laptop/device scenarios
   - Prevents boot without physical TKey present
   - Hardware-based authentication

2. **Software Attacks on Key Material**
   - LUKS key never stored in plaintext on disk
   - Key derived at boot time from TKey
   - Protected against software key extraction
   - USS never written to filesystem

3. **USS Extraction Attacks (v1.1.0+)**
   - Old: USS stored in `/boot/initramfs` → extractable
   - New: USS derived from password → not extractable
   - Eliminates 3-factor → 1-factor reduction

4. **Limited Protection Against Cold Boot Attacks**
   - Key exists in RAM only during boot
   - Minimized time window
   - No persistent key storage

### What This System Does NOT Protect Against

1. **Physical Access with TKey Present**
   - If attacker has both device and TKey, they can boot if password is obtained
   - Consider this when storing TKey and device together

2. **Evil Maid Attacks on Bootloader**
   - Modified bootloader can capture keystrokes or compromise initramfs
   - **Mitigation**: Use UEFI Secure Boot, TPM-based attestation

3. **Compromised Initramfs**
   - Malicious initramfs can extract key during boot
   - **Mitigation**: Secure Boot with signed initramfs

4. **Advanced Physical Attacks**
   - DMA attacks (e.g., Thunderbolt/FireWire)
   - Hardware implants
   - Chip-level attacks on TKey
   - **Mitigation**: IOMMU, disable unnecessary ports

5. **Rubber Hose Cryptanalysis**
   - Physical coercion to provide TKey
   - Legal compulsion

---

## USS Derivation Implementation

### Problem with Original Implementation

In the original implementation, USS could be:

1. **Not used at all** (least secure)
2. **Stored in a file** and passed via `--uss PATH`

**Critical Weakness:** If USS is stored in initramfs (unencrypted `/boot` partition):

- An attacker with physical access to the disk can extract USS
- USS extraction: `unmkinitramfs /boot/initrd.img && cat usr/local/lib/tkey-luks/uss.bin`
- With stolen laptop + TKey + extracted USS, the attacker only needs to guess the password
- **3-factor authentication becomes 1-factor!**

### Improved Solution: Password-Derived USS

The improved implementation derives USS from the user's password using PBKDF2:

```text
USS = PBKDF2-HMAC-SHA256(password, salt, iterations=100000, length=32)
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

### Cryptographic Flow

**Complete end-to-end flow:**

```text
Stage 1: User Input
└─> User Password

Stage 2: USS Derivation (Client - v1.1.0+)
└─> USS = PBKDF2-HMAC-SHA256(password, machine-id, 100k iterations, 32 bytes)
    ├─> Salt sources (in priority order):
    │   1. /etc/machine-id (systemd) ✅
    │   2. /var/lib/dbus/machine-id
    │   3. /sys/class/dmi/id/product_uuid (hardware UUID)
    │   4. hostname (fallback)
    └─> USS = 32 bytes, never written to disk

Stage 3: Device Setup (TKey Firmware)
└─> CDI = Hash(UDS ⊕ DeviceApp ⊕ USS_derived)
    ├─> UDS: Unique Device Secret (hardware-embedded, unextractable)
    ├─> DeviceApp: Application binary hash
    └─> CDI now incorporates password!

Stage 4: Key Derivation (Device App)
└─> secret_key = Ed25519_KeyDerive(CDI)
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
  secret_key = Ed25519_derive(CDI)  // Contains USS
  LUKS_key = BLAKE2b(key=secret_key, data=password)
  ```

This provides **defense in depth**: compromising one layer doesn't compromise the other.

### Security Properties

- **Attack Resistance**:
  - Extract disk → No USS (derived from password)
  - Extract USS logic → No password (user knowledge)
  - Steal TKey → No password (user knowledge)
  - Steal TKey + disk → Still need password
  - Password + disk → Still need TKey (UDS)
  - Password + TKey → Still need system (machine-id salt)

- **Performance**: PBKDF2 adds ~100-200ms to boot time (100k iterations)
- **Deterministic**: Same password + same system = same key
- **System-Specific**: machine-id salt prevents key reuse across systems

---

## Usage & Configuration

### Recommended Approach (v1.1.0+)

```bash
# Enroll LUKS key using improved USS derivation
echo "your-password" | sudo tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --device /dev/ttyACM0 \
  --output /tmp/key.bin
sudo cryptsetup luksAddKey /dev/nvme0n1p6 /tmp/key.bin
sudo shred -u /tmp/key.bin
```

The `--derive-uss` flag enables automatic USS derivation from password.

### Advanced Options

#### Custom Salt

```bash
# Use custom salt instead of machine-id
tkey-luks-client \
  --challenge "my-password" \
  --derive-uss \
  --salt "my-custom-salt" \
  --output key.bin
```

**Warning**: If you use custom salt, you must ensure it's available during boot!

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

**Performance Guide:**

| Iterations | Security | Boot Delay |
|-----------|----------|------------|
| 100,000   | Good     | ~100ms     |
| 200,000   | Better   | ~200ms     |
| 500,000   | Best     | ~500ms     |
| 1,000,000 | Overkill | ~1s        |

### Backward Compatibility (Deprecated)

```bash
# Old approach: USS from file (LESS SECURE)
tkey-luks-client \
  --challenge "my-password" \
  --uss /path/to/uss.bin \
  --output key.bin
```

**Warning:** This approach is deprecated and will show security warnings.

---

## Migration Guide

### For New Installations

1. **Build and Install** with new code:
   ```bash
   ./scripts/build-all.sh
   sudo make -C client install
   sudo make -C device-app install
   sudo make -C initramfs-hooks install
   ```

2. **Add LUKS Key** using derived USS:
   ```bash
   echo "your-password" | sudo tkey-luks-client \
     --challenge-from-stdin \
     --derive-uss \
     --output /tmp/key.bin
   sudo cryptsetup luksAddKey /dev/nvme0n1p6 /tmp/key.bin
   sudo shred -u /tmp/key.bin
   ```

3. **Update initramfs**:
   ```bash
   sudo update-initramfs -u -k all
   # Look for: "✓ Copied machine-id for USS derivation"
   ```

4. **Test** by rebooting

### For Existing Installations (v1.0.x → v1.1.x)

#### Option 1: Fresh Setup (Recommended)

```bash
# 1. Add new key with derived USS
echo "your-password" | sudo tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --output - | \
sudo cryptsetup luksAddKey /dev/nvme0n1p6 -

# 2. Test new key works
echo "your-password" | sudo tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --output /tmp/test-key.bin

sudo cryptsetup luksOpen /dev/nvme0n1p6 test-mapper \
  --key-file=/tmp/test-key.bin

# 3. If successful, update initramfs and reboot to test
sudo update-initramfs -u
sudo reboot

# 4. After confirming boot works, remove old keyslot
sudo cryptsetup luksKillSlot /dev/nvme0n1p6 <old-slot-number>

# 5. Clean up old USS files
sudo rm -rf /boot/initramfs-uss/
sudo rm -f /etc/tkey-luks/uss.bin
```

#### Option 2: Parallel Keys (Safe Transition)

Keep both old USS file key and new derived USS key for a transition period:

1. Add new derived USS key (different keyslot)
2. Test thoroughly over several boots
3. Eventually remove old key after confidence established

---

## Attack Scenarios & Mitigations

### Scenario 1: Stolen Device with Disk Extraction

**Attack:** Thief steals laptop, extracts disk, attempts USS extraction

**Defense:**

| Approach | USS Stored? | Extractable? | Result |
|----------|-------------|--------------|--------|
| v1.0.x (OLD) | Yes (`/boot/initramfs`) | ✗ Yes | 3-factor → 1-factor |
| v1.1.0+ (NEW) | No (derived) | ✓ No | Remains 3-factor |

**Mitigation (v1.1.0+):** USS is ephemeral, derived at boot time  
**Residual Risk:** If TKey also stolen AND attacker guesses password

### Scenario 2: Evil Maid

**Attack:** Attacker modifies bootloader while device unattended

**Mitigation:**
- Enable Secure Boot (prevents unsigned bootloader)
- TPM-based boot integrity measurements
- Physical security (tamper-evident seals)
- BIOS/UEFI password

**Residual Risk:** Sophisticated attacks on firmware itself

### Scenario 3: Insider Access to Boot Files

**Attack:** Local attacker with root access extracts USS from `/boot`

**Defense:**

| Approach | USS Location | Root Access Impact |
|----------|--------------|-------------------|
| v1.0.x (OLD) | `/boot/initramfs-uss/` | ✗ Can extract USS |
| v1.1.0+ (NEW) | Not stored | ✓ Nothing to extract |

**Mitigation (v1.1.0+):** USS derived from password at boot time  
**Residual Risk:** Root access can install keylogger (need secure boot + tamper detection)

### Scenario 4: TKey Replication

**Attack:** Attacker attempts to clone TKey by extracting UDS

**Mitigation:**
- TKey secrets are hardware-protected (cannot extract UDS)
- Even with USS + password, need physical TKey hardware
- Touch requirement prevents automation

**Residual Risk:** Supply chain attacks on TKey manufacturing

### Scenario 5: Software Supply Chain Attack

**Attack:** Backdoored firmware extracts secrets from initramfs

**Defense:**

| Approach | Vulnerable Assets | Impact |
|----------|------------------|---------|
| v1.0.x (OLD) | USS file in plaintext | ✗ Firmware reads USS → bypass |
| v1.1.0+ (NEW) | USS derived in memory | ✓ No file to backdoor |

**Mitigation (v1.1.1+):**
- USS never touches filesystem
- Firmware signing and attestation
- Secure boot chain verification

**Residual Risk:** Malicious firmware could still keylog password during entry

### Scenario 6: USB Communication Sniffing

**Attack:** Intercept USB communication between client and TKey

**Mitigation:**
- Challenge-response protocol prevents replay
- LUKS key derived on TKey, never transmitted over USB
- USS derived before TKey communication (not sent)
- Password never sent in plaintext

**Residual Risk:** Physical USB interception reveals challenge data (but not USS or UDS)

### Scenario 7: DMA Attack

**Attack:** Use DMA-capable device (Thunderbolt, FireWire) to read RAM during boot

**Mitigation:**
- Enable IOMMU/VT-d protection
- Disable unnecessary boot-time PCI devices
- Minimize key lifetime in RAM
- Use dedicated USB port for TKey

**Residual Risk:** Key briefly exists in memory during unlock (~2-5 seconds)

### Scenario 8: Firmware Compromise

**Attack:** Compromise system firmware to capture keys or passwords

**Mitigation:**
- Use open firmware (coreboot/libreboot) if possible
- Regular firmware updates from trusted sources
- Firmware integrity verification (TPM)
- Hardware write-protection for firmware

**Residual Risk:** Nation-state level attacks on firmware supply chain

---

## Troubleshooting

### Common Issue: "Failed to unlock LUKS device" (v1.1.0)

**Symptoms:**
```
[   33.237635] tkey-luks: SUCCESS: Key derived successfully
[   38.684163] tkey-luks: FAILURE: Failed to unlock LUKS device
```

**Root Cause (Fixed in v1.1.1):**
- `/etc/machine-id` (used as salt) was not available in initramfs
- Setup used machine-id → USS₁
- Boot couldn't find machine-id → different/no salt → USS₂
- USS₁ ≠ USS₂ → Wrong LUKS key → Unlock failed

**Solution:**

1. **Update to v1.1.1+** (includes automatic fix)
2. **Rebuild initramfs:**
   ```bash
   sudo update-initramfs -u -k all
   # Look for: "✓ Copied machine-id for USS derivation"
   ```

3. **Verify salt availability:**
   ```bash
   cd test
   bash verify-salt-availability.sh
   ```

4. **Re-add LUKS keys:**
   ```bash
   # Old keys won't work with new USS
   cd test/luks-setup
   ./add-tkey-key.sh /dev/sdXY your-password
   ```

### Verifying Salt Consistency

Run the verification script to check if salt is available in initramfs:

```bash
cd test
bash verify-salt-availability.sh
```

**Expected output:**
```
✓ Found machine-id
✓ machine-id found in initramfs!
✓ Salt values MATCH!
✓ USS derivation will be consistent
```

### Manual Verification

```bash
# 1. Check current system salt
cat /etc/machine-id

# 2. Check salt in initramfs
sudo unmkinitramfs /boot/initrd.img-$(uname -r) /tmp/check
cat /tmp/check/main/etc/machine-id

# They should match!
```

### Debugging USS Derivation

Test USS derivation manually:

```bash
cd test
bash test-improved-uss.sh
```

Should show:
```
Using machine-id for salt
USS derived successfully using PBKDF2 (100000 iterations)
USS (hex): [consistent 32-byte hex value]
```

**The hex value should be identical across multiple runs with the same password.**

### Issue: "could not determine system salt"

**Cause:** System has no machine-id

**Solution:**
```bash
# Generate machine-id
sudo systemd-machine-id-setup
cat /etc/machine-id

# Rebuild initramfs
sudo update-initramfs -u -k all

# Re-add LUKS keys
```

### Salt Security Notes

**Q: Is including machine-id in initramfs safe?**

**A:** Yes, because:

1. machine-id is **not a secret** (world-readable: `ls -la /etc/machine-id`)
2. Real security comes from:
   - Password (user knowledge)
   - TKey's UDS (hardware secret, unextractable)
   - Physical TKey possession
   - Touch confirmation

3. machine-id provides:
   - System-specific USS (prevents key reuse across machines)
   - Consistent USS derivation (same password → same USS)

**Security layers remain intact:** Password + TKey hardware + UDS + Touch

---

## Best Practices

### Password Selection

- **Minimum:** 16 characters (recommended: 20+)
- **Entropy:** Use passphrase (4-6 random words) or random characters
- **Avoid:** Dictionary words, personal info, keyboard patterns
- **Rationale:** Password protects USS derivation + BLAKE2b challenge (double use)

### Physical Security

- Store TKey separately from laptop when possible
- Use tamper-evident storage for TKey
- Never leave TKey inserted during transport
- Consider two TKeys (primary + backup in different keyslots)

### System Configuration

1. **Enable Secure Boot**
   - Prevents unsigned bootloader execution
   - Protects initramfs integrity
   - Mitigates evil maid attacks

2. **BIOS/UEFI Security**
   - Set BIOS/UEFI password
   - Disable unnecessary boot devices
   - Disable USB boot (or restrict to specific devices)

3. **Monitor Salt Stability**
   - `/etc/machine-id` should never change
   - If machine-id changes, re-add all LUKS keys!
   - Backup machine-id value in secure location

4. **IOMMU Protection**
   - Enable IOMMU/VT-d in BIOS
   - Add `intel_iommu=on` or `amd_iommu=on` to kernel parameters
   - Protects against DMA attacks

### Emergency Access Planning

- **Always maintain emergency password keyslot** (independent of TKey)
- Test emergency password quarterly
- Store emergency password in secure offline location
- Document USS derivation parameters if using non-defaults

### Key Management

1. **Multiple TKeys**
   ```bash
   # Add backup TKey to different keyslot
   echo "your-password" | sudo tkey-luks-client \
     --challenge-from-stdin \
     --derive-uss \
     --output - | \
   sudo cryptsetup luksAddKey /dev/sdaX - --key-slot 1
   ```

2. **Emergency Password**
   ```bash
   # Always maintain password-based keyslot
   sudo cryptsetup luksAddKey /dev/sdaX
   # Use DIFFERENT password from TKey
   ```

3. **LUKS Header Backup**
   ```bash
   # Backup LUKS header
   cryptsetup luksHeaderBackup /dev/sdaX \
     --header-backup-file header.backup
   # Store in secure offline location
   ```

### Operational Security

- USS derivation happens in cleartext memory (enroll in secure environment)
- Password entry visible to onlookers (shield keyboard during boot)
- Clear bash history after enrollment (`history -c`)
- Review boot logs for failed unlock attempts
- Monitor for unauthorized LUKS keyslot changes

### Recommended LUKS Settings

- **Cipher:** aes-xts-plain64 (default)
- **Key Size:** 512 bits (for XTS mode)
- **Hash:** sha256 or sha512
- **PBKDF:** argon2id (LUKS2) or pbkdf2 (LUKS1)
- **Keyslot Allocation:**
  - Slot 0: Primary TKey
  - Slot 1: Backup TKey
  - Slot 7: Emergency password (different from TKey password)

---

## Compliance & Audit

### Security Audit Checklist

- [ ] Secure Boot enabled and configured
- [ ] Bootloader integrity verification active
- [ ] Initramfs signature validation enabled
- [ ] TKey enrollment tested and documented
- [ ] Backup TKey configured in separate keyslot
- [ ] Emergency password set (different from TKey)
- [ ] IOMMU/VT-d enabled in BIOS
- [ ] Unnecessary boot devices disabled
- [ ] Boot logs monitored for failed attempts
- [ ] LUKS header backed up offline
- [ ] Key rotation schedule defined
- [ ] Incident response plan documented
- [ ] Recovery procedures tested
- [ ] Machine-id backup stored securely

### Compliance Considerations

#### FIPS 140-2

- Evaluate TKey FIPS compliance status
- Use FIPS-approved algorithms
- Consider additional layers if FIPS required
- Document cryptographic module usage

#### GDPR/Data Protection

- Document key management procedures
- Define data breach response plan
- Consider key escrow requirements
- Maintain audit trail of key operations

#### Industry Standards

- Align with NIST SP 800-111 (Storage Encryption)
- Follow NIST SP 800-132 (PBKDF recommendations)
- Implement security frameworks (CIS, NIST CSF)
- Regular security assessments

### Deployment Checklist

1. **Pre-Deployment**
   - [ ] Test in VM/staging environment
   - [ ] Document salt configuration
   - [ ] Plan key rotation schedule
   - [ ] Define emergency procedures
   - [ ] Test backup TKey enrollment
   - [ ] Verify emergency password works

2. **Deployment**
   - [ ] Enable Secure Boot
   - [ ] Configure BIOS security
   - [ ] Enroll TKey with strong password
   - [ ] Add backup TKey
   - [ ] Set emergency password
   - [ ] Backup LUKS header
   - [ ] Test boot with TKey
   - [ ] Test boot with emergency password
   - [ ] Document all credentials securely

3. **Post-Deployment**
   - [ ] Monitor boot logs
   - [ ] Schedule regular testing
   - [ ] Review security posture quarterly
   - [ ] Update firmware as available
   - [ ] Rotate keys per schedule

---

## Responsible Disclosure

If you discover a security vulnerability in this project, please:

1. **Do NOT** publish details publicly
2. Contact maintainers privately via GitHub Security Advisories
3. Allow reasonable time for fix (90 days recommended)
4. Coordinate disclosure timeline
5. Receive credit in acknowledgments (if desired)

---

## References

### TKey & Tillitis

- [Tillitis TKey Security Architecture](https://dev.tillitis.se/)
- [TKey Hardware Documentation](https://tillitis.se/)
- [TKey Firmware Source](https://github.com/tillitis/tkey-device-signer)

### Cryptography & Standards

- [PBKDF2 Specification (RFC 2898)](https://datatracker.ietf.org/doc/html/rfc2898)
- [BLAKE2 Specification](https://blake2.net/)
- [NIST Key Management Guidelines](https://csrc.nist.gov/publications)
- [NIST SP 800-132: PBKDF Recommendations](https://csrc.nist.gov/publications/detail/sp/800-132/final)

### LUKS & Storage Encryption

- [LUKS Specification](https://gitlab.com/cryptsetup/LUKS2-docs)
- [cryptsetup FAQ](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/FrequentlyAskedQuestions)
- [LUKS Security](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/home)

### Attack Vectors

- [DMA Attack Mitigation](https://en.wikipedia.org/wiki/DMA_attack)
- [Evil Maid Attacks](https://www.schneier.com/blog/archives/2009/10/evil_maid_attac.html)
- [Cold Boot Attacks](https://en.wikipedia.org/wiki/Cold_boot_attack)

### Related Documentation

- [INITRAMFS.md](INITRAMFS.md) - Integration guide
- [SETUP.md](SETUP.md) - Installation instructions
- [TESTING.md](TESTING.md) - Test procedures
- [VERSION.md](../VERSION.md) - Changelog & release notes

---

## Support

- **GitHub Issues**: <https://github.com/No-0n3/tkey-luks/issues>
- **Documentation**: <https://github.com/No-0n3/tkey-luks/tree/master/docs>
- **Security**: Use GitHub Security Advisories for sensitive reports
