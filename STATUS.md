# TKey-LUKS Project Status

## Current State: Initial Setup Complete

**Date:** February 7, 2026  
**Phase:** Phase 1 - Environment Setup  
**Status:** Foundation laid, ready for development

---

## ✅ Completed

### Project Structure
- [x] Directory structure created
- [x] Git repository initialized
- [x] .gitignore configured
- [x] .gitmodules prepared (URLs need verification)

### Documentation
- [x] PLAN.md - Comprehensive implementation plan
- [x] README.md - Project overview
- [x] docs/SETUP.md - Setup instructions
- [x] docs/SECURITY.md - Security considerations
- [x] docs/TESTING.md - Testing guide
- [x] test/README.md - Test documentation

### Build System
- [x] Client Makefile created
- [x] Device app Makefile created
- [x] Build scripts (build-all.sh)
- [x] Installation script (install.sh)
- [x] Development setup script (setup-dev.sh)

### Test Infrastructure
- [x] QEMU VM creation script
- [x] QEMU VM run script
- [x] LUKS test image creation script
- [x] LUKS unlock test script

### Code Scaffolding
- [x] Client application skeleton (C)
- [x] Device application skeleton (C)
- [x] Function prototypes defined
- [x] TODO markers for implementation

---

## 🔄 Next Steps (In Priority Order)

### Immediate (Next 1-2 days)

1. **Initialize Tillitis Submodules** ✅
   - [x] tkey-libs: https://github.com/tillitis/tkey-libs
   - [x] tkey-device-signer: https://github.com/tillitis/tkey-device-signer
   - [x] tkey-devtools: https://github.com/tillitis/tkey-devtools
   - [ ] Run: `git submodule update --init --recursive`
   - [ ] Build tkey-libs: `cd submodules/tkey-libs && make`

2. **Evaluate tkey-device-signer**
   - [ ] Review tkey-device-signer code (Ed25519 signing)
   - [ ] Understand signing protocol
   - [ ] Adapt for LUKS key derivation (sign challenge → derive key)
   - [ ] Decide: adapt tkey-device-signer or build custom device app

3. **Set Up Development Environment**
   - [ ] Run: `./scripts/setup-dev.sh`
   - [ ] Install dependencies
   - [ ] Verify toolchains (GCC, RISC-V)
   - [ ] Test basic builds

### Short Term (Next week)

4. **Implement Client Application**
   - [ ] TKey USB detection
   - [ ] Device app loading
   - [ ] Challenge-response protocol
   - [ ] Key derivation (PBKDF2/HKDF)
   - [ ] cryptsetup integration

5. **Implement/Adapt Device Application**
   - [ ] Decision on custom vs tkey-sign
   - [ ] USS-based signing
   - [ ] Communication protocol
   - [ ] Testing on TKey hardware

6. **Create initramfs Integration**
   - [ ] Hook script implementation
   - [ ] Boot script implementation
   - [ ] Configuration management
   - [ ] Error handling and fallback

### Medium Term (Next 2-3 weeks)

7. **Testing Infrastructure**
   - [ ] Create test VM
   - [ ] Test LUKS enrollment
   - [ ] Integration tests
   - [ ] Error scenario tests

8. **Documentation Completion**
   - [ ] Update docs based on implementation
   - [ ] Add API documentation
   - [ ] Create user guide
   - [ ] Troubleshooting guide

9. **Security Review**
   - [ ] Code audit
   - [ ] Protocol review
   - [ ] Key derivation validation
   - [ ] Threat model verification

---

## 📋 Implementation Checklist

### Phase 1: Environment Setup ✅
- [x] Project structure
- [x] Build system
- [x] Documentation
- [x] Test infrastructure

### Phase 2: Device Application (Current)
- [ ] Evaluate tkey-sign
- [ ] Implement or adapt device app
- [ ] Test on TKey hardware
- [ ] Document protocol

### Phase 3: Client Application
- [ ] USB communication
- [ ] Key derivation
- [ ] cryptsetup integration
- [ ] Static compilation
- [ ] Error handling

### Phase 4: initramfs Integration
- [ ] Hooks implementation
- [ ] Boot scripts
- [ ] Installation process
- [ ] Configuration

### Phase 5: Testing
- [ ] Unit tests
- [ ] Integration tests
- [ ] QEMU VM tests
- [ ] Security tests

### Phase 6: Documentation & Release
- [ ] Complete documentation
- [ ] Security audit
- [ ] User guide
- [ ] Release preparation

---

## 🎯 Project Goals

**Primary Goal:** Unlock LUKS encrypted root partition at boot using TKey

**Success Criteria:**
- TKey successfully unlocks LUKS partition
- Boot time impact < 5 seconds
- Statically compiled client < 5MB
- Works in initramfs
- Comprehensive tests passing
- Complete documentation
- Security review completed

---

## 🔧 Technical Decisions Needed

### Decision 1: Device App Strategy
**Options:**
- A) Use tkey-sign (faster, tested)
- B) Custom device app (tailored, minimal)
- C) Modified tkey-sign (middle ground)

**Action:** Evaluate tkey-sign first (Option A)

### Decision 2: Client Language
**Options:**
- A) C (current implementation)
- B) Go (recommended for TKey, standard in Tillitis ecosystem)

**Current:** C (Go is recommended for TKey clients)

### Decision 3: Key Derivation
**Options:**
- A) PBKDF2 (simpler, standard)
- B) HKDF (modern, flexible)
- C) Argon2 (memory-hard)

**Action:** Start with PBKDF2 (Option A)

### Decision 4: Initial Distribution Support
**Options:**
- A) Debian/Ubuntu only (initramfs-tools)
- B) Multi-distro (dracut support)

**Current:** Debian/Ubuntu first (Option A)

---

## 📚 Resources

### Repositories (Verify URLs)
- tkey-libs: https://github.com/tillitis/tkey-libs
- tkey-sign: Check Tillitis GitHub
- TKey documentation: https://dev.tillitis.se/

### Documentation
- LUKS: https://gitlab.com/cryptsetup/cryptsetup
- initramfs-tools: https://manpages.debian.org/initramfs-tools
- TKey protocol: https://dev.tillitis.se/protocol/

### Tools
- cryptsetup
- QEMU/KVM
- RISC-V toolchain
- TKey SDK

---

## 🚀 Getting Started (For New Contributors)

1. **Clone Repository:**
   ```bash
   git clone https://github.com/yourusername/tkey-luks.git
   cd tkey-luks
   ```

2. **Read Documentation:**
   - Start with: [PLAN.md](PLAN.md)
   - Setup: [docs/SETUP.md](docs/SETUP.md)
   - Security: [docs/SECURITY.md](docs/SECURITY.md)

3. **Set Up Environment:**
   ```bash
   ./scripts/setup-dev.sh
   ```

4. **Update Submodules:**
   ```bash
   # After verifying URLs in .gitmodules
   git submodule update --init --recursive
   ```

5. **Start Development:**
   - See current tasks in "Next Steps" above
   - Pick an area: client, device-app, or testing
   - Check TODOs in code files

---

## 📝 Notes

### Important Considerations
- TKey must be physically present during boot
- Static linking is critical for initramfs
- Security review needed before production
- Test thoroughly in VM before real system

### Known Issues
- Submodule URLs need verification
- Device app needs RISC-V toolchain
- Client needs TKey libraries
- Protocol not yet implemented

### Future Enhancements
- Multiple TKey support
- Key rotation mechanism
- Remote attestation
- TPM integration option
- Network unlock option

---

**Last Updated:** February 7, 2026  
**Next Review:** After Phase 2 completion
