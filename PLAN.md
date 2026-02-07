# TKey-LUKS: Tillitis TKey LUKS Unlock System

## Project Overview
Create a mechanism to unlock LUKS encrypted root partitions at boot using Tillitis TKey hardware security key. The TKey must be physically present during boot, and the LUKS key will be derived from a TKey cryptographic operation.

## Architecture

```
┌─────────────────────────────────────┐
│         Boot Process                 │
│  ┌──────────────────────────────┐   │
│  │      initramfs               │   │
│  │  ┌────────────────────────┐  │   │
│  │  │  tkey-luks-unlock      │  │   │
│  │  │  (client binary)        │  │   │
│  │  └───────────┬─────────────┘  │   │
│  │              │ USB             │   │
│  │              ▼                 │   │
│  │      ┌──────────────┐          │   │
│  │      │ Tillitis TKey│          │   │
│  │      │  (device app) │          │   │
│  │      └──────────────┘          │   │
│  │              │                 │   │
│  │              ▼                 │   │
│  │   Derived LUKS Key             │   │
│  │              │                 │   │
│  │              ▼                 │   │
│  │    cryptsetup luksOpen         │   │
│  └──────────────────────────────┘   │
│              │                       │
│              ▼                       │
│      Root Filesystem Mounted         │
└─────────────────────────────────────┘
```

## Components

### 1. Device Application (TKey Firmware)
**Options:**
- **Option A: Use tkey-sign** - Leverage existing signing functionality to derive keys
- **Option B: Custom tkey-luks-device** - Purpose-built app for key derivation
- **Option C: Modified tkey-sign** - Fork and adapt for LUKS use case

**Recommendation:** Start with tkey-sign as it provides signing capabilities that can be used for key derivation.

### 2. Client Application (initramfs)
- **tkey-luks-unlock**: Statically compiled binary
- Communicates with TKey device app
- Derives LUKS key from TKey response
- Passes key to cryptsetup
- Must be:
  - Statically linked (no dynamic dependencies)
  - Small footprint for initramfs
  - Robust error handling

### 3. initramfs Integration
- **Hook scripts** for initramfs-tools (Debian/Ubuntu) or dracut (Fedora/RHEL)
- **Installation scripts** to add binaries and device app
- **Boot scripts** to trigger unlock process

### 4. Installation System
- Script to install client binary
- Script to copy device app
- Hook integration
- Configuration management

### 5. Test Environment
- QEMU VM with LUKS encrypted root
- Test scripts for end-to-end validation
- Automated testing framework

## Technical Approach

### Key Derivation Strategy
1. **Challenge-Response Model:**
   - Client generates or uses pre-stored challenge
   - Sends challenge to TKey
   - TKey signs challenge with device-unique key
   - Client derives LUKS key from signature (e.g., using PBKDF2 or HKDF)

2. **Direct Derivation Model:**
   - Client requests key material from TKey
   - TKey derives key using device secrets
   - Returns derived key material
   - Client uses directly or further processes for LUKS

### Static Compilation
- Use musl-libc for smaller, fully static binaries
- Compile all dependencies statically
- Ensure no dynamic library dependencies
- Target: `x86_64-unknown-linux-musl` or similar

## Project Structure

```
tkey-luks/
├── README.md                    # Project documentation
├── PLAN.md                      # This file
├── docs/                        # Additional documentation
│   ├── SETUP.md                 # Setup instructions
│   ├── TESTING.md               # Testing guide
│   └── SECURITY.md              # Security considerations
├── device-app/                  # TKey device application
│   ├── Makefile
│   └── src/
├── client/                      # Client application (initramfs)
│   ├── go.mod                   # Go module (if using Go)
│   ├── Makefile                 # Build system
│   └── src/
│       └── main.c               # Or main.go for Go
├── initramfs-hooks/             # initramfs integration
│   ├── hooks/                   # Hook scripts
│   │   └── tkey-luks
│   ├── scripts/                 # Boot scripts
│   │   └── local-top/
│   │       └── tkey-luks-unlock
│   └── install.sh               # Installation script
├── test/                        # Testing infrastructure
│   ├── qemu/                    # QEMU VM setup
│   │   ├── create-vm.sh
│   │   ├── run-vm.sh
│   │   └── README.md
│   ├── luks-setup/              # LUKS test image creation
│   │   ├── create-test-image.sh
│   │   └── test-unlock.sh
│   └── integration/             # Integration tests
│       └── test-boot.sh
├── scripts/                     # Utility scripts
│   ├── install.sh               # Main installation script
│   ├── build-all.sh             # Build all components
│   └── setup-dev.sh             # Development setup
├── submodules/                  # Git submodules (symbolic link target)
│   ├── tkey-libs/               # TKey libraries
│   ├── tkey-sign/               # TKey signing app (reference)
│   └── tkey-device-signer/      # Device signing library
└── .gitmodules                  # Git submodule configuration
```

## Implementation Phases

### Phase 1: Environment Setup (Week 1)
- [ ] Initialize git repository
- [ ] Add required git submodules:
  - `tkey-libs` - Core TKey communication libraries
  - `tkey-sign` - Reference signing implementation
  - `tkey-device-signer` - Device-side signing
- [ ] Set up build environment
- [ ] Document dependencies

### Phase 2: Device Application (Week 1-2)
- [ ] Evaluate tkey-sign for suitability
- [ ] Test static compilation of tkey-sign
- [ ] Create or adapt device app for key derivation
- [ ] Test device app on TKey hardware
- [ ] Document device app protocol

