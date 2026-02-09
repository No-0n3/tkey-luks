# TKey-LUKS: Hardware-Based LUKS Unlock with Tillitis TKey

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)

Unlock LUKS encrypted root partitions at boot using Tillitis TKey hardware security key.

## Overview

This project provides a secure mechanism to unlock LUKS encrypted root partitions during boot using a Tillitis TKey hardware security device. The TKey must be physically present in the computer during boot, and the LUKS encryption key is derived from cryptographic operations performed by the TKey.

## Features

- 🔐 **Hardware-Based Security**: LUKS key derived from TKey device secrets
- 🔑 **Improved USS Derivation**: Password-derived USS using PBKDF2 (never stored on disk!)
- 🚀 **Boot Integration**: Seamless integration with initramfs
- 🔧 **Static Binary**: No dependencies in initramfs environment
- 🧪 **Test Environment**: Hardware and image-based test scripts
- 📦 **Easy Installation**: Automated installation scripts
- 🔄 **Fallback Support**: Optional password fallback
- ✅ **Conventional Commits**: Strict commit standards enforced via CI and git hooks

## Security Highlights

**NEW: Improved USS Derivation** - The User Supplied Secret (USS) is now derived from your password using PBKDF2 instead of being stored in a file. This means:

- ✅ USS is never written to disk or stored in initramfs
- ✅ Password is used in TWO cryptographic layers (USS + challenge)
- ✅ Each system has a unique USS (via machine-id salt)
- ✅ Strong KDF with 100k iterations makes brute-force harder
- ✅ No extractable secrets from the boot partition

**Why this matters:** Previously, if USS was stored in initramfs, an attacker with physical access could extract it, reducing 3-factor auth to 1-factor. The improved approach keeps USS ephemeral and password-derived.

See [docs/USS-DERIVATION.md](docs/USS-DERIVATION.md) for detailed security analysis.

## Project Status

✅ **v1.1.0 Release** - Improved USS Derivation with password-based security!

### Latest Updates (v1.1.0)

- ✅ **Password-Based USS Derivation**: PBKDF2-HMAC-SHA256 with 100k iterations
- ✅ **No USS Files**: Removed need for USS file storage (ephemeral derivation)
- ✅ **System-Unique**: Machine-id used as salt for system-specific keys
- ✅ **Double Protection**: Password used in USS derivation + BLAKE2b challenge
- ✅ **Backward Compatible**: Old `--uss PATH` still works (with warnings)
- ✅ **Debian Packaging**: `debian/` kept in-repo for reproducible builds; CI uses it to build packages
- ✅ **Comprehensive Documentation**: Security analysis, migration guide, setup instructions

**Why keep `debian/` in-repo?** It keeps packaging reproducible, reviewable, and buildable locally with standard debhelper tooling. CI consumes the same files to avoid drift between local and server builds.

### Tested Systems

- **Ubuntu 24.04 Desktop** - Full boot-time LUKS unlock with improved USS derivation
- Real hardware: NVMe encrypted partitions with TKey
- Boot timing: ~33 seconds total (including physical touch)
- Test results: USS derivation deterministic, system-specific, secure

See [docs/SETUP.md](docs/SETUP.md) for setup instructions and [docs/USS-DERIVATION.md](docs/USS-DERIVATION.md) for security details.

## Quick Start

### Prerequisites

- Tillitis TKey hardware device
- Linux system with initramfs-tools (Ubuntu 24.04 tested)
- Go 1.20+ (for building client)
- LLVM/Clang 15+ (for building device app)
- cryptsetup-initramfs package
- libusb-1.0-0-dev

### Installation

```bash
# Clone repository with submodules
git clone --recursive https://github.com/No-0n3/tkey-luks.git
cd tkey-luks

# Install Node.js dependencies and git hooks (for contributors)
npm install

# Build all components
./scripts/build-all.sh

# Install to system
sudo make -C client install
sudo make -C device-app install
sudo make -C initramfs-hooks install
```

### Adding TKey to LUKS Partition

```bash
# Add TKey-derived key to LUKS partition (requires existing password)
cd client
sudo ./tkey-luks-client --challenge "YourChallengePhrase" | \
  sudo cryptsetup luksAddKey /dev/nvme0n1p6 -

# Verify key was added
sudo cryptsetup luksDump /dev/nvme0n1p6
```

### Configuring Boot Unlock (Ubuntu 24.04)

**Critical:** Ubuntu 24.04 requires the `initramfs` option in `/etc/crypttab` for custom unlock scripts.

Edit `/etc/crypttab` and add `initramfs` to the options:

```bash
# Before:
luks-<uuid> UUID=<uuid> none luks,discard

# After:
luks-<uuid> UUID=<uuid> none luks,discard,initramfs
```

Then update initramfs:

```bash
sudo update-initramfs -u -k all
```

### Usage (Improved USS Derivation)

**New enrollment process (v1.1.0+):**

```bash
# Enroll with improved USS derivation (recommended)
echo "YourPassword" | sudo tkey-luks-client \
  --challenge-from-stdin \
  --derive-uss \
  --output - | \
sudo cryptsetup luksAddKey /dev/sdXY -
```

**At Boot:**

1. System prompts for password
2. USS derived from password using PBKDF2 (never stored!)
3. Touch TKey when it blinks (physical authentication)
4. System derives LUKS key and unlocks automatically

