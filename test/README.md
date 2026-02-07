# Test Directory

This directory contains all testing infrastructure for TKey-LUKS.

## Structure

```
test/
├── qemu/               # QEMU VM testing
│   ├── create-vm.sh    # Create test VM with LUKS
│   ├── run-vm.sh       # Run test VM
│   └── vm/             # VM files (created)
├── luks-setup/         # LUKS test image creation
│   ├── create-test-image.sh  # Create LUKS test image
│   └── test-unlock.sh        # Test unlock mechanisms
└── integration/        # Integration tests (TODO)
    └── test-boot.sh    # Full boot test
```

## Quick Start

### Create Test Environment

```bash
# Create QEMU VM (recommended for full testing)
cd qemu
./create-vm.sh

# Or create simple test image
cd luks-setup
./create-test-image.sh my-test.img 100M mypassword
```

### Run Tests

```bash
# Run VM test
cd qemu
./run-vm.sh

# Test LUKS unlock
cd luks-setup
./test-unlock.sh my-test.img no   # Password mode
./test-unlock.sh my-test.img yes  # TKey mode (after building)
```

## Test Components

### QEMU VM Testing

The QEMU VM provides a complete test environment:
- Full boot sequence
- Real initramfs
- Actual LUKS encryption
- USB device passthrough (for TKey)

**Create VM:**
```bash
cd qemu
./create-vm.sh
```

**Run VM:**
```bash
./run-vm.sh                    # Standard run
./run-vm.sh --console          # Console output
./run-vm.sh --debug            # Debug mode
./run-vm.sh --tkey-device DEV  # Specific TKey
```

### LUKS Test Images

Small LUKS encrypted images for quick testing.

**Create:**
```bash
cd luks-setup
./create-test-image.sh <file> <size> <password>
```

**Test:**
```bash
./test-unlock.sh <file> [yes|no]
```

## Requirements

### For QEMU Testing
- qemu-system-x86_64
- qemu-utils
- debootstrap (for VM creation)
- cryptsetup
- 10GB+ free disk space

### For LUKS Testing
- cryptsetup
- loop device support
- root/sudo access

## Writing Tests

See [../docs/TESTING.md](../docs/TESTING.md) for:
- Test template
- Testing best practices
- CI integration
- Debugging techniques

## Common Issues

### "Loop device not available"
```bash
# Load loop module
sudo modprobe loop

# Check available loop devices
ls /dev/loop*
```

### "Permission denied"
Most test scripts require root for:
- Loop device operations
- LUKS operations
- QEMU with USB passthrough

Run with sudo:
```bash
sudo ./create-test-image.sh
```

### "QEMU not found"
Install QEMU:
```bash
# Debian/Ubuntu
sudo apt-get install qemu-system-x86 qemu-utils

# Fedora
sudo dnf install qemu-system-x86 qemu-img
```

## See Also

- [../docs/TESTING.md](../docs/TESTING.md) - Full testing guide
- [../PLAN.md](../PLAN.md) - Project plan
