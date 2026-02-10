#!/bin/bash
# Verify Salt Availability for USS Derivation
# This script checks if the salt used for USS derivation will be available in initramfs

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}    TKey-LUKS USS Salt Availability Verification        ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check current system salt
echo -e "${YELLOW}[1/3] Checking salt on current system...${NC}"
echo ""

SALT_SOURCE=""
SALT_VALUE=""

if [ -f /etc/machine-id ]; then
    SALT_VALUE=$(cat /etc/machine-id)
    SALT_SOURCE="/etc/machine-id"
    echo -e "${GREEN}✓ Found machine-id${NC}"
    echo -e "  Source: ${CYAN}$SALT_SOURCE${NC}"
    echo -e "  Value:  ${CYAN}$SALT_VALUE${NC}"
elif [ -f /var/lib/dbus/machine-id ]; then
    SALT_VALUE=$(cat /var/lib/dbus/machine-id)
    SALT_SOURCE="/var/lib/dbus/machine-id"
    echo -e "${GREEN}✓ Found dbus machine-id${NC}"
    echo -e "  Source: ${CYAN}$SALT_SOURCE${NC}"
    echo -e "  Value:  ${CYAN}$SALT_VALUE${NC}"
elif [ -f /sys/class/dmi/id/product_uuid ]; then
    SALT_VALUE=$(cat /sys/class/dmi/id/product_uuid)
    SALT_SOURCE="/sys/class/dmi/id/product_uuid"
    echo -e "${YELLOW}⚠ Using DMI product UUID${NC}"
    echo -e "  Source: ${CYAN}$SALT_SOURCE${NC}"
    echo -e "  Value:  ${CYAN}$SALT_VALUE${NC}"
    echo -e "${YELLOW}  Note: DMI may not be available in all initramfs environments${NC}"
else
    SALT_VALUE=$(hostname)
    SALT_SOURCE="hostname"
    echo -e "${RED}⚠ No proper salt found, falling back to hostname${NC}"
    echo -e "  Source: ${CYAN}$SALT_SOURCE${NC}"
    echo -e "  Value:  ${CYAN}$SALT_VALUE${NC}"
    echo -e "${RED}  WARNING: Hostname is not a secure salt!${NC}"
fi
echo ""

# Check if salt will be in initramfs
echo -e "${YELLOW}[2/3] Checking if salt will be available in initramfs...${NC}"
echo ""

KERNEL_VERSION=$(uname -r)
INITRAMFS="/boot/initrd.img-$KERNEL_VERSION"

if [ ! -f "$INITRAMFS" ]; then
    echo -e "${RED}✗ Initramfs not found: $INITRAMFS${NC}"
    echo -e "${YELLOW}  Cannot verify initramfs contents${NC}"
    exit 1
fi

echo -e "  Kernel version: ${CYAN}$KERNEL_VERSION${NC}"
echo -e "  Initramfs file: ${CYAN}$INITRAMFS${NC}"
echo ""

# Extract and check initramfs
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "  Extracting initramfs (this may take a moment)..."
sudo unmkinitramfs "$INITRAMFS" "$TEMP_DIR" 2>/dev/null || {
    echo -e "${RED}✗ Failed to extract initramfs${NC}"
    exit 1
}

# Check for machine-id in initramfs
if [ -f "$TEMP_DIR/main/etc/machine-id" ]; then
    INITRAMFS_SALT=$(cat "$TEMP_DIR/main/etc/machine-id")
    echo -e "${GREEN}✓ machine-id found in initramfs!${NC}"
    echo -e "  Value: ${CYAN}$INITRAMFS_SALT${NC}"
    echo ""
    
    # Verify they match
    if [ "$SALT_VALUE" = "$INITRAMFS_SALT" ]; then
        echo -e "${GREEN}✓ Salt values MATCH!${NC}"
        echo -e "  System salt and initramfs salt are identical"
        echo ""
    else
        echo -e "${RED}✗ WARNING: Salt values DO NOT MATCH!${NC}"
        echo -e "  System:    ${CYAN}$SALT_VALUE${NC}"
        echo -e "  Initramfs: ${CYAN}$INITRAMFS_SALT${NC}"
        echo -e ""
        echo -e "${YELLOW}  This will cause USS derivation to fail during boot!${NC}"
        echo -e "${YELLOW}  Re-add LUKS keys after fixing the initramfs.${NC}"
        echo ""
        exit 1
    fi
else
    echo -e "${RED}✗ machine-id NOT found in initramfs!${NC}"
    echo ""
    echo -e "${YELLOW}This means:${NC}"
    echo "  • USS derivation will use a different salt during boot"
    echo "  • TKey unlock will FAIL with wrong USS"
    echo "  • You must rebuild initramfs with the updated hooks"
    echo ""
    echo -e "${CYAN}To fix:${NC}"
    echo "  1. Update initramfs hooks:"
    echo "     cd ../initramfs-hooks"
    echo "     sudo cp hooks/tkey-luks /etc/initramfs-tools/hooks/"
    echo "  2. Rebuild initramfs:"
    echo "     sudo update-initramfs -u -k all"
    echo "  3. Verify the fix:"
    echo "     bash verify-salt-availability.sh"
    echo "  4. Re-add LUKS keys:"
    echo "     cd luks-setup"
    echo "     ./add-tkey-key.sh test-luks-100mb.img test123"
    echo ""
    exit 1
fi

# Summary
echo -e "${YELLOW}[3/3] Verification Summary${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ System Configuration Valid${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Salt Source:  $SALT_SOURCE"
echo "Salt Value:   $SALT_VALUE"
echo ""
echo -e "${GREEN}✓ Initramfs includes correct salt${NC}"
echo -e "${GREEN}✓ USS derivation will be consistent between setup and boot${NC}"
echo ""
echo -e "${CYAN}You can now:${NC}"
echo "  • Add LUKS keys with --derive-uss"
echo "  • Keys will unlock successfully during boot"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
