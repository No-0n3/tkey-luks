# Tillitis TKey Tools and Libraries Reference

This document provides information about the Tillitis TKey tools and libraries used in this project.

## Official Resources

- **TKey Developer Handbook**: https://dev.tillitis.se/
- **GitHub Organization**: https://github.com/tillitis
- **Projects List**: https://dev.tillitis.se/projects/

## Submodules in This Project

### 1. tkey-libs
**Repository**: https://github.com/tillitis/tkey-libs  
**Purpose**: Core libraries for TKey device app development  
**Language**: C (for RISC-V)

**Contents:**
- Application startup code
- Protocol definitions
- Cryptographic functions (Blake2s, Ed25519)
- Hardware abstraction layer

**Building:**
```bash
cd submodules/tkey-libs
make
# Or with container:
make podman
```

**Usage in Device Apps:**
```c
#include "tkey/app.h"
#include "tkey/blake2s.h"
```

**Pre-compiled Releases:**  
Available at: https://github.com/tillitis/tkey-libs/releases

### 2. tkey-device-signer
**Repository**: https://github.com/tillitis/tkey-device-signer  
**Purpose**: Ed25519 signing device app (reference implementation)  
**Language**: C (runs on TKey)

**What it does:**
- Signs data using TKey's Unique Device Secret (USS)
- Ed25519 cryptographic signing
- Reference implementation for device apps

**Adapting for LUKS:**
We can adapt this signer to:
1. Receive challenge from client
2. Sign challenge with USS
3. Return signature for LUKS key derivation

**Protocol:**
- `CMD_GET_PUBKEY` - Get device public key
- `CMD_SET_SIZE` - Set data size
- `CMD_LOAD_DATA` - Load data to sign
- `CMD_GET_SIG` - Get signature

### 3. tkey-devtools
**Repository**: https://github.com/tillitis/tkey-devtools  
**Purpose**: Development tools for TKey  
**Language**: Go

**Tools included:**
- `tkey-runapp` - Load and start device apps on TKey
- `run-tkey-qemu` - Script for TKey emulator
- `hidread` - Read debug output from TKey
- `lshid` - List HID devices

**Building:**
```bash
cd submodules/tkey-devtools
make
# Or:
go build ./cmd/tkey-runapp
```

**Using tkey-runapp:**
```bash
# Load and run a device app
./tkey-runapp /path/to/device-app.bin

# With specific port
./tkey-runapp --port /dev/ttyACM0 device-app.bin

# With QEMU emulator
./tkey-runapp --port ./tkey-qemu-pty device-app.bin
```

## Go Client Libraries

### tkeyclient
**Repository**: https://github.com/tillitis/tkeyclient  
**Go Package**: `github.com/tillitis/tkeyclient`  
**Documentation**: https://pkg.go.dev/github.com/tillitis/tkeyclient

**Purpose**: Core Go library for communicating with TKey

**Usage:**
```go
import "github.com/tillitis/tkeyclient"

// Connect to TKey
tk := tkeyclient.New()
err := tk.Connect(port)

// Load device app
appBinary, _ := os.ReadFile("device-app.bin")
err = tk.LoadApp(appBinary, []byte("user-secret"))

// Communication functions
tk.Write(data)
response, _ := tk.Read()
```

### tkeyutil
**Repository**: https://github.com/tillitis/tkeyutil  
**Go Package**: `github.com/tillitis/tkeyutil`  
**Documentation**: https://pkg.go.dev/github.com/tillitis/tkeyutil

**Purpose**: Utility functions for input and notifications

### tkeysign
**Repository**: https://github.com/tillitis/tkeysign  
**Go Package**: `github.com/tillitis/tkeysign`  
**Documentation**: https://pkg.go.dev/github.com/tillitis/tkeysign

**Purpose**: Functions to communicate with the signer device app

**Example Usage:**
```go
import "github.com/tillitis/tkeysign"

signer := tkeysign.New(tk)
signature, err := signer.Sign(message)
pubkey, err := signer.GetPublicKey()
```

## Required Build Tools

### For Client Development (Go)
- **Go**: Version 1.20 or later
- **libusb**: libusb-1.0-0-dev
- **pkg-config**: For finding libraries

**Installation (Ubuntu/Debian):**
```bash
sudo apt install golang libusb-1.0-0-dev pkg-config
```

### For Device App Development (C/RISC-V)
- **LLVM/Clang**: Version 15+ with riscv32 support
- **LLD**: LLVM linker
- **Make**: Build automation

