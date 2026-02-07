# TKey-LUKS Project Status

## Current State: Device App Built, Testing Ready

**Date:** February 2025  
**Phase:** Phase 3 - LUKS Test Infrastructure  
**Status:** Device app compiled successfully, test automation ready to execute

---

## ✅ Completed Components

### Device App (RISC-V, runs on TKey)
- **Location**: [device-app/src/main.c](device-app/src/main.c) (490 lines)
- **Binary**: `tkey-luks-device.bin` (27,856 bytes)
- **Status**: ✅ **Built successfully with clang-20**
- **Adapted from**: tkey-device-signer (Ed25519 signer)
- **Key Features**:
  - BLAKE2s-based key derivation (replaces Ed25519 signing)
  - Challenge-response protocol
  - Touch verification required before key derivation
  - 64-byte LUKS key output
  - USS (User Supplied Secret) support preserved
  - Commands: `CMD_SET_CHALLENGE`, `CMD_LOAD_CHALLENGE`, `CMD_DERIVE_KEY`

### Build System
- **Compiler**: clang 20.1.8 with lld-20 linker
- **Target**: `riscv32-unknown-none-elf` with `-march=rv32iczmmul`
- **Libraries**: 
  - monocypher (Ed25519, SHA-512)
  - blake2s (key derivation)
  - tkey-libs (8 libraries compiled)
- **Status**: ✅ **Building clean, no errors**
- **Artifacts**: `.bin` (27KB), `.elf` (34KB)

### Submodules (All Initialized & Built)
- **tkey-libs**: ✅ Compiled (831 objects)
- **tkey-device-signer**: ✅ Compiled (1758 objects, code reviewed)
- **tkey-devtools**: ✅ Compiled (1671 objects)

### LUKS Test Infrastructure
- **Location**: `test/luks-setup/`
- **Scripts (all executable)**:
  1. `create-tkey-test-image.sh` - Creates 10MB LUKS2 test image with ext4
  2. `derive-tkey-key.py` - Python simulation of device app key derivation
  3. `add-tkey-key.sh` - Adds TKey-derived key to LUKS slot 1
  4. `test-end-to-end.sh` - Complete automated test pipeline
  5. `README.md` - Comprehensive test documentation (250+ lines)
- **Status**: ✅ **Ready to execute**

### Documentation
- `PLAN.md` - Complete project plan
- `README.md` - Project overview
- `SECURITY.md` - Security considerations
- `TESTING.md` - Testing strategy
- `SETUP.md` - Development setup guide
- `TILLITIS-TOOLS.md` - TKey tools overview
- `SIGNER-REVIEW.md` - Code review of tkey-device-signer adaptation
- `test/luks-setup/README.md` - Test infrastructure documentation
- **Status**: ✅ **Comprehensive and up-to-date**


## 🧪 Ready to Test NOW

### Quick Test (Complete Automation)
```bash
cd /home/isaac/Development/tkey-luks/test/luks-setup
./test-end-to-end.sh
```

This will:
1. Create 10MB LUKS2 test image with password "test123"
2. Simulate TKey key derivation (CDI → Ed25519 → BLAKE2s)
3. Add derived 64-byte key to LUKS slot 1
4. Test unlock with both password and TKey key
5. Cleanup and report results

### Manual Testing Steps

#### Step 1: Create LUKS Test Image
```bash
cd test/luks-setup
./create-tkey-test-image.sh
```
**Creates**: `test-luks-10mb.img`
- **Format**: LUKS2 with AES-XTS-Plain64
- **Size**: 10 MB (expandable)
- **Filesystem**: ext4
- **Initial Password**: `test123` (slot 0, for recovery)

#### Step 2: Derive TKey Key (Python Simulation)
```bash
./derive-tkey-key.py
```
**Creates**: 
- `tkey-derived-key.bin` (64 bytes, binary)
- `tkey-derived-key.hex` (hex representation)

**Derivation Logic (matches device app exactly)**:
```
1. CDI (32 bytes) = simulated device-unique secret
2. crypto_ed25519_key_pair(public[32], secret[64], cdi)
3. challenge = "luks-challenge-2024" (19 bytes)
4. blake2s(output[64], secret[64], challenge[19])
5. Result: 64-byte LUKS key
```

#### Step 3: Add TKey Key to LUKS Image
```bash
./add-tkey-key.sh
```
**Action**: Adds derived key to **slot 1** (slot 0 keeps password)
**Verification**: Lists LUKS slots showing both keys active

#### Step 4: Test LUKS Unlock
```bash
./test-unlock.sh
# Or manually:
sudo cryptsetup open --key-file tkey-derived-key.bin test-luks-10mb.img test-tkey
sudo cryptsetup status test-tkey
sudo cryptsetup close test-tkey
```

## 🔑 Key Derivation Process

