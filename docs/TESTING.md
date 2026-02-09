# Testing Guide

## Overview

This guide covers testing procedures for the TKey-LUKS system with improved USS derivation.

## Test Structure

```text
test/
├── README.md                     # Test documentation
├── test-improved-uss.sh          # Live USS derivation test with TKey
├── test-tkey-unlock.sh           # Full unlock test with TKey
├── test-uss-derivation.sh        # USS derivation demo (no TKey needed)
└── luks-setup/                   # LUKS test image tools
    ├── create-tkey-test-image.sh # Create test LUKS image
    ├── add-tkey-key.sh           # Add TKey key to existing LUKS
    ├── test-unlock.sh            # Test unlock with image
    └── README.md                 # LUKS setup documentation
```

## Prerequisites

### Hardware Requirements

- Tillitis TKey hardware device (for hardware tests)
- USB port for TKey connection
- x86_64 Linux system

### Software Requirements

- Linux kernel 5.x or later (with LUKS support)
- cryptsetup
- Go 1.21+ (for building client)
- LLVM/Clang 15+ with riscv32 support (for building device app)

## Quick Start

### Build Everything

```bash
# Build client and device app
./scripts/build-all.sh
```

### Run USS Derivation Test (No Hardware Needed)

```bash
cd test
./test-uss-derivation.sh
```

This demonstrates:

- System salt detection (machine-id)
- USS derivation from password
- PBKDF2 parameter effects
- Deterministic output verification

### Run Live TKey Tests (Hardware Required)

```bash
cd test

# Test 1: USS derivation with real TKey
./test-improved-uss.sh

# Test 2: Full unlock scenario
./test-tkey-unlock.sh
```

What these test:

- TKey device detection
- Device app loading
- USS derivation from password
- Physical touch requirement
- Key derivation and signing
- Full LUKS unlock workflow

## Test Categories

### 1. USS Derivation Tests

#### Software-Only Test (No TKey)

```bash
cd test
./test-uss-derivation.sh
```

Tests:

- Machine-id salt detection
- PBKDF2 USS derivation
- Deterministic output
- Custom salt support
- Iteration count effects

#### Hardware USS Test (With TKey)

```bash
cd test
./test-improved-uss.sh
```

Tests:

- TKey detection at /dev/ttyACM0
- Device app loading with USS
- Touch sensor activation
- Key derivation with USS
- Multiple unlock attempts

### 2. Full Integration Tests

#### Complete Unlock Test

```bash
cd test
./test-tkey-unlock.sh
```

Tests:

1. TKey detection
2. USS derivation (PBKDF2)
3. Device app loading
4. Touch requirement
5. Key derivation (BLAKE2b)
6. LUKS image creation
7. Keyslot enrollment
8. Successful unlock

### 3. LUKS Image Tests

#### Create Test Image

```bash
cd test/luks-setup
./create-tkey-test-image.sh test.img 100M mypassword
```

Creates:

- 100MB LUKS2 encrypted image
- Ext4 filesystem inside
- Initialized with password
- Ready for TKey enrollment

#### Add TKey to Existing Image

```bash
cd test/luks-setup
./add-tkey-key.sh test.img mypassword
```

Process:

1. Derives USS from password
2. Loads TKey device app
3. Waits for touch
4. Derives LUKS key
5. Adds to keyslot

#### Test Unlock

```bash
cd test/luks-setup
./test-unlock.sh test.img mypassword
```

Tests unlocking with:

- TKey hardware
- USS derivation
- Physical touch
- Successful mount

### 4. Go Unit Tests

```bash
cd client
make test
```

Runs Go unit tests for:

- USS derivation functions
- System salt detection
- PBKDF2 parameters
- Command-line parsing
- Error handling

Note: Currently basic - most testing is integration-based due to hardware dependency.

## Test Scenarios

### Scenario 1: Basic USS Derivation

Goal: Verify USS derivation works correctly

```bash
cd test
./test-uss-derivation.sh
```

Validates:

- System salt detection
- PBKDF2 with 100k iterations
- Deterministic output
- 32-byte USS length
- Different passwords produce different USS

### Scenario 2: TKey Hardware Detection

Goal: Verify TKey is detected and accessible

```bash
# Manual check
ls -la /dev/ttyACM*
lsusb | grep Tillitis

# Automated test
cd test
./test-improved-uss.sh
```

Validates:

- USB device enumeration
- Serial port creation
- Device permissions
- Communication channel

### Scenario 3: Device App Loading

Goal: Verify device app loads with USS

```bash
cd test
./test-improved-uss.sh
```

Validates:

- USS derivation before loading
- Device app binary valid
- TKey accepts app
- CDI generation with USS
- App ready for signing

### Scenario 4: Physical Touch Requirement

Goal: Verify touch sensor works

```bash
cd test
./test-improved-uss.sh
# Press TKey button when prompted
```

Validates:

- Touch prompt displayed
- 30-second timeout
- Touch detection
- Signing proceeds after touch
- No signing without touch

### Scenario 5: Key Derivation

Goal: Verify full key derivation chain

```bash
cd test
./test-tkey-unlock.sh
```

Validates:

- USS = PBKDF2(password, machine-id, 100k)
- CDI = Hash(UDS xor App xor USS)
- secret_key = Ed25519_KeyDerive(CDI)
- LUKS_key = BLAKE2b(key=secret_key, data=password)
- 64-byte LUKS key output

