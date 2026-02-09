# Security Considerations for TKey-LUKS

## Security Model Overview

**TKey-LUKS v1.1.0+** uses an **improved USS (User Supplied Secret) derivation** approach that provides defense-in-depth by using your password in two independent cryptographic layers.

### Key Security Features

1. **Password-Derived USS** - USS is derived from your password using PBKDF2, never stored
2. **Double Password Protection** - Password used in both USS derivation and challenge
3. **Hardware Root of Trust** - TKey's UDS (Unique Device Secret) cannot be extracted
4. **Physical Touch Requirement** - Prevents remote/automated attacks
5. **System-Specific** - Machine-id salt makes USS unique per installation

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

3. **Limited Protection Against Cold Boot Attacks**
   - Key exists in RAM only during boot
   - Minimized time window
   - No persistent key storage

### What This System Does NOT Protect Against

1. **Physical Access with TKey Present**
   - If attacker has both device and TKey, they can boot if password is gotten
   - Consider this when storing TKey and device together

2. **Evil Maid Attacks on Bootloader**
   - Modified bootloader can capture keystrokes or compromise initramfs
   - Mitigation: Use UEFI Secure Boot
   - Mitigation: Boot from read-only media

3. **Compromised Initramfs**
   - Malicious initramfs can extract key during boot
   - Mitigation: Secure Boot with signed initramfs

4. **Advanced Physical Attacks**
   - DMA attacks (e.g., Thunderbolt/FireWire)
   - Hardware implants
   - Chip-level attacks on TKey

5. **Rubber Hose Cryptanalysis**
   - Physical coercion to provide TKey
   - Legal compulsion

## Security Features

### Hardware-Based Key Derivation

**Improved USS Derivation (v1.1.0+):**

The TKey device uses a multi-layer key derivation approach:

#### Layer 1: USS Derivation (Client-Side)

```text
USS = PBKDF2-HMAC-SHA256(password, machine-id, 100000 iterations, 32 bytes)
```

- **Input:** User password (never stored)
- **Salt:** System machine-id (unique per installation)
- **Iterations:** 100,000 (configurable)
- **Output:** 32-byte USS (ephemeral, never written to disk)

#### Layer 2: CDI Generation (TKey Firmware)

```text
CDI = Hash(UDS ⊕ DeviceApp ⊕ USS)
```

- **UDS:** Unique Device Secret (hardware-embedded, unextractable)
- **DeviceApp:** Application binary hash
- **USS:** Password-derived secret from Layer 1
- **CDI:** Compound Device Identifier (TKey internal state)

#### Layer 3: Key Derivation (Device App)

```text
secret_key = Ed25519_KeyDerive(CDI)
LUKS_key = BLAKE2b(key=secret_key, data=password)
```

- **secret_key:** Derived from CDI (contains USS)
- **Challenge:** Same password used in Layer 1
- **LUKS_key:** Final 64-byte encryption key

**Security Properties:**

- Password used in **TWO independent layers** (USS derivation + BLAKE2b challenge)
- USS never exposed to filesystem or network
- Device-unique via UDS (cannot emulate without physical TKey)
- System-unique via machine-id salt
- Strong KDF prevents brute-force (100k iterations)
- Physical touch required (prevents automation)

### Key Derivation Process

**Full Cryptographic Flow:**

```text
User Input: password
    ↓
[Client: PBKDF2]
    USS = PBKDF2(password, machine-id, 100k)
    ↓
[TKey Firmware]
    CDI = Hash(UDS ⊕ App ⊕ USS)
    ↓
[Device App: Ed25519]
    secret_key = KeyDerive(CDI)
    ↓
[Device App: BLAKE2b]
    LUKS_key = BLAKE2b(key=secret_key, data=password)
    ↓
[LUKS Unlock]
    cryptsetup luksOpen --key-file=<LUKS_key>
```

**Attack Resistance:**

- Extract disk → No USS (derived from password)
- Extract USS logic → No password (user knowledge)
- Steal TKey → No password (user knowledge)
- Steal TKey + disk → Still need password
- Password + disk → Still need TKey (UDS)
- Password + TKey → Still need system (machine-id salt)

### Physical Touch Requirement

- TKey requires physical button press to derive key
- Each unlock attempt needs user presence
- Prevents automated/remote attacks
- Natural rate limiting through physical interaction

## Best Practices

### Password Selection (USS Derivation)

