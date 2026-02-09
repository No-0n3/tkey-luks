# Project Version and Release Notes

## Current Version: v1.1.0

### v1.1.0 - Improved USS Derivation (January 2025)

#### Major Security Enhancement: Password-Based USS Derivation

This release introduces a significant security improvement by eliminating USS file storage and implementing password-based USS derivation using PBKDF2.

#### 🔒 Security Improvements

- **No USS Files**: USS is now derived from password at boot time (never stored on disk)
- **PBKDF2-HMAC-SHA256**: Strong key derivation with 100,000 iterations (configurable)
- **System-Unique**: Machine-id used as salt for system-specific key derivation
- **Double Password Protection**: Password used in both USS derivation and BLAKE2b challenge
- **Attack Resistance**: Eliminates USS extraction attacks from boot partition

#### ✨ New Features

**Client Application:**

- Added `--derive-uss` flag for improved USS derivation mode
- Added `--uss-password` and `--uss-password-stdin` flags for password input
- Added `--salt` flag for custom salt (defaults to machine-id)
- Added `--pbkdf2-iterations` flag (default: 100,000)
- Deprecated `--uss PATH` with migration warnings
- Automatic system salt detection (machine-id → dbus machine-id → DMI UUID → hostname)

**Initramfs Integration:**

- Updated `00-tkey-luks` script to use `--derive-uss` automatically
- Password entry at boot derives USS dynamically
- No changes to `/etc/crypttab` required (still needs `initramfs` option)

**Documentation:**

- New comprehensive guide: `docs/USS-DERIVATION.md`
- Updated `docs/SETUP.md` with improved enrollment instructions
- Updated `docs/SECURITY.md` with new security model analysis
- Migration guide from v1.0.x file-based USS

**Testing:**

- New test script: `test/test-uss-derivation.sh` (USS derivation unit tests)
- New test script: `test/test-improved-uss.sh` (hardware validation)
- Updated `test/luks-setup/*.sh` scripts for improved USS
- All tests pass on real hardware (TKey at /dev/ttyACM0)

**Packaging:**

- Complete Debian packaging (`debian/` directory)
- GitHub Actions workflow for automated releases (`.github/workflows/release.yml`)
- Automated Debian package building on version tags
- CI/CD integration with package testing

#### 🔄 Migration from v1.0.x

If you're using file-based USS (v1.0.x):

1. Enroll with improved USS derivation (new keyslot):

   ```bash
   echo "password" | sudo tkey-luks-client --derive-uss \
     --challenge-from-stdin --output - | \
   sudo cryptsetup luksAddKey /dev/sdXY -
   ```

2. Update initramfs and test boot:

   ```bash
   sudo update-initramfs -u
   sudo reboot
   ```

3. After confirming boot works, remove old keyslot:

   ```bash
   sudo cryptsetup luksKillSlot /dev/sdXY <old-slot-number>
   ```

4. Delete old USS files:

   ```bash
   sudo rm -rf /boot/initramfs-uss/
   ```

#### ⚠️ Breaking Changes

**None** - Full backward compatibility maintained:

- Old `--uss PATH` flag still works (with deprecation warning)
- Existing enrolled keys continue to function
- Initramfs scripts support both old and new methods

#### 📊 Technical Details

**USS Derivation Formula:**

```text
USS = PBKDF2-HMAC-SHA256(
  password = user_password,
  salt = machine-id,
  iterations = 100000,
  length = 32 bytes
)
```

**Full Cryptographic Flow:**

1. Client derives USS from password using PBKDF2
2. TKey generates CDI: `CDI = Hash(UDS ⊕ App ⊕ USS)`
3. Device app derives Ed25519 key from CDI
4. Device app computes: `LUKS_key = BLAKE2b(key=secret_key, data=password)`

**Security Properties:**

- Password used in **two independent layers** (USS + BLAKE2b)
- USS never exposed to filesystem or network
- Device-unique via UDS (unextractable hardware secret)
- System-unique via machine-id salt
- Strong KDF prevents brute-force (100k iterations)
- Physical touch required (prevents automation)

#### 🏗️ Build System Changes

- Updated `client/Makefile` (no changes required)
- Updated `debian/rules` for package building
- Added `golang.org/x/crypto/pbkdf2` dependency
- Go 1.21+ required (for crypto libraries)

#### 📝 Files Changed

**Core Implementation:**

- `client/main.go` - Added USS derivation functions
- `initramfs-hooks/scripts/local-top/00-tkey-luks` - Added --derive-uss flag

**Documentation:**

- `docs/USS-DERIVATION.md` - New comprehensive security guide
- `docs/SETUP.md` - Updated with improved enrollment
- `docs/SECURITY.md` - Updated security model analysis
- `README.md` - Updated with v1.1.0 features

**Testing:**

- `test/test-uss-derivation.sh` - New USS unit tests
- `test/test-improved-uss.sh` - New hardware test
- `test/luks-setup/*.sh` - Updated for --derive-uss

**Packaging:**

- `debian/control` - Package metadata
- `debian/rules` - Build rules
- `debian/changelog` - Release notes
- `debian/postinst` - Post-installation script
- `debian/postrm` - Post-removal script
- `debian/copyright` - License information
- `.github/workflows/release.yml` - CI/CD automation

**Scripts:**

- `scripts/install.sh` - Updated instructions for improved USS

---

### v1.0.0 - Initial Release (2024)

#### First Stable Release of TKey-LUKS

#### Features

- TKey-based LUKS unlock at boot time
- File-based USS storage in `/boot/initramfs-uss/`
- Initramfs integration with Ubuntu 24.04
- Client application for key derivation
- Device application for TKey firmware
- LUKS1 and LUKS2 support
- Basic documentation and setup guides

#### Known Issues

- USS stored in plaintext file (security concern)
- Single-layer password protection (BLAKE2b only)
- No system-unique binding (USS portable across systems)

**Status**: Replaced by v1.1.0 with improved USS derivation

---

## Release Notes Format

Each release follows semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes to API or behavior
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

## Changelog Generation

GitHub releases are automatically created via CI/CD on version tags:

```bash
git tag v1.1.0
git push origin v1.1.0
```

The release workflow builds Debian packages and creates GitHub releases with:

- Debian package (`.deb`)
- Source tarball
- Binary tarball
- SHA256 checksums
- Release notes
