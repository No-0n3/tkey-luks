# TKey-LUKS Initramfs Hooks Makefile
# Install hooks and scripts for Ubuntu 24.04 initramfs-tools

HOOK_NAME = tkey-luks
HOOK_SRC = hooks/$(HOOK_NAME)
HOOK_DEST = /etc/initramfs-tools/hooks/$(HOOK_NAME)

SCRIPT_NAME = tkey-luks
SCRIPT_SRC = scripts/local-top/$(SCRIPT_NAME)
SCRIPT_DEST = /etc/initramfs-tools/scripts/local-top/$(SCRIPT_NAME)

.PHONY: all install uninstall update-initramfs check test clean

all:
	@echo "TKey-LUKS Initramfs Hooks"
	@echo ""
	@echo "Available targets:"
	@echo "  install          - Install hooks and scripts to system"
	@echo "  update-initramfs - Rebuild initramfs with TKey-LUKS"
	@echo "  uninstall        - Remove hooks and scripts from system"
	@echo "  check            - Verify installation"
	@echo "  test             - Test in VM (requires VM to be set up)"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Client and device-app must be built and installed"
	@echo "  - Run 'make install' in client/ and device-app/ first"

install:
	@echo "Installing TKey-LUKS initramfs hooks..."
	@# Check prerequisites
	@if [ ! -f /usr/local/bin/tkey-luks-client ]; then \
		echo "ERROR: tkey-luks-client not installed"; \
		echo "Run 'make install' in client/ directory first"; \
		exit 1; \
	fi
	@if [ ! -f /usr/local/lib/tkey-luks/tkey-luks-device.bin ]; then \
		echo "ERROR: tkey-luks-device.bin not installed"; \
		echo "Run 'make install' in device-app/ directory first"; \
		exit 1; \
	fi
	@# Install hook
	install -D -m 755 $(HOOK_SRC) $(HOOK_DEST)
	@echo "  ✓ Installed hook: $(HOOK_DEST)"
	@# Install script
	install -D -m 755 $(SCRIPT_SRC) $(SCRIPT_DEST)
	@echo "  ✓ Installed script: $(SCRIPT_DEST)"
	@echo ""
	@echo "Installation complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Review /etc/crypttab and /etc/fstab"
	@echo "  2. Run 'sudo make update-initramfs' to rebuild initramfs"
	@echo "  3. Reboot and test (or use test VM)"

uninstall:
	@echo "Removing TKey-LUKS initramfs hooks..."
	rm -f $(HOOK_DEST)
	@echo "  ✓ Removed hook"
	rm -f $(SCRIPT_DEST)
	@echo "  ✓ Removed script"
	@echo ""
	@echo "Run 'sudo update-initramfs -u' to rebuild initramfs without TKey-LUKS"

update-initramfs:
	@echo "Rebuilding initramfs with TKey-LUKS..."
	@# Verify hooks are installed
	@if [ ! -f $(HOOK_DEST) ]; then \
		echo "ERROR: Hooks not installed. Run 'sudo make install' first"; \
		exit 1; \
	fi
	@# Update initramfs for all kernels
	update-initramfs -u -k all
	@echo ""
	@echo "✓ Initramfs updated successfully"
	@echo ""
	@echo "Initramfs now includes:"
	@lsinitramfs /boot/initrd.img-$$(uname -r) | grep -E "(tkey-luks|cdc-acm)" || echo "  (verification failed)"

check:
	@echo "Checking TKey-LUKS initramfs installation..."
	@echo ""
	@echo "[1/5] Checking prerequisites..."
	@if [ -f /usr/local/bin/tkey-luks-client ]; then \
		echo "  ✓ Client installed"; \
	else \
		echo "  ✗ Client NOT installed"; \
	fi
	@if [ -f /usr/local/lib/tkey-luks/tkey-luks-device.bin ]; then \
		echo "  ✓ Device app installed"; \
	else \
		echo "  ✗ Device app NOT installed"; \
	fi
	@echo ""
	@echo "[2/5] Checking hook installation..."
	@if [ -f $(HOOK_DEST) ]; then \
		echo "  ✓ Hook installed: $(HOOK_DEST)"; \
	else \
		echo "  ✗ Hook NOT installed"; \
	fi
	@echo ""
	@echo "[3/5] Checking script installation..."
	@if [ -f $(SCRIPT_DEST) ]; then \
		echo "  ✓ Script installed: $(SCRIPT_DEST)"; \
	else \
		echo "  ✗ Script NOT installed"; \
	fi
	@echo ""
	@echo "[4/5] Checking initramfs contents..."
	@if lsinitramfs /boot/initrd.img-$$(uname -r) | grep -q tkey-luks-client; then \
		echo "  ✓ TKey client in initramfs"; \
	else \
		echo "  ✗ TKey client NOT in initramfs (run 'make update-initramfs')"; \
	fi
	@echo ""
	@echo "[5/5] Checking TKey device..."
	@if [ -e /dev/ttyACM0 ]; then \
		echo "  ✓ TKey device present: /dev/ttyACM0"; \
	else \
		echo "  ⚠ TKey device not detected (plug in TKey)"; \
	fi

test:
	@echo "Testing TKey-LUKS in VM..."
	@cd ../test/qemu && ./run-vm.sh --tkey-device /dev/ttyACM0

clean:
	@echo "Nothing to clean (hooks are source files)"

