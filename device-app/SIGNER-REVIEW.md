# tkey-device-signer Code Review
## Understanding the Base Implementation

This document explains how tkey-device-signer works and what we need to adapt for LUKS key derivation.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     TKey Device App                      │
│                                                          │
│  ┌────────────┐     ┌──────────┐     ┌──────────────┐  │
│  │  STARTED   │────>│ LOADING  │────>│   SIGNING    │  │
│  │            │     │          │     │              │  │
│  │ - Get keys │     │- Load    │     │- Touch wait  │  │
│  │ - Set size │     │  message │     │- Sign msg    │  │
│  └────────────┘     │  chunks  │     │- Return sig  │  │
│                     └──────────┘     └──────────────┘  │
│                                                          │
│  Secret: CDI (32 bytes) → Ed25519 key pair (64B + 32B) │
└─────────────────────────────────────────────────────────┘
```

---

## Protocol Flow (Current Signer)

### 1. **Initialization** (main.c:467)
```c
// Generate public/private key pair from CDI
crypto_ed25519_key_pair(ctx.secret_key, ctx.pubkey, (uint8_t *)cdi);
//                      ↑ 64 bytes       ↑ 32 bytes   ↑ from hardware
```

**CDI** = Compound Device Identifier (unique per TKey + USS if provided)

### 2. **STATE_STARTED Commands** (main.c:90-220)

| Command                | Code | Length | Action                              |
|------------------------|------|--------|-------------------------------------|
| `CMD_GET_PUBKEY`       | 0x01 | 1 B    | Return 32-byte public key           |
| `CMD_SET_SIZE`         | 0x03 | 32 B   | Set message size, transition to LOADING |
| `CMD_GET_NAMEVERSION`  | 0x09 | 1 B    | Return app name/version             |
| `CMD_GET_FIRMWARE_HASH`| 0x0b | 32 B   | Return SHA-512 of firmware          |

**Key Part - CMD_SET_SIZE** (main.c:175-211):
```c
// Extract size from command bytes [1..4]
local_message_size = pkt.cmd[1] + (pkt.cmd[2] << 8) + 
                     (pkt.cmd[3] << 16) + (pkt.cmd[4] << 24);

// Validate: 0 < size <= MAX_SIGN_SIZE (4096)
if (local_message_size == 0 || local_message_size > MAX_SIGN_SIZE) {
    rsp[0] = STATUS_BAD;
    state = STATE_FAILED;
}

// Setup for loading
ctx->message_size = local_message_size;
ctx->left = ctx->message_size;  // Bytes left to receive
ctx->msg_idx = 0;               // Current position

state = STATE_LOADING;  // ← Transition!
```

### 3. **STATE_LOADING Commands** (main.c:235-285)

| Command          | Code | Length | Action                          |
|------------------|------|--------|---------------------------------|
| `CMD_LOAD_DATA`  | 0x05 | 128 B  | Load 127 bytes of message data  |

**Loading Process** (main.c:245-275):
```c
// Each CMD_LOAD_DATA carries 127 bytes (128 - 1 for cmd code)
nbytes = (ctx->left > 127) ? 127 : ctx->left;

// Copy into message buffer
memcpy_s(&ctx->message[ctx->msg_idx], 
         MAX_SIGN_SIZE - ctx->msg_idx, 
         pkt.cmd + 1,    // Skip command byte
         nbytes);

ctx->msg_idx += nbytes;
ctx->left -= nbytes;

// All loaded?
if (ctx->left == 0) {
    state = STATE_SIGNING;  // ← Transition!
}
```

**Example**: 300-byte message needs 3 calls:
- Load #1: 127 bytes
- Load #2: 127 bytes  
- Load #3: 46 bytes → Transition to SIGNING

### 4. **STATE_SIGNING Commands** (main.c:302-350)

| Command      | Code | Length | Action                     |
|--------------|------|--------|----------------------------|
| `CMD_GET_SIG`| 0x07 | 1 B    | Wait for touch, sign, return |

**Signing Process** (main.c:307-344):
```c
#ifndef TKEY_SIGNER_APP_NO_TOUCH
    // Wait for user to touch the button (30 second timeout)
    touched = touch_wait(LED_GREEN, TOUCH_TIMEOUT);
    if (!touched) {
        rsp[0] = STATUS_BAD;
        state = STATE_STARTED;  // Reset!
        return;
    }
