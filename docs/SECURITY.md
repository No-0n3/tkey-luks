# Security Considerations for TKey-LUKS

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
   - If attacker has both device and TKey, they can boot
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

The TKey device contains unique secrets that cannot be extracted. Keys are derived using:
- Device serial number (USS - Unique Device Secret)
- Application-specific secrets
- Cryptographic operations performed in secure hardware

### Key Derivation Process

```
TKey USS → HMAC/Sign(challenge) → KDF → LUKS Key
```

1. Client generates or retrieves challenge
2. TKey signs challenge with device-unique key
3. Client applies KDF (PBKDF2/HKDF) to signature
4. Result used as LUKS key

### Rate Limiting

- Maximum unlock attempts before lockout
- Exponential backoff on failures
- Prevents brute force attempts

### Audit Logging

- All unlock attempts logged (after successful boot)
- Failed attempts tracked
- TKey serial number logged

## Best Practices

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

### Operational Security

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

### Scenario 1: Stolen Device

**Attack:** Thief steals laptop
**Mitigation:** TKey required for boot, device remains encrypted
**Residual Risk:** If TKey also stolen

### Scenario 2: Evil Maid

**Attack:** Attacker modifies bootloader while device unattended
**Mitigation:** 
- Secure Boot prevents unsigned bootloader
- TPM-based boot integrity measurements
- Physical security

### Scenario 3: TKey Replication

**Attack:** Attacker attempts to clone TKey
**Mitigation:** TKey secrets not extractable (hardware security)
**Residual Risk:** Supply chain attacks on TKey manufacturing

### Scenario 4: USB Sniffing

**Attack:** Intercept communication between client and TKey
**Mitigation:** 
- Challenge-response prevents replay
- Key derived from signature, not transmitted
- TKey protocol uses secure communication

### Scenario 5: DMA Attack

**Attack:** Use DMA-capable device to read RAM during boot
**Mitigation:**
- IOMMU protection
- Disable unnecessary boot-time devices
- Minimize key lifetime in RAM

### Scenario 6: Firmware Compromise

**Attack:** Compromise system firmware to capture keys
**Mitigation:**
- Use open firmware (coreboot/libreboot) if possible
- Regular firmware updates
- Firmware integrity verification

## Key Management

### Initial Enrollment

```bash
# Generate initial LUKS key from TKey
tkey-luks-enroll /dev/sdaX

# This process:
# 1. Generates random challenge
# 2. Stores challenge in LUKS header
# 3. Derives key from TKey signature
# 4. Adds key to LUKS keyslot
```

### Multiple TKeys

```bash
# Add backup TKey to different keyslot
tkey-luks-enroll --keyslot 1 /dev/sdaX

# Each TKey gets unique challenge
# Independent key derivation
```

### Emergency Password

```bash
# Always maintain password-based keyslot
cryptsetup luksAddKey /dev/sdaX
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
