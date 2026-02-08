# TKey-LUKS Client Application

The client application runs in initramfs during boot to unlock LUKS encrypted partitions using a TKey hardware device.

**Implementation:** Go (following Tillitis ecosystem standards)

## Architecture

```
┌─────────────────────────┐
│  tkey-luks-client       │
│  (Go Binary)            │
└────────┬────────────────┘
         │
         ├─→ 1. Detect TKey on USB
         ├─→ 2. Load device app to TKey
         ├─→ 3. Get public key (verify)
         ├─→ 4. Set challenge size
         ├─→ 5. Load challenge data
         ├─→ 6. Derive 64-byte key
         └─→ 7. Output key material

Integration:
  • Derived key → LUKS unlock
  • cryptsetup luksOpen --key-file=<(tkey-luks-client)
```

## Building

### Quick Build (Recommended)

```bash
# Use build script (downloads deps, builds, generates hash)
./build.sh
```

### Using Makefile

```bash
make              # Build binary and generate SHA-512 hash
make verify       # Verify binary integrity
make deps         # Download and verify Go dependencies
make clean        # Clean build artifacts
make test         # Run tests
make install      # Install to /usr/local/bin
make config       # Show build configuration
```

### Manual Build

```bash
# Download dependencies
go mod download
go mod verify

# Build (static linking, reduced size)
go build -ldflags="-s -w" -o tkey-luks-client

# Generate integrity hash
sha512sum tkey-luks-client > tkey-luks-client.sha512
```

### Requirements

- **Go 1.20+**
- **TKey device** (Tillitis MTA1-USB-V1)
- **tkey-devtools** (for tkey-runapp)

Install Go on Ubuntu/Debian:
```bash
sudo apt-get install golang
```

### Output

- `tkey-luks-client` - Static binary for TKey communication
- `tkey-luks-client.sha512` - SHA-512 hash for integrity verification

### Binary Integrity Verification

The build process generates a SHA-512 hash of the client binary for integrity verification:

```bash
# Verify binary integrity after building
make verify

# Or manually:
sha512sum -c tkey-luks-client.sha512
```

The hash file is automatically generated during build but is **not** committed to git - it's generated locally to verify your build matches expectations.

**Security Note:** Always verify the binary integrity before deployment, especially in initramfs environments. The hash ensures the binary hasn't been tampered with.

## Protocol

The client implements the TKey-LUKS protocol for key derivation:

| Command                 | Code   | Function                                  |
|-------------------------|--------|-------------------------------------------|
| `CMD_GET_NAMEVERSION`   | 0x09   | Get device app name and version           |
| `CMD_GET_PUBKEY`        | 0x01   | Get Ed25519 public key (for verification) |
| `CMD_SET_CHALLENGE`     | 0x03   | Set challenge size (32-bit LE)            |
| `CMD_LOAD_CHALLENGE`    | 0x05   | Load challenge data (up to 128 bytes)     |
| `CMD_DERIVE_KEY`        | 0x07   | Derive 64-byte key using Blake2b          |

**Protocol Flow:**
1. Connect to TKey device at /dev/ttyACM0 (62500 baud)
2. Load device app binary (or skip with `--skip-load-app`)
3. Get app name/version to verify correct app loaded
4. Get public key (derived from TKey CDI)
5. Set challenge size
6. Load challenge data in chunks
7. Request key derivation
8. Receive 64-byte derived key
9. Output to stdout or file

## Usage

### Basic Usage

```bash
# Derive key with default challenge
./tkey-luks-client

# Use custom challenge
./tkey-luks-client --challenge "my secret challenge"

# Specify device app binary
./tkey-luks-client --device-app ../device-app/tkey-luks-device.bin

# Output to file
./tkey-luks-client --output keyfile.bin

# Skip loading device app (already loaded)
./tkey-luks-client --skip-load-app
```

### LUKS Integration

```bash
# Add TKey-derived key to LUKS slot
cryptsetup luksAddKey /dev/sdX --key-file=<(./tkey-luks-client)

# Unlock LUKS volume with TKey
cryptsetup luksOpen /dev/sdX my_volume --key-file=<(./tkey-luks-client)

# In initramfs unlock script
/usr/local/bin/tkey-luks-client --skip-load-app | \
  cryptsetup luksOpen /dev/disk/by-uuid/XXX root_crypt
```

### Command-Line Flags

```
--device string         TKey device path (default "/dev/ttyACM0")
--device-app string     Device app binary path
--skip-load-app         Skip loading device app (use when already loaded)
--challenge string      Custom challenge string (default: hostname + UUID)
--output string         Output file (default: stdout)
--verbose               Enable verbose logging
```

## Dependencies

Go dependencies (managed via go.mod):
- **github.com/tillitis/tkeyclient** v1.1.0 - TKey communication library
- **github.com/google/uuid** - UUID generation
- **go.bug.st/serial** - Serial port communication

Runtime dependencies:
- TKey device (Tillitis MTA1-USB-V1)
- Device app binary loaded on TKey

## Testing

```bash
# Run Go tests
make test

# Test basic connectivity
./tkey-luks-client --verbose

# Test with hardware (requires TKey plugged in)
cd ../test
./luks-setup/test-hardware.sh

# Test protocol directly
python3 test-protocol.py
```

## Security Considerations

1. **Key Material Handling**
   - Keys are only held in memory briefly
   - Stdout/file output should be piped directly to cryptsetup
   - No logging of derived keys

2. **Touch Detection**
   - Device app requires physical touch to derive key
   - Prevents automated key extraction

3. **Challenge Entropy**
   - Default challenge includes hostname + UUID
   - Custom challenges are hashed for consistent length

4. **Binary Integrity**
   - SHA-512 verification ensures binary hasn't been tampered with
   - Always verify before deploying to production

## Troubleshooting

**TKey not found:**
```bash
# Check device exists
ls -l /dev/ttyACM*

# Check permissions
sudo usermod -a -G dialout $USER
# Log out and back in for group change to take effect
```

**Device app load fails:**
```bash
# Build device app first
cd ../device-app && ./build.sh

# Verify binary exists
ls -lh ../device-app/tkey-luks-device.bin

# Try with explicit path
./tkey-luks-client --device-app ../device-app/tkey-luks-device.bin
```

**Key derivation fails:**
```bash
# Enable verbose logging
./tkey-luks-client --verbose

# Test with protocol validation
cd ../test && python3 test-protocol.py
```

## Development

```bash
# Format code
go fmt

# Run linter
go vet

# Build with race detector
go build -race

# Generate dependency graph
go mod graph
```

## References

- **TKey Documentation:** https://dev.tillitis.se/
- **tkeyclient Library:** https://github.com/tillitis/tkeyclient
- **TKey Protocol:** https://dev.tillitis.se/protocol/
- **Device App:** [../device-app/README.md](../device-app/README.md)