#endif

// ★ THIS IS WHAT WE'LL REPLACE ★
crypto_ed25519_sign(signature,        // OUT: 64 bytes
                    ctx->secret_key,  // IN: 64 bytes (private key)
                    ctx->message,     // IN: loaded message
                    ctx->message_size); // IN: message length

// Return signature (64 bytes in rsp[1..64])
memcpy_s(rsp + 1, CMDLEN_MAXBYTES, signature, 64);
appreply(pkt.hdr, RSP_GET_SIG, rsp);

// Clean up sensitive data
crypto_wipe(signature, sizeof(signature));
wipe_context(ctx);

state = STATE_STARTED;  // ← Back to start
```

---

## Data Structures

### Context (main.c:39-47)
```c
struct context {
    uint8_t secret_key[64];       // Ed25519 private key ← FROM CDI
    uint8_t pubkey[32];           // Ed25519 public key
    uint8_t message[MAX_SIGN_SIZE]; // Message buffer (4096 bytes)
    uint32_t left;                // Bytes left to load
    uint32_t message_size;        // Total message size
    uint16_t msg_idx;             // Current load position
};
```

### Packet (main.c:52-56)
```c
struct packet {
    struct frame_header hdr;      // Protocol framing (ID, endpoint, len)
    uint8_t cmd[CMDLEN_MAXBYTES]; // 128 bytes: [0]=command, [1..127]=data
};
```

---

## Memory Layout (CRITICAL for security!)

```
Context Memory Map:
┌──────────────────────────────┐ ← ctx
│  secret_key[64]              │ ← SENSITIVE! Private key
├──────────────────────────────┤
│  pubkey[32]                  │ ← Public (OK to share)
├──────────────────────────────┤
│  message[4096]               │ ← Challenge data
├──────────────────────────────┤
│  left (4 bytes)              │
│  message_size (4 bytes)      │
│  msg_idx (2 bytes)           │
└──────────────────────────────┘

Note: secret_key is placed BELOW message buffer
      to prevent buffer overflows from corrupting it!
```

---

## Cryptographic Operations

### Key Generation (main.c:467)
```c
// Monocypher function
crypto_ed25519_key_pair(
    ctx.secret_key,  // OUT: 64-byte private key
    ctx.pubkey,      // OUT: 32-byte public key  
    (uint8_t *)cdi); // IN: 32-byte seed from hardware CDI
```

### Signing (main.c:329)
```c
// Monocypher Ed25519 signature
crypto_ed25519_sign(
    signature,          // OUT: 64-byte signature
    ctx->secret_key,    // IN: 64-byte private key
    ctx->message,       // IN: message to sign
    ctx->message_size); // IN: message length
```

---

## What We Need to Adapt for LUKS

### Changes Required

#### 1. **Replace Signing with Key Derivation**

**Before (Ed25519 signing):**
```c
crypto_ed25519_sign(signature, ctx->secret_key, ctx->message, ctx->message_size);
```

**After (BLAKE2b key derivation):**
```c
// Use BLAKE2b (already in Monocypher) as KDF
// Input: secret_key (from CDI+USS) + challenge
// Output: 64-byte LUKS key
blake2b(derived_key, 64,        // Output: 64 bytes for LUKS
        ctx->message,           // Input: challenge from initramfs
        ctx->message_size,      // Challenge size
        ctx->secret_key, 64);   // Key: derived from CDI+USS
```

#### 2. **Rename Commands** (keep codes!)

| Old Name         | New Name             | Code | Purpose                    |
|------------------|----------------------|------|----------------------------|
| CMD_SET_SIZE     | CMD_SET_CHALLENGE    | 0x03 | Set challenge size         |
| CMD_LOAD_DATA    | CMD_LOAD_CHALLENGE   | 0x05 | Load challenge chunks      |
| CMD_GET_SIG      | CMD_DERIVE_KEY       | 0x07 | Derive LUKS key            |
| RSP_GET_SIG      | RSP_DERIVE_KEY       | 0x08 | Return derived key         |

#### 3. **Keep These Commands Unchanged**

- ✅ `CMD_GET_PUBKEY` - Still useful for identification
- ✅ `CMD_GET_NAMEVERSION` - Identify as "tkey-luks" app
- ✅ `CMD_GET_FIRMWARE_HASH` - Security verification
- ✅ Touch requirement - Good security practice

#### 4. **State Machine** - Keep the same!

```
STARTED → LOADING → DERIVING → back to STARTED
   ↑                    ↓
   └────────────────────┘