**Double protection:** Your password is used in both USS derivation AND the BLAKE2b challenge, providing two independent cryptographic layers.

**Fallback**: Emergency LUKS password still works if TKey is not present.

### Testing

```bash
# Test USS derivation unit tests
cd test
./test-uss-derivation.sh

# Test with real TKey hardware
./test-improved-uss.sh

# Test LUKS image creation and unlock
cd test/luks-setup
./create-tkey-test-image.sh
./add-tkey-key.sh
./test-unlock.sh
```

## Architecture

The system consists of three main components:

1. **Device Application**: Runs on TKey, performs cryptographic operations
2. **Client Application**: Runs in initramfs, communicates with TKey
3. **initramfs Hooks**: Integration with boot process

```text
[initramfs] → [Client Binary] → [USB] → [TKey Device App]
     ↓              ↓                         ↓
[Derived Key] → [cryptsetup] → [Unlock LUKS]
```

## Documentation

- [docs/SETUP.md](docs/SETUP.md) - Setup and installation guide  
- [docs/TESTING.md](docs/TESTING.md) - Testing procedures
- [docs/SECURITY.md](docs/SECURITY.md) - Security considerations
- [initramfs-hooks/README.md](initramfs-hooks/README.md) - Initramfs integration details

## Boot Process Details

The TKey-LUKS unlock happens early in boot:

1. **2s**: Script starts, TKey detected at `/dev/ttyACM0`
2. **14s**: User enters challenge phrase
3. **13s**: Key derivation on TKey (Blake2b, 64 bytes)

## Troubleshooting

### TKey not detected at boot

- Check USB connection and power
- Verify `cdc-acm` module loaded: `lsmod | grep cdc_acm`
- Check initramfs contents: `lsinitramfs /boot/initrd.img-$(uname -r) | grep tkey`

### Script not running

- Verify `initramfs` option in `/etc/crypttab` (required for Ubuntu 24.04)
- Rebuild initramfs: `sudo update-initramfs -u -k all`
- Check dmesg after boot: `dmesg | grep tkey-luks`

### Wrong crypttab path

- Initramfs uses `/cryptroot/crypttab`, not `/etc/crypttab`
- Script automatically reads from correct location

### Key derivation fails

- Ensure TKey button pressed when device blinks
- Verify password matches enrollment
- Check TKey device app loaded correctly: `dmesg | grep tkey`
- For improved USS: Ensure system machine-id hasn't changed

### USS derivation issues

If upgrading from v1.0.x (file-based USS) to v1.1.0 (improved USS):

- Old `--uss PATH` still works (with deprecation warning)
- Enroll new keyslot with `--derive-uss` before removing old one
- Test new keyslot boots successfully before removing old
- See [docs/USS-DERIVATION.md](docs/USS-DERIVATION.md) for migration guide

### Password not working

- Different from v1.0: Password affects **both** USS derivation and BLAKE2b
- Same password must be used at boot and enrollment
- System-specific: Machine-id used as salt (moving disk to new system requires re-enrollment)

## License

This project is licensed under the BSD-2-Clause License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! This project strictly follows [Conventional Commits](https://www.conventionalcommits.org/) to maintain clear and semantic commit history.

### 📋 Commit Message Format

All commits **must** follow this specification:

```text
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Standard Types**:

- `feat`: A new feature for users
- `fix`: A bug fix for users
- `docs`: Documentation changes only
- `style`: Code style changes (formatting, semicolons, etc.)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `build`: Changes to build system or dependencies
- `ci`: Changes to CI configuration
- `chore`: Other changes that don't modify src or test files

**Examples**:

```text
feat(client): add timeout configuration for TKey detection
fix(initramfs): resolve race condition in device detection
docs: update Ubuntu 24.04 installation guide
build: upgrade commitlint to v20.4.1
test: add integration tests for challenge validation
```

### 🔒 Commit Validation

Commits are validated **locally** with git hooks and in **CI** with GitHub Actions.

#### ✨ Automatic Local Validation (Recommended)

Run `npm install` to automatically set up git hooks:

```bash
# Install dependencies and git hooks
npm install
```

**What happens:** The commit-msg hook validates your message before the commit is created.

- ✅ Valid messages: commit proceeds normally
- ❌ Invalid messages: commit is rejected with helpful error messages

#### 🔧 Manual Hook Installation

Reinstall hooks manually if needed:

```bash
./install-hooks.sh
```

#### 🧪 Manual Validation

Check commits without hooks:

```bash
# Validate last commit
npx commitlint --last

# Validate a message
echo "feat: add new feature" | npx commitlint

# Validate last 5 commits
npx commitlint --from HEAD~5
```

#### 🚀 CI/CD Validation

GitHub Actions automatically validates:

- **Push events**: Last commit message
- **Pull requests**: All commits in the PR

**Result**: PRs with invalid commits will fail CI checks and cannot be merged.

This system provides security against:

- Unauthorized boot of stolen devices
- Cold boot attacks (limited)
- Software-only attacks on LUKS keys

See [docs/SECURITY.md](docs/SECURITY.md) for full threat model and considerations.

## Acknowledgments

- Tillitis for the TKey hardware and SDK
- cryptsetup project
- Linux kernel initramfs framework
