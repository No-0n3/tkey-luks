# TKey-LUKS Architecture Diagrams

This directory contains PlantUML diagrams documenting the TKey-LUKS implementation.

## Diagram Files

### 1. Current Implementation Flow

- **Source**: `current-implementation-flow.puml`
- **Image**: `TKey-LUKS Current Implementation Flow.png`
- **Description**: Complete sequence diagram showing the boot-to-unlock process with all components (Initramfs, Client, TKey Hardware, Device App, LUKS). Shows all protocol commands and demonstrates how the current system works.

**Key Points**:

- Shows optional USS handling
- Demonstrates the BLAKE2b key derivation
- Highlights the security weakness when USS is stored in initramfs

### 2. Cryptographic Flow

- **Source**: `cryptographic-flow.puml`
- **Image**: `TKey-LUKS Cryptographic Flow.png`
- **Description**: Component diagram showing how secrets flow through the system, from hardware secrets (UDS) through key generation to final LUKS key derivation.

**Key Points**:

- Shows the five stages: Device Secrets → Key Generation → User Input → Key Derivation → Volume Unlock
- Illustrates how CDI combines UDS, App, and USS
- Explains the security weakness of storing USS in initramfs

### 3. Improved Implementation Flow

- **Source**: `improved-implementation-flow.puml`
- **Image**: `TKey-LUKS Improved Implementation Flow.png`
- **Description**: Proposed improved architecture where USS is derived from the user password instead of stored in cleartext in initramfs.

**Key Points**:

- USS = KDF(password, salt) - never stored on disk
- Password used in TWO places: USS derivation and challenge
- Compares security properties of current vs improved approach
- Shows how to achieve true multi-factor authentication

## Viewing the Diagrams

### Option 1: View PNG Images (Recommended)

Just open the PNG files in any image viewer:

```bash
xdg-open "TKey-LUKS Current Implementation Flow.png"
xdg-open "TKey-LUKS Cryptographic Flow.png"
xdg-open "TKey-LUKS Improved Implementation Flow.png"
```

### Option 2: Regenerate from Source

If you modify the `.puml` files, regenerate the images:

```bash
cd docs
java -jar plantuml.jar -tpng *.puml
```

### Option 3: View/Edit Online

Upload `.puml` files to: <http://www.plantuml.com/plantuml/uml/>

## Security Analysis Summary

### Current Weaknesses (❌)

1. **USS is optional** - Many deployments may not use it
2. **USS stored in initramfs** - Extractable with `unmkinitramfs`
3. **Challenge is single factor** - Only user password
4. **USS not in challenge** - Only affects CDI, not the derivation input

**Attack scenario**:

```text
Attacker steals: Laptop + TKey
Attacker extracts: USS from /boot/initramfs (unmkinitramfs)
Attacker only needs: User password (brute force or keylog)
Result: 3-factor becomes 1-factor!
```

### Improved Design (✅)

1. **USS derived from password** - Never stored anywhere
2. **Use strong KDF** - PBKDF2 or Argon2 with system salt
3. **Password used twice** - USS derivation + challenge
4. **Per-system salt** - Machine-id or UUID

**Better security**:

```text
Attacker steals: Laptop + TKey
Attacker cannot extract: USS (computed, not stored)
Attacker still needs: Password + TKey hardware
Result: True multi-factor!
```

### Best Design (✅✅✅)

Use **separate hardware token** for USS:

- Store USS on USB stick or smart card
- Requires three physical items: TKey + USB + password
- True three-factor: HAVE (TKey), HAVE (USB), KNOW (password)

## Implementation Notes

### Current Formula

```text
CDI = Hash(UDS + App + USS_stored)
secret_key = Ed25519_derive(CDI)
LUKS_key = BLAKE2b(key=secret_key, data=user_password)
```

### Improved Formula

```text
USS = PBKDF2(password, machine_salt, 100000)
CDI = Hash(UDS + App + USS_derived)
secret_key = Ed25519_derive(CDI)
LUKS_key = BLAKE2b(key=secret_key, data=user_password)
```

Password contributes to BOTH CDI (via USS) and challenge!

## Editing Diagrams

The PlantUML files use standard PlantUML syntax:

- Sequence diagrams: `@startuml ... @enduml`
- Component diagrams: `package`, `component`, `note`
- Colors: `#lightblue`, `#palegreen`, etc.
- Formatting: `<b>bold</b>`, `<color:red>colored</color>`

Make changes to `.puml` files and regenerate PNGs.

## References

- PlantUML Documentation: <https://plantuml.com/>
- TKey Documentation: <https://dev.tillitis.se/>
- BLAKE2 Specification: <https://www.blake2.net/>
- LUKS Specification: <https://gitlab.com/cryptsetup/cryptsetup>