```

#### 5. **Context Changes**

```c
struct luks_context {
    uint8_t secret_material[64]; // CDI+USS derived (was: secret_key)
    uint8_t pubkey[32];          // Keep for identification
    uint8_t challenge[256];      // Challenge from initramfs (was: message)
    uint32_t left;               // Keep
    uint32_t challenge_size;     // Was: message_size
    uint16_t challenge_idx;      // Was: msg_idx
};
```

---

## Key Insights for Adaptation

### ✅ **Keep These:**
1. **State machine structure** - It's solid
2. **Protocol framing** - TKey standard
3. **Touch requirement** - Physical presence proof
4. **USS support** - User personalization
5. **Memory layout** - Secret before buffer (security)
6. **Command codes** - Client compatibility

### 🔧 **Change These:**
1. **crypto_ed25519_sign()** → **blake2b()** for KDF
2. **Variable names** - message → challenge, etc.
3. **App name** - "tk1 sign" → "tk1 luks"
4. **MAX_SIGN_SIZE** - 4096 bytes → maybe smaller (128 bytes challenge?)
5. **State name** - STATE_SIGNING → STATE_DERIVING

### 🚫 **Remove These:**
- Nothing! Ed25519 key pair generation is still useful for identification

---

## Implementation Strategy

### Phase 1: Copy & Rename ✅
```bash
cp submodules/tkey-device-signer/signer/main.c device-app/src/luks_main.c
cp submodules/tkey-device-signer/signer/app_proto.{c,h} device-app/src/
```

### Phase 2: Search & Replace
- `CMD_GET_SIG` → `CMD_DERIVE_KEY`
- `RSP_GET_SIG` → `RSP_DERIVE_KEY`  
- `CMD_SET_SIZE` → `CMD_SET_CHALLENGE`
- `CMD_LOAD_DATA` → `CMD_LOAD_CHALLENGE`
- `STATE_SIGNING` → `STATE_DERIVING`
- `message` → `challenge`
- `signature` → `derived_key`
- `app_name` → "tk1 luks"

### Phase 3: Replace Crypto
In signing_commands() function:
```c
// OLD:
crypto_ed25519_sign(signature, ctx->secret_key, 
                    ctx->message, ctx->message_size);

// NEW:
blake2b(derived_key, 64,           // 64-byte key output
        ctx->challenge,            // Challenge input
        ctx->challenge_size,       // Challenge size
        ctx->secret_material, 64); // Secret from CDI+USS
```

### Phase 4: Test
1. Build: `make` (with clang)
2. Test with tkey-runapp from submodules/tkey-devtools
3. Test in QEMU: `run-tkey-qemu`

---

## Next Steps

**Option A - Manual Copy/Adapt:**
1. Copy signer files to device-app/src/
2. Rename functions/variables 
3. Replace Ed25519 with BLAKE2b
4. Update Makefile
5. Build & test

**Option B - Start from Modified Copy:**
1. I can create the adapted version directly
2. Keep signer as reference
3. Test both side-by-side

**Which approach do you prefer?**

---

## Files to Work With

**Reference (READ ONLY):**
- `submodules/tkey-device-signer/signer/main.c` (498 lines)
- `submodules/tkey-device-signer/signer/app_proto.c` (92 lines)  
- `submodules/tkey-device-signer/signer/app_proto.h` (32 lines)

**Our Implementation:**
- `device-app/src/main.c` (adapt from signer)
- `device-app/src/app_proto.c` (copy & modify)
- `device-app/src/app_proto.h` (copy & modify)
- `device-app/Makefile` (already configured!)

**Build Target:**
- `device-app/tkey-luks-device.bin` - Flash to TKey