### Phase 3: Client Application (Week 2-3)
- [ ] Implement client communication with TKey
- [ ] Implement key derivation logic
- [ ] Add cryptsetup integration
- [ ] Static compilation setup
- [ ] Error handling and logging
- [ ] Command-line interface

### Phase 4: initramfs Integration (Week 3)
- [ ] Create initramfs hooks
- [ ] Create boot scripts
- [ ] Installation scripts
- [ ] Configuration management
- [ ] Test on various distributions

### Phase 5: Test Environment (Week 3-4)
- [ ] QEMU VM setup scripts
- [ ] LUKS test image creation
- [ ] Automated test suite
- [ ] Documentation

### Phase 6: Security Hardening & Documentation (Week 4)
- [ ] Security audit
- [ ] Documentation completion
- [ ] User guide
- [ ] Troubleshooting guide

## Dependencies

### Build Dependencies
- **C/C++ Toolchain:** gcc, g++, make
- **Go Toolchain:** go 1.20+ (recommended for TKey clients)
- **TKey SDK:** Tillitis development tools
- **Static Linking:** musl-libc, static libraries
- **LLVM/Clang:** For advanced static compilation

### Runtime Dependencies (initramfs)
- cryptsetup (already in initramfs)
- USB device access (udev/devfs)

### Test Dependencies
- QEMU/KVM
- cryptsetup
- e2fsprogs (for filesystem creation)
- debootstrap or similar (for test rootfs)

## Git Submodules to Add

1. **tkey-libs** - Core libraries for TKey communication
   - Repository: https://github.com/tillitis/tkey-libs

2. **tkey-sign** - Reference signing implementation
   - Repository: https://github.com/tillitis/tkey-sign (verify correct repo)

3. **tkey-device-signer** - Device-side signing implementation
   - Repository: Part of Tillitis SDK

## Security Considerations

### Threat Model
- **Physical Security:** TKey must be physically secure
- **Boot Integrity:** Bootloader should verify initramfs (UEFI Secure Boot)
- **Key Derivation:** Use cryptographically secure derivation
- **Side Channels:** Consider timing attacks
- **Fallback:** Need emergency unlock mechanism

### Best Practices
1. Use hardware-based key derivation
2. Implement rate limiting on failures
3. Log all attempts (after root is mounted)
4. Support key rotation
5. Multiple TKey support (backup keys)

## Testing Strategy

### Unit Tests
- Device app functionality
- Client key derivation
- Communication protocol

### Integration Tests
- Full boot sequence
- QEMU VM with LUKS
- Multiple unlock attempts
- Error scenarios

### Test Scenarios
1. **Happy Path:** TKey present, correct unlock
2. **Missing TKey:** Boot failure handling
3. **Wrong TKey:** Rejection and retry
4. **USB Errors:** Timeout and error handling
5. **Multiple Attempts:** Rate limiting
6. **Fallback:** Manual password entry

## Alternative Solutions Analysis

### Solution 1: Use tkey-sign (Recommended)
**Pros:**
- Existing, tested codebase
- Known security properties
- Can derive keys from signatures
- Already supports static compilation

**Cons:**
- May be over-featured for our needs
- Need to ensure signature output is suitable for key derivation

### Solution 2: Custom Device App
**Pros:**
- Purpose-built for LUKS
- Minimal code surface
- Optimized for our specific use case

**Cons:**
- More development time
- Need our own security audit
- Maintenance burden

### Solution 3: TPM Integration
**Alternative Approach** (for comparison)
**Pros:**
- TPM widely available
- Mature tooling (clevis, systemd-cryptenroll)

**Cons:**
- Not using TKey (doesn't meet requirement)
- TPM on motherboard (different threat model)

## Configuration File Format

```yaml
# /etc/tkey-luks.conf
device:
  app_path: /usr/lib/tkey-luks/device-app.bin
  timeout: 30

luks:
  device: /dev/sda2  # Auto-detected from crypttab
  key_slot: 0
  derivation: pbkdf2
  iterations: 100000

security:
  max_attempts: 3
  lockout_time: 60

fallback:
  enable: true
  prompt_timeout: 10
```

## Open Questions

1. **Which Tillitis repos should we use?** - Need to verify correct upstream repos
2. **C or Go for client?** - Go is standard for TKey clients and offers good performance
3. **Key storage format?** - How do we enroll TKey initially?
4. **Multiple TKeys?** - Support for backup keys?
5. **Distribution support?** - Start with Debian/Ubuntu or support multiple?

## Success Criteria

- [ ] TKey successfully unlocks LUKS partition
- [ ] Boot time impact < 5 seconds
- [ ] Statically compiled client < 5MB
- [ ] Works in initramfs environment
- [ ] Comprehensive test suite passing
- [ ] Documentation complete
- [ ] Security review completed

## Next Steps

1. Research exact Tillitis repository URLs
2. Set up git submodules
3. Create initial project structure
4. Test tkey-sign static compilation
5. Begin device app evaluation
6. Set up development VM

## References

- Tillitis Documentation: https://dev.tillitis.se/
- LUKS Specification: https://gitlab.com/cryptsetup/cryptsetup
- initramfs-tools: https://manpages.debian.org/initramfs-tools
- cryptsetup: https://gitlab.com/cryptsetup/cryptsetup/-/wikis/home
