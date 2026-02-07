# TKey-LUKS Client Application

The client application runs in initramfs during boot to unlock LUKS encrypted partitions using a TKey hardware device.

## Implementation Options

### Go Implementation (Recommended)

Go is the standard language for TKey client applications in the Tillitis ecosystem.

**Advantages:**
- Better TKey library support
- Easier static compilation
- Standard practice in Tillitis projects
- Good performance
- Memory safe

**To implement in Go:**
```bash
# Create Go module
go mod init github.com/yourusername/tkey-luks

# Add TKey dependencies (example)
go get github.com/tillitis/tkeyclient

# Build statically
go build -ldflags="-s -w" -o tkey-luks-unlock
```

### C Implementation (Current)

C implementation is provided as an alternative.

**Advantages:**
- Direct control over binary size
- Minimal dependencies
- Traditional approach

**Disadvantages:**
- Manual memory management
- More complex TKey integration
- Less library support

**To build:**
```bash
make
```

## Architecture

```
┌─────────────────────────┐
│   tkey-luks-unlock      │
│   (Client Binary)       │
└────────┬────────────────┘
         │
         ├─→ 1. Detect TKey on USB
         ├─→ 2. Load device app to TKey
         ├─→ 3. Send challenge
         ├─→ 4. Receive signature
         ├─→ 5. Derive LUKS key
         └─→ 6. Unlock with cryptsetup
```

## Protocol

1. **USB Detection**
   - Scan for TKey device (Tillitis vendor ID)
   - Establish communication channel

2. **Device App Loading**
   - Load device app binary to TKey
   - Verify app loaded successfully

3. **Challenge-Response**
   - Send 32-byte challenge
   - Receive 64-byte signature (signed with USS)

4. **Key Derivation**
   - Apply KDF (PBKDF2/HKDF) to signature
   - Generate LUKS key material

5. **LUKS Unlock**
   - Pass key to cryptsetup
   - Unlock LUKS device

## Current Status

- [x] C skeleton with function prototypes
- [ ] TKey USB detection
- [ ] Device app loading
- [ ] Challenge-response protocol
- [ ] Key derivation
- [ ] cryptsetup integration
- [ ] Static compilation
- [ ] Error handling
- [ ] Go implementation

## Building

### C Version

```bash
# Standard build
make

# Static build
make STATIC=-static

# Debug build
make debug

# Install
sudo make install
```

### Go Version (TODO)

```bash
# Build
go build -o tkey-luks-unlock

# Static build
CGO_ENABLED=0 go build -ldflags="-s -w" -o tkey-luks-unlock

# Install
sudo install -m 755 tkey-luks-unlock /usr/lib/tkey-luks/
```

## Dependencies

### C Version
- libusb-1.0
- TKey libraries (from submodules)
- cryptsetup (runtime)

### Go Version
- github.com/tillitis/tkeyclient
- Go 1.20+

## Testing

```bash
# Test binary
./tkey-luks-unlock --help

# Test with mock device
TKEY_MOCK=1 ./tkey-luks-unlock /dev/loop0

# Test in initramfs (via QEMU)
cd ../test/qemu
./run-vm.sh
```

## Next Steps

1. **Decide on implementation language**
   - Evaluate Go vs C trade-offs
   - Consider Go for better TKey ecosystem integration

2. **Implement TKey communication**
   - USB detection
   - Device app loading
   - Protocol implementation

3. **Implement key derivation**
   - Choose KDF (PBKDF2 recommended)
   - Implement derivation logic
   - Handle key material securely

4. **Integrate with cryptsetup**
   - Library integration or command spawning
   - Secure key passing
   - Error handling

5. **Static compilation**
   - Ensure no dynamic dependencies
   - Optimize binary size
   - Test in initramfs

## References

- TKey Client Libraries: https://github.com/tillitis (Go packages)
- TKey Protocol: https://dev.tillitis.se/protocol/
- cryptsetup: https://gitlab.com/cryptsetup/cryptsetup
