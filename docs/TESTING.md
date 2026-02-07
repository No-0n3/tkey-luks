# Testing Guide

## Overview

This guide covers testing procedures for the TKey-LUKS system, from unit tests to full integration testing with QEMU.

## Test Environment Setup

### Quick Start

```bash
# Set up complete test environment
cd test/qemu
./create-vm.sh

# Run basic test
./run-vm.sh
```

### Manual Setup

#### 1. Install Test Dependencies

```bash
# Debian/Ubuntu
sudo apt-get install qemu-system-x86 qemu-utils \
    debootstrap cryptsetup e2fsprogs \
    ovmf # for UEFI testing

# Fedora/RHEL
sudo dnf install qemu-system-x86 qemu-img \
    cryptsetup e2fsprogs edk2-ovmf
```

#### 2. Create Test Image

```bash
cd test/luks-setup
./create-test-image.sh
```

This creates:
- LUKS encrypted disk image
- Minimal bootable root filesystem
- Test GRUB configuration
- Enrolled test TKey

## Test Categories

### 1. Unit Tests

#### Device Application Tests

```bash
cd device-app
make test

# Test key derivation
./test/test-key-derivation

# Test TKey communication
./test/test-tkey-comm
```

#### Client Application Tests

```bash
cd client
make test

# Test USB communication
./test/test-usb

# Test key derivation
./test/test-kdf

# Test cryptsetup integration
./test/test-cryptsetup
```

### 2. Integration Tests

#### Full Boot Test

```bash
cd test/integration
./test-boot.sh

# What it tests:
# - TKey detection in initramfs
# - Client-device communication
# - Key derivation
# - LUKS unlock
# - Successful boot
```

#### Error Scenario Tests

```bash
# Test missing TKey
./test-boot.sh --no-tkey

# Test wrong TKey
./test-boot.sh --wrong-tkey

# Test USB errors
./test-boot.sh --usb-error

# Test timeout scenarios
./test-boot.sh --timeout
```

### 3. QEMU VM Testing

#### Basic Boot Test

```bash
cd test/qemu
./run-vm.sh

# Expected output:
# - GRUB menu appears
# - Kernel boots
# - initramfs starts
# - TKey detected
# - LUKS unlocked
# - System boots to login
```

#### Advanced QEMU Options

```bash
# Boot with console output
./run-vm.sh --console

# Boot with debugging
./run-vm.sh --debug

# Boot with specific TKey device
./run-vm.sh --tkey-device /dev/ttyACM0

# UEFI boot (Secure Boot testing)
./run-vm.sh --uefi

# Snapshot and restore testing
./run-vm.sh --snapshot test1
./run-vm.sh --restore test1
```

### 4. Performance Tests

```bash
cd test/integration
./test-performance.sh

# Metrics tested:
# - Boot time impact
# - TKey communication latency
# - Key derivation time
# - Total unlock time
```

### 5. Security Tests

```bash
cd test/integration
./test-security.sh

# Tests:
# - Rate limiting
# - Failed attempt handling
# - Key material not leaked
# - Secure memory handling
```

## Test Scenarios

### Scenario 1: Happy Path

**Setup:**
- Valid TKey enrolled
- TKey connected via USB
- Normal boot

**Expected Result:**
- System boots automatically
- No user interaction required
- Boot time < 30 seconds

**Test:**
```bash
./test/integration/test-scenario-1-happy-path.sh
```

### Scenario 2: Missing TKey

**Setup:**
- TKey not connected
- Fallback enabled

**Expected Result:**
- System detects missing TKey
- Falls back to password prompt
- User can enter password

**Test:**
```bash
./test/integration/test-scenario-2-missing-tkey.sh
```

### Scenario 3: Wrong TKey

**Setup:**
- Different TKey connected
- Not enrolled with this system

**Expected Result:**
- Unlock fails
- Error message displayed
- Fallback to password (if enabled)
- Or retry prompt

**Test:**
```bash
./test/integration/test-scenario-3-wrong-tkey.sh
```

### Scenario 4: USB Communication Error

**Setup:**
- TKey connected but communication fails
- Simulated USB error

**Expected Result:**
- Timeout after configured period
- Error message
- Retry or fallback

**Test:**
```bash
./test/integration/test-scenario-4-usb-error.sh
```

### Scenario 5: Multiple TKeys

**Setup:**
- Two TKeys enrolled
- Test with each TKey

**Expected Result:**
- Either TKey successfully unlocks
- No preference needed

**Test:**
```bash
./test/integration/test-scenario-5-multiple-tkeys.sh
```

### Scenario 6: Rate Limiting

**Setup:**
- Make multiple failed unlock attempts

**Expected Result:**
- After N attempts, lockout imposed
- Exponential backoff
- Eventually allows retry

**Test:**
```bash
./test/integration/test-scenario-6-rate-limiting.sh
```

## QEMU VM Details

### VM Configuration

**Specifications:**
- RAM: 2GB
- CPUs: 2
- Disk: 10GB (LUKS encrypted)
- Network: User-mode NAT
- USB: QEMU USB controller with TKey passthrough