- **Minimum:** 16 characters (recommended: 20+)
- **Entropy:** Use passphrase (4-6 random words) or random characters
- **Avoid:** Dictionary words, personal info, keyboard patterns
- **Rationale:** Password protects USS derivation + BLAKE2b challenge (double use)

### Physical Security

- Store TKey separately from laptop (reduces theft risk)
- Use tamper-evident bag for TKey storage
- Never leave TKey inserted during transport
- Consider two TKeys (primary + backup with different keyslot)

### System Configuration

- Enable secure boot (prevents initramfs tampering)
- Set BIOS/UEFI password (prevents boot device changes)
- Disable USB boot in BIOS (reduces evil maid attacks)
- Monitor /etc/machine-id integrity (salt changes = USS changes!)

### Migration from Old USS Files

If upgrading from v1.0.x (file-based USS):

```bash
# 1. Enroll with improved USS derivation (new keyslot)
echo "password" | sudo tkey-luks-client --derive-uss --challenge-from-stdin \
  --output - | sudo cryptsetup luksAddKey /dev/sdaX -

# 2. Test new keyslot boots successfully
sudo update-initramfs -u && reboot

# 3. After confirming boot works, remove old keyslot
sudo cryptsetup luksKillSlot /dev/sdaX <old-slot-number>

# 4. Delete old USS files
sudo rm -rf /boot/initramfs-uss/
```

### Emergency Access Planning

- **Always maintain emergency password keyslot** (independent of TKey)
- Test emergency password quarterly
- Store emergency password in secure location (safe, password manager)
- Document USS derivation parameters (if non-default iterations/salt)

### Operational Security

- USS derivation happens in cleartext memory (choose secure environments for enrollment)
- Password entry visible to on-lookers (shield keyboard during boot)
- System logs may contain tkey-luks-client command history (clear bash history after enrollment)
- Consider hardware security key for emergency keyslot (YubiKey, etc.)

### Deployment

1. **Use Secure Boot**
   - Enable UEFI Secure Boot
   - Sign bootloader and kernel
   - Verify initramfs integrity

2. **TKey Storage**
   - Store TKey separately from device when possible
   - Use dedicated TKey for boot (not shared with other purposes)
   - Consider multiple TKeys for redundancy

3. **Backup Strategy**
   - Enroll multiple TKeys in LUKS keyslots
   - Keep backup TKey in secure location
   - Maintain emergency password in separate keyslot

4. **Physical Security**
   - Secure BIOS/UEFI with password
   - Disable unnecessary boot devices
   - Consider disabling USB ports except needed ones

### Operational Procedures

1. **Key Rotation**
   - Periodically re-enroll TKeys
   - Rotate LUKS keys
   - Remove old keyslots

2. **Monitoring**
   - Review boot logs regularly
   - Alert on failed unlock attempts
   - Monitor for unauthorized access

3. **Incident Response**
   - Document procedure for lost TKey
   - Plan for emergency recovery
   - Test backup procedures

## Attack Scenarios and Mitigations

### Scenario 1: Stolen Device with Disk Extraction

**Attack:** Thief steals laptop, extracts disk, attempts USS extraction

**Defense:**

- ❌ OLD: USS stored in /boot/initramfs → Extractable → 3-factor becomes 1-factor!
- ✅ NEW: USS derived from password → Not stored → Cannot extract

**Mitigation (v1.1.0+):** USS is ephemeral, derived at boot time
**Residual Risk:** If TKey also stolen AND attacker guesses password

### Scenario 2: Evil Maid

**Attack:** Attacker modifies bootloader while device unattended

**Mitigation:**

- Secure Boot prevents unsigned bootloader
- TPM-based boot integrity measurements
- Physical security

### Scenario 3: Insider Access to Boot Files

**Attack:** Local attacker with root access extracts USS from /boot

**Defense:**

- ❌ OLD: USS file in /boot/initramfs-uss/ → Root access = USS extraction
- ✅ NEW: No USS files stored → Nothing to extract

**Mitigation (v1.1.0+):** USS derived from password at boot time  
**Residual Risk:** Root access can install keylogger (use full disk encryption + secure boot)

### Scenario 4: TKey Replication

**Attack:** Attacker attempts to clone TKey
**Mitigation:** TKey secrets not extractable (hardware security)
**Residual Risk:** Supply chain attacks on TKey manufacturing

### Scenario 5: Software Supply Chain Attack

**Attack:** Backdoored firmware extraction from initramfs

**Defense:**