**Required LLVM features:**
- Target: `riscv32-unknown-none-elf`
- Extensions: `-march=rv32iczmmul`

**Installation (Ubuntu/Debian):**
```bash
sudo apt install clang lld llvm
```

**Verify:**
```bash
clang --version  # Should be 15+
llc --version | grep riscv32  # Should show riscv32 support
```

### Container Alternative
Instead of installing tools natively, use the `tkey-builder` container:

```bash
# Pull container
podman pull ghcr.io/tillitis/tkey-builder

# Build with container
podman run --rm \
  --mount type=bind,source=.,target=/src \
  --mount type=bind,source=../tkey-libs,target=/tkey-libs \
  -w /src -it ghcr.io/tillitis/tkey-builder make -j
```

## TKey Emulator (QEMU)

### Using Pre-built Container
```bash
# Use run-tkey-qemu script (from tkey-devtools)
./submodules/tkey-devtools/run-tkey-qemu

# Creates: tkey-qemu-pty (for client apps to connect to)
```

### Building QEMU from Source
```bash
# Clone TKey's QEMU fork
git clone -b tk1 https://github.com/tillitis/qemu
cd qemu
mkdir build && cd build

# Configure
../configure --target-list=riscv32-softmmu --disable-werror

# Build
make -j $(nproc) qemu-system-riscv32

# Get firmware
git clone https://github.com/tillitis/tillitis-key1
cd tillitis-key1/hw/application_fpga
make firmware.elf

# Run
/path/to/qemu/build/qemu-system-riscv32 -nographic -M tk1,fifo=chrid \
  -bios firmware.elf -chardev pty,id=chrid
```

## USB Device Detection

### Finding TKey Device
```bash
# List USB devices
lsusb | grep Tillitis

# Expected output:
# Bus 001 Device 005: ID 1209:8885 Tillitis TKey

# Find serial port
ls -la /dev/ttyACM*

# Device nodes created:
# /dev/ttyACM0 - Main communication
# /dev/ttyACM1 - Debug output (optional)
```

### Using lshid (from tkey-devtools)
```bash
cd submodules/tkey-devtools
go build ./cmd/lshid
./lshid

# Look for: ID 1209:8885 Tillitis
```

## Integration in This Project

### Device App Structure
```
device-app/
├── Makefile           # Use tkey-libs for compilation
├── src/
│   └── main.c        # Adapt tkey-device-signer protocol
└── app.bin           # Output binary for TKey
```

**Build with tkey-libs:**
```bash
cd device-app
make LIBDIR=../submodules/tkey-libs
```

### Client App Structure
```
client/
├── go.mod            # Go module
├── main.go           # Use tkeyclient library
└── tkey-luks-unlock  # Output binary
```

**With tkeyclient:**
```go
import (
    "github.com/tillitis/tkeyclient"
)

func main() {
    tk := tkeyclient.New()
    tk.Connect("/dev/ttyACM0")
    // Load device app and communicate
}
```

## Testing Without Hardware

### Option 1: QEMU Emulator
```bash
# Start emulator
./submodules/tkey-devtools/run-tkey-qemu

# Use with client
./tkey-luks-unlock --port ./tkey-qemu-pty /dev/loop0
```

### Option 2: Mock Implementation
Create a mock TKey interface for testing:
```go
type MockTKey struct {
    // Simulated USS
    uss [32]byte
}

func (m *MockTKey) Sign(challenge []byte) []byte {
    // Simulate signing
    return signature
}
```

## Common Issues and Solutions

### "TKey not detected"
- Check USB connection: `lsusb | grep Tillitis`
- Check permissions: `ls -la /dev/ttyACM*`
- Add udev rules (see tkey-devtools/system/)

### "clang: error: unsupported target"
- Ensure LLVM 15+ installed
- Verify riscv32 support: `llc --version | grep riscv32`

### "Cannot find tkey-libs"
- Build submodule: `cd submodules/tkey-libs && make`
- Specify path: `make LIBDIR=../submodules/tkey-libs`

## Additional Reading

- **TKey Protocol**: https://dev.tillitis.se/protocol/
- **Building Apps**: https://dev.tillitis.se/tools/
- **Security Design**: https://dev.tillitis.se/intro/
- **App Examples**: Various examples in https://dev.tillitis.se/projects/

## License Information

All Tillitis projects are open source:
- Most use BSD-2-Clause license
- Some older projects may use GPL-2.0
- Check each repository's LICENSE file

## Support

- GitHub Issues: On respective repositories
- Community: https://tillitis.se/
- Documentation: https://dev.tillitis.se/
