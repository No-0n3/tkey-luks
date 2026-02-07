# TKey-LUKS: Hardware-Based LUKS Unlock with Tillitis TKey

Unlock LUKS encrypted root partitions at boot using Tillitis TKey hardware security key.

## Overview

This project provides a secure mechanism to unlock LUKS encrypted root partitions during boot using a Tillitis TKey hardware security device. The TKey must be physically present in the computer during boot, and the LUKS encryption key is derived from cryptographic operations performed by the TKey.

## Features

- 🔐 **Hardware-Based Security**: LUKS key derived from TKey device secrets
- 🚀 **Boot Integration**: Seamless integration with initramfs
- 🔧 **Static Binary**: No dependencies in initramfs environment
- 🧪 **Test Environment**: QEMU-based testing infrastructure
- 📦 **Easy Installation**: Automated installation scripts
- 🔄 **Fallback Support**: Optional password fallback

## Project Status

⚠️ **In Development** - This project is in initial development phase.

See [PLAN.md](PLAN.md) for detailed implementation plan.

## Quick Start

### Prerequisites

- Tillitis TKey hardware device
- Linux system (Debian/Ubuntu recommended)
- initramfs-tools or dracut
- cryptsetup
- Build tools (gcc, make, or go)

### Installation

```bash
# Clone repository with submodules
git clone --recursive https://github.com/yourusername/tkey-luks.git
cd tkey-luks

# Build all components
./scripts/build-all.sh

# Install system-wide
sudo ./scripts/install.sh

# Enroll TKey with LUKS partition
sudo tkey-luks-enroll /dev/sdaX
```

### Testing

```bash
# Set up test environment
./test/qemu/create-vm.sh

# Run test
./test/qemu/run-vm.sh
```

## Architecture

The system consists of three main components:

1. **Device Application**: Runs on TKey, performs cryptographic operations
2. **Client Application**: Runs in initramfs, communicates with TKey
3. **initramfs Hooks**: Integration with boot process

```
[initramfs] → [Client Binary] → [USB] → [TKey Device App]
     ↓              ↓                         ↓
[Derived Key] → [cryptsetup] → [Unlock LUKS]
```

## Documentation

- [PLAN.md](PLAN.md) - Detailed implementation plan
- [docs/SETUP.md](docs/SETUP.md) - Setup and installation guide
- [docs/TESTING.md](docs/TESTING.md) - Testing procedures
- [docs/SECURITY.md](docs/SECURITY.md) - Security considerations

## Security

This system provides security against:
- Unauthorized boot of stolen devices
- Cold boot attacks (limited)
- Software-only attacks on LUKS keys

See [docs/SECURITY.md](docs/SECURITY.md) for full threat model and considerations.

## License

[To be determined]

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Acknowledgments

- Tillitis for the TKey hardware and SDK
- cryptsetup project
- Linux kernel initramfs framework