- ❌ OLD: USS in plaintext initramfs → Firmware reads USS file → Key material exposed
- ✅ NEW: USS derived in memory → No file to backdoor

**Mitigation (v1.1.0+):** USS never touches filesystem  
**Additional Defense:** Firmware signing, attestation, secure boot  
**Residual Risk:** Malicious firmware could keylog password (verify firmware hashes!)

### Scenario 6: USB Communication Sniffing

**Attack:** Intercept USB communication between client and TKey

**Mitigation:**

- Challenge-response prevents replay attacks
- LUKS key derived on TKey, never transmitted
- USS derived before TKey communication (not sent over USB)
- Password never sent in plaintext

**Residual Risk:** Physical USB interception still reveals challenge data (but not USS)

### Scenario 7: DMA Attack

**Attack:** Use DMA-capable device to read RAM during boot

**Mitigation:**

- IOMMU protection
- Disable unnecessary boot-time devices
- Minimize key lifetime in RAM

**Residual Risk:** Key briefly exists in memory during unlock

### Scenario 8: Firmware Compromise

**Attack:** Compromise system firmware to capture keys

**Mitigation:**

- Use open firmware (coreboot/libreboot) if possible
- Regular firmware updates
- Firmware integrity verification

## Key Management

### Initial Enrollment (Improved Method)

```bash
# Improved USS derivation (v1.1.0+)
echo "your-password" | sudo tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --output - | \
sudo cryptsetup luksAddKey /dev/sdaX -
```

**This process:**

1. Derives USS from password using PBKDF2 (100k iterations)
2. Loads device app to TKey with derived USS
3. Waits for physical touch
4. Derives LUKS key using USS + password (double protection)
5. Adds key to LUKS keyslot

**Security notes:**

- USS never stored on disk
- Password used in two independent layers
- System-specific via machine-id salt
- TKey touch required (prevents automation)

### Multiple TKeys

```bash
# Add backup TKey to different keyslot using same password
echo "your-password" | sudo tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --output - | \
sudo cryptsetup luksAddKey /dev/sdaX - --key-slot 1

# Note: Use same password for both TKeys for convenience
# Or use different passwords for defense-in-depth
```

### Emergency Password

```bash
# Always maintain password-based keyslot (independent of TKey)
sudo cryptsetup luksAddKey /dev/sdaX
# Enter existing password when prompted
# Then enter NEW emergency password (different from TKey password)
```

## LUKS Configuration

### Recommended Settings

- **Cipher:** aes-xts-plain64 (default)
- **Key Size:** 512 bits (for XTS)
- **Hash:** sha256 or sha512
- **PBKDF:** argon2id (LUKS2) or pbkdf2 (LUKS1)
- **Keyslot Allocation:**
  - Slot 0: Primary TKey
  - Slot 1: Backup TKey
  - Slot 7: Emergency password

### LUKS Header Backup

```bash
# Backup LUKS header (contains challenges)
cryptsetup luksHeaderBackup /dev/sdaX --header-backup-file header.backup

# Store backup in secure offline location
```

## Compliance Considerations

### FIPS 140-2

- Evaluate TKey FIPS compliance status
- Use FIPS-approved algorithms
- Consider additional layers if FIPS required

### GDPR/Data Protection

- Document key management procedures
- Define data breach response
- Consider key escrow requirements

### Industry Standards

- Align with NIST guidelines
- Follow industry security frameworks
- Regular security assessments

## Security Audit Checklist

- [ ] Secure Boot enabled and configured
- [ ] Bootloader integrity verification
- [ ] initramfs signature validation
- [ ] TKey enrollment tested
- [ ] Backup TKey configured
- [ ] Emergency password set
- [ ] IOMMU/VT-d enabled
- [ ] Unnecessary boot devices disabled
- [ ] Boot logs monitored
- [ ] LUKS header backed up
- [ ] Key rotation schedule defined
- [ ] Incident response plan documented
- [ ] Recovery procedures tested

## Responsible Disclosure

If you discover a security vulnerability in this project, please:

1. Do NOT publish details publicly
2. Contact maintainers privately
3. Allow reasonable time for fix
4. Coordinate disclosure timeline

## References

- [Tillitis TKey Security Architecture](https://dev.tillitis.se/)
- [LUKS Security](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/FrequentlyAskedQuestions)
- [NIST Key Management Guidelines](https://csrc.nist.gov/publications)
- [DMA Attack Mitigation](https://en.wikipedia.org/wiki/DMA_attack)