### Scenario 6: LUKS Unlock

Goal: Verify LUKS unlock works end-to-end

```bash
cd test/luks-setup
./create-tkey-test-image.sh test.img 100M testpass
./test-unlock.sh test.img testpass
```

Validates:

- Image creation
- TKey enrollment
- Key derivation
- Keyslot unlock
- Filesystem mount
- Read/write access

### Scenario 7: Deterministic Keys

Goal: Verify same password produces the same key

```bash
cd test
./test-tkey-unlock.sh
```

Validates:

- Multiple derives produce same USS
- Same USS produces same CDI
- Same challenge produces same LUKS key
- Reproducible unlocks

### Scenario 8: Password Variation

Goal: Verify different passwords produce different keys

```bash
cd test
echo "password1" | ./tkey-luks-client --challenge-from-stdin --derive-uss --output key1.bin
echo "password2" | ./tkey-luks-client --challenge-from-stdin --derive-uss --output key2.bin
cmp key1.bin key2.bin && echo "FAIL: Keys match" || echo "PASS: Keys differ"
```

Validates:

- Different USS from different passwords
- Different LUKS keys
- No key collisions

## Manual Testing

### Test USS Derivation Manually

```bash
cd client

# Build
make

# Derive USS from password
echo "my-password" | ./tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --verbose \
  --output test-uss.bin

# Check output
hexdump -C test-uss.bin | head -3

# Verify deterministic
echo "my-password" | ./tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --output test-uss2.bin

cmp test-uss.bin test-uss2.bin && echo "Deterministic" || echo "Non-deterministic"

# Cleanup
rm test-uss*.bin
```

### Test Full Unlock Manually

```bash
# 1. Create test image
cd test/luks-setup
./create-tkey-test-image.sh /tmp/test.img 100M mypassword

# 2. Enroll TKey
echo "mypassword" | sudo ../../client/tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --output - | \
sudo cryptsetup luksAddKey /tmp/test.img -

# 3. Test unlock
echo "mypassword" | sudo ../../client/tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --output - | \
sudo cryptsetup luksOpen /tmp/test.img test-mapper --key-file=-

# 4. Verify
ls -la /dev/mapper/test-mapper
sudo mount /dev/mapper/test-mapper /mnt
ls -la /mnt

# 5. Cleanup
sudo umount /mnt
sudo cryptsetup luksClose test-mapper
rm /tmp/test.img
```

## Troubleshooting Tests

### TKey Not Detected

Problem: No /dev/ttyACM0 device

Solutions:

```bash
# Check USB
lsusb | grep Tillitis

# Check kernel messages
dmesg | grep -i tkey
dmesg | grep cdc_acm

# Check permissions
ls -la /dev/ttyACM*
sudo usermod -a -G dialout $USER
# Log out and back in
```

### Device App Load Fails

Problem: TKey rejects device app

Solutions:

```bash
# Rebuild device app
cd device-app
make clean && make

# Check binary size (must be < 100KB)
ls -lh tkey-luks-device.bin

# Verify hash
make verify
```

### USS Derivation Fails

Problem: No machine-id found

Solutions:

```bash
# Check machine-id exists
cat /etc/machine-id || cat /var/lib/dbus/machine-id

# Generate if missing (Ubuntu/Debian)
sudo systemd-machine-id-setup

# Or use custom salt
echo "mypass" | ./tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --salt "custom-salt-value" \
  --output test.bin
```

### Touch Timeout

Problem: Test fails waiting for touch

Solutions:

- Press button within 30 seconds
- Check TKey LED is flashing
- Try reconnecting TKey
- Check USB cable quality

### Tests Hang

Problem: Test script hangs indefinitely

Solutions:

```bash
# Kill stuck processes
pkill -f tkey-luks-client

# Power cycle TKey (unplug/replug)
# Note: TKey loads one app per power cycle

# Run with timeout
timeout 60 ./test-improved-uss.sh
```

## Continuous Integration

Current CI setup (GitHub Actions):

- Build verification
- Basic compilation tests
- Static analysis

Note: Hardware tests are not automated in CI due to hardware dependency.

## Adding New Tests

### Adding a Test Script

1. Create script in test/
2. Make executable: chmod +x test/test-new.sh
3. Follow existing script patterns
4. Document in this file

### Test Script Template

```bash
#!/bin/bash
# Test: Description of what this tests

set -e

echo "=== Test Name ==="
echo ""

# Check prerequisites
if [ ! -f "../client/tkey-luks-client" ]; then
    echo "Error: Client not built"
    exit 1
fi

# Run test
echo "Running test..."
+# ... test logic ...
+
+echo "Test passed"
+```
+
+## Test Coverage
+
+Current test coverage:
+- USS derivation (PBKDF2)
+- System salt detection
+- TKey communication
+- Device app loading
+- Touch requirement
+- Key derivation
+- LUKS unlock
+- Error scenarios (partial)
+- Edge cases (partial)
+- Unit tests (minimal)
+
+## See Also
+
+- [test/README.md](../test/README.md) - Test directory documentation
+- [test/luks-setup/README.md](../test/luks-setup/README.md) - LUKS test image setup
+- [SETUP.md](SETUP.md) - System setup and installation
+- [USS-DERIVATION.md](USS-DERIVATION.md) - USS security analysis