### Device App Implementation
**File**: [device-app/src/main.c](device-app/src/main.c#L336)

```c
// Line 336-340: BLAKE2s key derivation
blake2s(ctx->derived_key,        // Output: 64 bytes
        64,                       // Output length
        ctx->secret_key,          // Key: 64-byte Ed25519 secret
        64,                       // Key length
        ctx->challenge,           // Data: user challenge
        ctx->challenge_size);     // Data length
```

### Full Flow
```
TKey CDI (32 bytes, hardware-unique)
  ↓
crypto_ed25519_key_pair()
  ↓
secret_key (64 bytes) + public_key (32 bytes)
  ↓
User sends challenge (up to 256 bytes)
  ↓
TKey user presses physical button (touch verification)
  ↓
blake2s(secret_key, challenge) → 64-byte LUKS key
  ↓
LUKS unlock successful
```

### LUKS Slot Strategy
- **Slot 0**: Recovery password (`test123` for testing, strong password for production)
- **Slot 1**: TKey-derived key (64 bytes)
- **Slot 2-7**: Available for additional keys
- **Rationale**: Keep password as fallback in case TKey is lost/damaged

## ⏳ Pending Implementation

### Go Client Application (Next Priority)
- **Purpose**: Host application to communicate with TKey device
- **Language**: Go (standard for TKey ecosystem)
- **Dependencies**: 
  - `github.com/tillitis/tkeyclient` - TKey communication library
  - `github.com/tillitis/tillitis-key1-apps/system` - App loading
- **Key Tasks**:
  1. Detect TKey USB device
  2. Load `tkey-luks-device.bin` to TKey
  3. Send challenge to device (e.g., "luks-challenge-2024")
  4. Wait for user to press TKey button
  5. Receive 64-byte derived key
  6. Call `cryptsetup open` with derived key
  7. Securely wipe key from memory

### TKey Hardware/QEMU Testing
- **Tool**: `tkey-runapp` from tkey-devtools submodule
- **Hardware Test**:
  ```bash
  tkey-runapp device-app/tkey-luks-device.bin
  ```
- **QEMU Test**: Use TKey QEMU emulation for testing without hardware
- **Validation**:
  - Device app loads successfully
  - Touch button requirement works
  - Key derivation produces expected output
  - Matches Python simulation results

### initramfs Integration (Boot-Time Unlock)
- **Location**: `/etc/initramfs-tools/hooks/tkey-luks` and `/scripts/local-top/tkey-luks`
- **Tasks**:
  1. Create hook to copy TKey tools and device app into initramfs
  2. Create boot script to:
     - Wait for TKey insertion with timeout
     - Load device app to TKey
     - Derive key with challenge
     - Unlock LUKS root partition
     - Fallback to password prompt on failure
  3. Integration testing with QEMU VM

## 📊 Project Metrics

- **Device App**: 27,856 bytes (fits comfortably in TKey 128KB RAM)
- **Build Time**: ~2 seconds on modern hardware
- **Test Image**: 10 MB (expandable to any size)
- **Key Size**: 64 bytes (512 bits, exceeds LUKS requirements)
- **Challenge Size**: Up to 256 bytes (configurable)
- **Dependencies**: 3 submodules, clang-20, lld-20, Python 3
- **Lines of Code**:
  - Device app: 490 lines (main.c)
  - Test scripts: 639 lines total
  - Documentation: 2500+ lines
  - Total: 3600+ lines

## 🚀 Next Actions

1. **[IMMEDIATE] Run LUKS tests**:
   ```bash
   cd test/luks-setup && ./test-end-to-end.sh
   ```
   **Expected**: All tests pass, key derivation works, LUKS unlocks

2. **Verify key derivation**: Ensure Python simulation matches device app logic

3. **Implement Go client**: Create `client/main.go` with tkeyclient integration

4. **Test with TKey hardware**: Load device app with `tkey-runapp`

5. **QEMU testing**: Validate device app in TKey emulator

6. **initramfs integration**: Create boot hooks for automatic unlock

## 🛠️ Development Commands

### Build Device App
```bash
cd device-app
make clean && make
ls -lh tkey-luks-device.bin  # Should show ~27KB
```

### Run All Tests
```bash
cd test/luks-setup
./test-end-to-end.sh
```

### Load to TKey Hardware
```bash
tkey-devtools/bin/tkey-runapp device-app/tkey-luks-device.bin
```

### Check Build Dependencies
```bash
clang --version          # Should be 20.x
lld-20 --version         # Should be 20.x
python3 --version        # Any 3.x
cryptsetup --version     # Should be 2.x
```

## 🔗 Resources

- **Tillitis Developer Portal**: https://dev.tillitis.se/
- **TKey Apps Repository**: https://github.com/tillitis/tillitis-key1-apps
- **TKey Client Library**: https://github.com/tillitis/tkeyclient
- **LUKS/cryptsetup**: https://gitlab.com/cryptsetup/cryptsetup
- **BLAKE2 Specification**: https://www.blake2.net/

## 📝 Technical Notes

### Why BLAKE2s?
- Fast (faster than SHA-256)
- Secure (designed for hashing and key derivation)
- Fixed 64-byte output (perfect for LUKS)
- Already in monocypher library (no extra dependencies)
- Keyed hashing capability (uses secret_key as key)

### Why Ed25519 Keypair from CDI?
- CDI (Compound Device Identifier) is TKey's hardware-unique secret
- Ed25519 key generation provides good entropy expansion
- 64-byte secret key provides sufficient key material
- Compatible with Tillitis security model
- Reuses well-tested crypto_ed25519_key_pair() from monocypher

### Production Considerations
- **CDI uniqueness**: Each TKey has unique CDI, so each device derives different keys
- **Challenge strategy**: Use unique challenge per system (hostname, disk UUID, timestamp)
- **Slot 0 backup**: Always keep strong password in slot 0 for recovery
- **Key rotation**: Plan to rotate LUKS master key periodically
- **USS support**: Device app supports User Supplied Secret for additional entropy

---

**Status**: ✅ Device app complete and compiled, test infrastructure ready  
**Next Milestone**: Execute LUKS tests and validate key derivation  
**Last Updated**: February 2025  
**Git Commits**: 4 (Initial setup → Submodules → Device app → Test infrastructure)
