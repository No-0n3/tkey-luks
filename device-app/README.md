# TKey-LUKS Device Application

This is the device application that runs on the TKey hardware (RISC-V).

**Base Implementation:** Adapted from [tkey-device-signer v1.0.2](https://github.com/tillitis/tkey-device-signer) for LUKS key derivation.

## Architecture

The device app will:
1. Use the TKey's Compound Device Identifier (CDI) as the base secret
2. Support User Supplied Secret (USS) for key personalization
3. Implement challenge-response protocol (adapted from signer)
4. Derive a LUKS key using cryptographic primitives (Monocypher/BLAKE2b)

## Protocol Changes from tkey-device-signer

| Original (Signer)               | Adapted (LUKS)                      |
|---------------------------------|-------------------------------------|
| `CMD_GET_PUBKEY` → pubkey       | `CMD_GET_PUBKEY` → pubkey (same)    |
| `CMD_SET_SIZE` → set msg size   | `CMD_SET_CHALLENGE` → set challenge |
| `CMD_LOAD_DATA` → load msg      | `CMD_LOAD_CHALLENGE` → load data    |
| `CMD_GET_SIG` → Ed25519 sign    | `CMD_DERIVE_KEY` → derive LUKS key  |
| Uses Monocypher Ed25519         | Uses BLAKE2b/HKDF for KDF           |

## Why tkey-device-signer as Base?

1. **Proven protocol**: Already handles USS, state machine, commands
2. **Crypto library**: Uses Monocypher (includes BLAKE2b)
3. **Production ready**: Used by tkey-ssh-agent and tkey-sign-cli
4. **Similar flow**: Challenge → Process → Response

## Building

### Quick Build

```bash
# Recommended: Use the build script (handles tkey-libs automatically)
./build.sh
```

### Manual Build

```bash
# Ensure submodules are initialized
cd ..
git submodule update --init

# Build tkey-libs (required dependency)
make -C submodules/tkey-libs

# Build device app
cd device-app
make
```

### Build Targets

```bash
make              # Build device app (checks dependencies)
make config       # Show build configuration
make clean        # Clean device app artifacts
make clean-all    # Clean device app and tkey-libs
make install      # Install to /usr/lib/tkey-luks/
```

### Requirements

- **Clang/LLVM 15+** with RISC-V support
- **LLD linker** (lld or lld-20)
- **tkey-libs v0.1.2** (handled by build.sh/Makefile)

Install on Ubuntu/Debian:
```bash
sudo apt-get install clang lld llvm
```

### Output

- `tkey-luks-device.bin` (48 KB) - Raw binary for TKey
- `tkey-luks-device.elf` - ELF executable with debug symbols
- `tkey-luks-device.bin.sha512` - SHA-512 hash for integrity verification

### Binary Integrity Verification

The build process generates a SHA-512 hash of the device app binary for integrity verification:

```bash
# Verify binary integrity after building
make verify

# Or manually:
sha512sum -c tkey-luks-device.bin.sha512
```

The hash file is automatically generated during build but is **not** committed to git - it's generated locally to verify your build matches expectations.

**Security Note:** Always verify the binary integrity before loading onto your TKey, especially if obtained from untrusted sources. The hash ensures the binary hasn't been tampered with.

## Development Approach

### Phase 1: Study the Base
1. ✅ Review `../submodules/tkey-device-signer/signer/main.c`
2. ✅ Understand protocol structure and state machine
3. ⏳ Identify what to keep vs. change

### Phase 2: Adapt for LUKS
1. ⏳ Copy relevant code to `device-app/src/`
2. ⏳ Replace Ed25519 operations with BLAKE2b-based KDF
3. ⏳ Modify command codes and response formats
4. ⏳ Keep USS support for user personalization

### Phase 3: Build & Test
1. ⏳ Build with Clang/LLVM toolchain
2. ⏳ Test with tkey-runapp (from tkey-devtools)
3. ⏳ Test in QEMU with emulated TKey

## Key Files to Reference

From `../submodules/tkey-device-signer/signer/`:
- **`main.c`** (498 lines) - State machine, command handling
  - `started_commands()` - Handle initial commands
  - `loading_commands()` - Handle data loading
  - `signing_commands()` - Handle signing (→ adapt to key derivation)
- **`app_proto.c`** - Protocol implementation
- **`app_proto.h`** - Protocol definitions (command codes, response codes)

## Cryptographic Approach

Instead of Ed25519 signing:

```c
// Original (signer):
crypto_ed25519_sign(signature, secret_key, pubkey, message, message_size);

// Adapted (LUKS key derivation):
// Use BLAKE2b or HKDF with:
// - Input: CDI + USS (if provided) + challenge
// - Output: 512-bit key for LUKS
blake2b(derived_key, 64, 
        challenge, challenge_size,
        secret_material, secret_size);
```

## Memory Layout (Keep Secret Safe!)

From tkey-device-signer:
```c
struct context {
    uint8_t secret_key[64];      // Private key - SENSITIVE!
    uint8_t pubkey[32];
    uint8_t message[MAX_SIZE];   // Buffer for challenge
    uint32_t left;
    uint32_t message_size;
};
```

Adapt to:
```c
struct luks_context {
    uint8_t secret_material[64]; // CDI + USS derived - SENSITIVE!
    uint8_t pubkey[32];          // For identification
    uint8_t challenge[128];      // Challenge from initramfs
    uint32_t challenge_size;
    uint8_t derived_key[64];     // Result - SENSITIVE!
};
```

## Command Protocol

| Command                 | Code   | Length | Data                | Response                  |
|-------------------------|--------|--------|---------------------|---------------------------|
| `CMD_GET_NAMEVERSION`   | 0x09   | 1 B    | none                | `RSP_GET_NAMEVERSION`     |
| `CMD_GET_PUBKEY`        | 0x01   | 1 B    | none                | `RSP_GET_PUBKEY` (32 B)   |
| `CMD_SET_CHALLENGE`     | 0x03   | 32 B   | size (32-bit LE)    | `RSP_SET_CHALLENGE`       |
| `CMD_LOAD_CHALLENGE`    | 0x05   | 128 B  | challenge data      | `RSP_LOAD_CHALLENGE`      |
| `CMD_DERIVE_KEY`        | 0x07   | 1 B    | none                | `RSP_DERIVE_KEY` (64 B)   |

## Next Steps

1. ⏳ Copy protocol structure from tkey-device-signer
2. ⏳ Replace signing logic with key derivation
3. ⏳ Update command codes and names
4. ⏳ Build and test with tkey-runapp
5. ⏳ Integrate with Go client

## Resources

- [tkey-device-signer source](../submodules/tkey-device-signer/signer/)
- [TKey Developer Handbook](https://dev.tillitis.se/)
- [Monocypher docs](https://monocypher.org/)
- [TKey Protocol](https://dev.tillitis.se/protocol/)
