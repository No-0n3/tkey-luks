#!/usr/bin/env python3
"""
Derive the TKey LUKS key that the device app will produce.

This simulates what the TKey device app does:
1. Generate Ed25519 keypair from CDI (32 bytes)
2. Use the secret key (64 bytes) with BLAKE2s to derive LUKS key
3. Output the derived key in hex format

For testing, we use a known CDI value.
"""

import sys
import hashlib
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.backends import default_backend

try:
    # Try Monocypher bindings (if available)
    import monocypher
    HAS_MONOCYPHER = True
except ImportError:
    HAS_MONOCYPHER = False

try:
    # Try PyNaCl for Ed25519
    import nacl.signing
    import nacl.bindings
    HAS_NACL = True
except ImportError:
    HAS_NACL = False

# BLAKE2b is in hashlib
def blake2b_derive(key_material, challenge):
    """
    Derive LUKS key using BLAKE2b (supports 64-byte output)
    Matches: crypto_blake2b_keyed(output, 64, key_material, 64, challenge, challenge_len)
    """
    import hashlib
    h = hashlib.blake2b(
        challenge,
        digest_size=64,  # 512 bits output (BLAKE2b supports up to 64 bytes)
        key=key_material,
        person=b"tkey-luks"  # Personalization string
    )
    return h.digest()

def derive_ed25519_keypair_from_cdi(cdi_bytes):
    """
    Derive Ed25519 keypair from CDI (32 bytes)
    This matches: crypto_ed25519_key_pair(secret_key, pubkey, cdi)
    """
    if HAS_NACL:
        # Use PyNaCl
        # Ed25519 seed is 32 bytes
        signing_key = nacl.signing.SigningKey(cdi_bytes)
        secret_key = signing_key._signing_key  # 32-byte seed + 32-byte pubkey = 64 bytes
        # But we need the full 64-byte secret key format
        # In Ed25519, secret_key = seed || public_key
        pubkey = bytes(signing_key.verify_key)
        secret_key_full = cdi_bytes + pubkey
        return secret_key_full, pubkey
    else:
        # Fallback: Use hash-based derivation (not cryptographically identical but for testing)
        print("WARNING: PyNaCl not available, using hash-based derivation (for testing only)")
        print("Install PyNaCl: pip install pynacl")
        # Hash CDI to get "secret key"
        secret_key = hashlib.sha512(cdi_bytes).digest()
        pubkey = hashlib.sha256(secret_key[:32]).digest()
        return secret_key, pubkey

def main():
    # Test CDI (32 bytes) - all zeros for simplicity
    # In real usage, this comes from TKey hardware
    # You can also pass USS (User Supplied Secret) which gets mixed with CDI
    print("=== TKey LUKS Key Derivation ===")
    print()
    
    # Test CDI: For testing, we'll use a known value
    cdi_hex = "00" * 32  # All zeros
    if len(sys.argv) > 1:
        cdi_hex = sys.argv[1]
        if len(cdi_hex) != 64:
            print(f"ERROR: CDI must be 64 hex characters (32 bytes)")
            print(f"Got: {len(cdi_hex)} characters")
            sys.exit(1)
    
    cdi = bytes.fromhex(cdi_hex)
    print(f"CDI (test): {cdi_hex}")
    
    # Step 1: Derive Ed25519 keypair from CDI
    print()
    print("[1/3] Deriving Ed25519 keypair from CDI...")
    secret_key, pubkey = derive_ed25519_keypair_from_cdi(cdi)
    print(f"Public key: {pubkey.hex()}")
    print(f"Secret key length: {len(secret_key)} bytes")
    
    # Step 2: Use test challenge
    # The client will send this challenge to the device
    challenge_hex = "a" * 64  # 32 bytes of 0xaa
    if len(sys.argv) > 2:
        challenge_hex = sys.argv[2]
    
    challenge = bytes.fromhex(challenge_hex)
    print()
    print(f"[2/3] Challenge (test): {challenge_hex}")
    print(f"Challenge length: {len(challenge)} bytes")
    
    # Step 3: Derive LUKS key using BLAKE2s
    print()
    print(f"[3/3] Deriving LUKS key with BLAKE2b...")
    derived_key = blake2b_derive(secret_key, challenge)
    
    print()
    print("=== Derived LUKS Key ===")
    print()
    print(f"Key (hex): {derived_key.hex()}")
    print(f"Key length: {len(derived_key)} bytes ({len(derived_key) * 8} bits)")
    print()
    
    # Save to file
    keyfile = "tkey-derived-key.bin"
    with open(keyfile, "wb") as f:
        f.write(derived_key)
    print(f"Key saved to: {keyfile}")
    
    # Also save hex
    hex_file = "tkey-derived-key.hex"
    with open(hex_file, "w") as f:
        f.write(derived_key.hex())
    print(f"Key hex saved to: {hex_file}")
    
    print()
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("Add this key to LUKS:")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()
    print(f"sudo cryptsetup luksAddKey test-luks-10mb.img {keyfile}")
    print()
    print("Or test unlock directly:")
    print(f"sudo cryptsetup luksOpen test-luks-10mb.img test --key-file {keyfile}")
    print()

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in ["-h", "--help"]:
        print("Usage: ./derive-tkey-key.py [CDI_HEX] [CHALLENGE_HEX]")
        print()
        print("Derives the key that TKey device app will produce.")
        print()
        print("Arguments:")
        print("  CDI_HEX: 64 hex chars (32 bytes) - default: all zeros")
        print("  CHALLENGE_HEX: hex string - default: 64 'a's (32 bytes)")
        print()
        print("Example:")
        print("  ./derive-tkey-key.py 0123456789abcdef... aabbccdd...")
        print()
        sys.exit(0)
    
    main()