**Files:**
- `vm-disk.qcow2` - Main disk image
- `vm-config.xml` - VM configuration
- `grub.cfg` - GRUB configuration
- `initramfs.img` - Custom initramfs with tkey-luks

### Creating Test VM from Scratch

```bash
cd test/qemu

# Step 1: Create disk image
qemu-img create -f qcow2 vm-disk.qcow2 10G

# Step 2: Set up LUKS encryption
./setup-luks.sh vm-disk.qcow2

# Step 3: Install minimal system
./install-system.sh vm-disk.qcow2

# Step 4: Install tkey-luks
./install-tkey-luks.sh vm-disk.qcow2

# Step 5: Enroll TKey
./enroll-tkey.sh vm-disk.qcow2

# Or use the all-in-one script:
./create-vm.sh
```

### Debugging VM Boot

```bash
# Boot with serial console
./run-vm.sh --serial

# Boot with VNC display
./run-vm.sh --vnc :1

# Boot with GDB debugging
./run-vm.sh --gdb 1234

# Boot with detailed logging
./run-vm.sh --debug --log vm-boot.log
```

### Accessing VM Console

```bash
# Via QEMU monitor
# Press Ctrl+Alt+2 to access monitor
# Type 'info usb' to see USB devices

# Via serial console
screen /dev/pts/X 115200

# Via SSH (if network configured)
ssh -p 2222 root@localhost
```

## Test Data and Fixtures

### Test TKey Configuration

```bash
# Test challenge stored in header
test/fixtures/test-challenge.bin

# Test device application
test/fixtures/test-device-app.bin

# Expected signature output
test/fixtures/test-signature.bin
```

### Mock TKey Device

For testing without hardware:

```bash
# Build mock TKey device
cd test/mock-tkey
make

# Run tests with mock device
export TKEY_MOCK=1
./test/integration/test-boot.sh
```

## Continuous Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          submodules: recursive
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential \
            qemu-system-x86 cryptsetup
      
      - name: Build
        run: ./scripts/build-all.sh
      
      - name: Unit tests
        run: make test
      
      - name: Integration tests
        run: ./test/integration/test-all.sh
```

## Test Checklist

Before release:

- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] QEMU boot test succeeds
- [ ] All error scenarios handled
- [ ] Performance metrics acceptable
- [ ] Security tests pass
- [ ] Documentation updated
- [ ] Test coverage > 80%

## Troubleshooting Tests

### TKey Not Detected in VM

**Symptom:** TKey device not visible in QEMU VM

**Solutions:**
```bash
# Check USB passthrough
lsusb | grep Tillitis

# Verify QEMU USB configuration
./run-vm.sh --show-usb

# Try different USB controller
./run-vm.sh --usb-controller ehci

# Check permissions
ls -la /dev/ttyACM*
```

### Boot Hangs at initramfs

**Symptom:** VM hangs at "Waiting for TKey..."

**Solutions:**
```bash
# Boot with debug output
./run-vm.sh --debug

# Check initramfs logs
./run-vm.sh --shell  # Drop to initramfs shell
cat /run/initramfs/tkey-luks.log

# Verify TKey enrollment
cryptsetup luksDump /dev/vda1
```

### Tests Fail Intermittently

**Symptom:** Tests pass sometimes, fail others

**Likely Causes:**
- Race conditions in boot process
- USB timing issues
- Insufficient VM resources

**Solutions:**
```bash
# Increase timeouts
export TKEY_TIMEOUT=60

# Allocate more VM RAM
./run-vm.sh --memory 4G

# Run with fixed random seed
export RANDOM_SEED=12345
```

## Writing New Tests

### Unit Test Template

```c
// test/test-template.c
#include "unity.h"
#include "../src/tkey-luks.h"

void setUp(void) {
    // Run before each test
}

void tearDown(void) {
    // Run after each test
}

void test_feature_works(void) {
    // Arrange
    int result;
    
    // Act
    result = my_function();
    
    // Assert
    TEST_ASSERT_EQUAL(EXPECTED_VALUE, result);
}

int main(void) {
    UNITY_BEGIN();
    RUN_TEST(test_feature_works);
    return UNITY_END();
}
```

### Integration Test Template

```bash
#!/bin/bash
# test/integration/test-template.sh

set -e

# Setup
TEST_NAME="Feature Test"
echo "Running $TEST_NAME..."

# Create test environment
./setup-test-env.sh

# Run test
./run-vm.sh --test-mode &
VM_PID=$!

# Wait for result
sleep 30

# Check result
if check_vm_booted; then
    echo "$TEST_NAME: PASS"
    exit 0
else
    echo "$TEST_NAME: FAIL"
    exit 1
fi
```

## Test Reports

Generate test reports:

```bash
# HTML report
./test/generate-report.sh --format html

# JUnit XML (for CI)
./test/generate-report.sh --format junit

# Coverage report
./test/generate-coverage.sh
```

## References

- QEMU Documentation: https://www.qemu.org/docs/master/
- cryptsetup Testing: https://gitlab.com/cryptsetup/cryptsetup/-/wikis/testing
- initramfs Debugging: https://wiki.debian.org/InitramfsDebug
