# Test Directory

This directory contains all testing infrastructure for TKey-LUKS with improved USS derivation (v1.1.0+).

## Structure

```text
test/
├── test-improved-uss.sh        # Hardware USS derivation test (requires TKey)
├── test-uss-derivation.sh      # USS derivation unit tests (no TKey needed)
├── test-tkey-unlock.sh         # Boot unlock testing with TKey
├── test-build-and-install.sh   # Full build and installation test (Docker or local)
├── test-debian-package.sh      # Test .deb installation in Docker container
├── test-with-act.sh            # Test GitHub Actions workflow locally
└── luks-setup/                 # LUKS test image utilities
    ├── create-tkey-test-image.sh   # Create 100MB LUKS2 test image
    ├── add-tkey-key.sh             # Enroll TKey with USS derivation
    ├── test-unlock.sh              # Test unlock with TKey or password
    └── README.md                   # Detailed luks-setup documentation
```

## Quick Start

### Package Installation Tests (CI/CD Simulation)

```bash
# Test full build and Debian package installation (recommended)
./test-build-and-install.sh

# Test with GitHub Actions locally (requires 'act' tool)
./test-with-act.sh

# Quick package test only (requires pre-built .deb)
./test-debian-package.sh
```

Simulates the GitHub Actions release workflow locally using Docker.

### USS Derivation Tests (No Hardware Required)

```bash
# Run USS derivation unit tests
./test-uss-derivation.sh
```

Tests PBKDF2 derivation, salt detection, and parameter validation without requiring physical TKey.

### Hardware Tests (Requires TKey)

```bash
# Comprehensive USS derivation test with real TKey
./test-improved-uss.sh
```

Tests all USS derivation scenarios with hardware device at `/dev/ttyACM0`.

### LUKS Image Testing

```bash
# Create test image
cd luks-setup
./create-tkey-test-image.sh

# Enroll TKey with improved USS derivation
./add-tkey-key.sh test-luks-100mb.img test123

# Test unlock
./test-unlock.sh test-luks-100mb.img yes test123
```

## Test Scripts

### 1. test-uss-derivation.sh

**Purpose:** Unit tests for USS derivation (no hardware required)

**Tests:**

- PBKDF2 key derivation
- System salt detection (machine-id, dbus, DMI, hostname)
- Custom salt parameter
- Custom iteration count
- Error handling

**Usage:**

```bash
./test-uss-derivation.sh
```

**Requirements:** tkey-luks-client in PATH or built in `../client/`

### 2. test-improved-uss.sh

**Purpose:** Comprehensive hardware testing with real TKey device

**Tests:**

- Basic USS derivation with default parameters
- Custom USS password
- Custom salt values
- Custom PBKDF2 iterations
- Deterministic key generation
- Key size validation (64 bytes)

**Usage:**

```bash
./test-improved-uss.sh
```

**Requirements:**

- TKey device at `/dev/ttyACM0`
- tkey-luks-client built
- Device app binary at `../device-app/tkey-luks-device.bin`

### 3. test-build-and-install.sh

**Purpose:** Full build and installation test (simulates GitHub Actions)

**Tests:**

- Complete build process (client + device app)
- Debian package creation
- Package installation in Docker container
- File installation verification
- Binary functionality
- Initramfs integration

**Usage:**

```bash
# Full test with Docker (safest, most accurate)
./test-build-and-install.sh

# Skip build step (test existing binaries)
./test-build-and-install.sh --skip-build

# Test on local system (requires root, modifies system)
sudo ./test-build-and-install.sh --method local

# Keep package after test
./test-build-and-install.sh --keep-package
```

**Requirements:**

- Docker (for default method)
- debhelper, devscripts, build-essential (for package build)
- Root access (for local installation method only)

**Test Methods:**

- `docker` (default): Test in Ubuntu 24.04 container (safest)
- `local`: Install on local system (requires root)
- `mock`: Just verify package structure

### 4. test-debian-package.sh

**Purpose:** Quick Debian package installation test in Docker

**Tests:**

- Package installation with dpkg
- File presence verification
- Executable permissions
- Documentation installation
- Initramfs script validation

**Usage:**

```bash
# Build package first
cd /home/isaac/Development/tkey-luks
dpkg-buildpackage -b -uc -us

# Test the package
./test/test-debian-package.sh
```

**Requirements:**

- Docker
- Pre-built .deb package in parent directory

### 5. test-with-act.sh

**Purpose:** Test GitHub Actions workflow locally using 'act'

**Tests:**

- Complete GitHub Actions workflow simulation
- Build and package job
- Installation test job
- Artifact handling

**Usage:**

```bash
# Install act first
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Test the workflow
./test-with-act.sh

# Test specific job
./test-with-act.sh --job build-and-package

# List available jobs
./test-with-act.sh --list
```

**Requirements:**

- act (GitHub Actions local runner)
- Docker
- ~10GB disk space for runner images

### 6. test-tkey-unlock.sh

**Purpose:** Boot-time unlock testing

**Usage:**

```bash
./test-tkey-unlock.sh [options]
```

**Requirements:** TKey device, LUKS partition configured

### 7. luks-setup/ Scripts

See [luks-setup/README.md](luks-setup/README.md) for detailed documentation on:

- Creating test LUKS images
- Enrolling TKey keys with improved USS derivation
- Testing unlock mechanisms

## Requirements

### For USS Derivation Tests

- tkey-luks-client (built from `../client/`)
- No TKey hardware needed for unit tests
- TKey device required for hardware tests

### For LUKS Testing

- cryptsetup (>= 2:2.0.0)
- loop device support (`modprobe loop`)
- root/sudo access for LUKS operations
- TKey device at `/dev/ttyACM0` for TKey unlock tests

## Test Results

All tests should pass on a correctly configured system:

```bash
# Example output from test-uss-derivation.sh
✓ Test 1: Basic USS derivation
✓ Test 2: USS with custom salt
✓ Test 3: USS with custom iterations
✓ Test 4: System salt detection
All USS derivation tests passed!

# Example output from test-improved-uss.sh
✓ Test 1: Basic improved USS
✓ Test 2: Custom USS password
✓ Test 3: Custom salt
✓ Test 4: Custom iterations
✓ Test 5: Deterministic derivation
All improved USS tests passed!
```

## Common Issues

### "TKey not found at /dev/ttyACM0"

```bash
# Check if TKey is connected
ls -la /dev/ttyACM*

# Check USB devices
lsusb | grep Tillitis

# Check dmesg
dmesg | grep -i tty
```

### "tkey-luks-client not found"

```bash
# Build the client first
cd ../client
make clean && make

# Or add to PATH
export PATH="$PATH:$(pwd)/../client"
```

### "Loop device not available"

```bash
# Load loop module
sudo modprobe loop

# Check available loop devices
ls /dev/loop*
```

### "Permission denied" on LUKS operations

Most LUKS test scripts require root access:

```bash
sudo ./test-unlock.sh
```

## Writing Tests

See [../docs/TESTING.md](../docs/TESTING.md) for:

- Test templates and best practices
- CI/CD integration guidelines
- Debugging techniques
- Security testing considerations

## See Also

- [../docs/TESTING.md](../docs/TESTING.md) - Comprehensive testing guide
- [../docs/USS-DERIVATION.md](../docs/USS-DERIVATION.md) - USS derivation technical details
- [../docs/SECURITY.md](../docs/SECURITY.md) - Security model and threat analysis
- [luks-setup/README.md](luks-setup/README.md) - LUKS test utilities documentation
