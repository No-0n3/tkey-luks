#!/bin/bash
# Quick start script - sets up everything for first time use

set -e

echo "=========================================="
echo "  TKey-LUKS Quick Start"
echo "=========================================="
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Check if we're in the right directory
if [ ! -f "PLAN.md" ]; then
    echo "ERROR: Run this script from the project root"
    exit 1
fi

echo "Project root: $PROJECT_ROOT"
echo ""

# Step 1: Read the plan
echo "[Step 1/5] Project Overview"
echo "─────────────────────────────────────────"
echo ""
echo "This project creates a boot-time LUKS unlock system using TKey."
echo ""
echo "Key documents to read:"
echo "  • PLAN.md          - Complete implementation plan"
echo "  • README.md        - Project overview"
echo "  • docs/SETUP.md    - Setup instructions"
echo "  • STATUS.md        - Current project status"
echo ""
read -p "Press Enter to continue..."
echo ""

# Step 2: Check dependencies
echo "[Step 2/5] Checking Dependencies"
echo "─────────────────────────────────────────"
echo ""

MISSING_DEPS=0

# Check essential tools
for cmd in gcc make git cryptsetup; do
    if command -v $cmd &> /dev/null; then
        echo "✓ $cmd found"
    else
        echo "✗ $cmd not found"
        MISSING_DEPS=1
    fi
done

# Check optional tools
echo ""
echo "Optional tools:"
for cmd in cargo qemu-system-x86_64 riscv32-unknown-elf-gcc; do
    if command -v $cmd &> /dev/null; then
        echo "✓ $cmd found"
    else
        echo "○ $cmd not found (optional)"
    fi
done

echo ""
if [ $MISSING_DEPS -eq 1 ]; then
    echo "⚠ Missing required dependencies"
    echo ""
    read -p "Run setup-dev.sh to install dependencies? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./scripts/setup-dev.sh
    else
        echo "Please install missing dependencies and try again"
        exit 1
    fi
else
    echo "✓ All required dependencies found"
fi
echo ""
read -p "Press Enter to continue..."
echo ""

# Step 3: Initialize submodules
echo "[Step 3/5] Git Submodules"
echo "─────────────────────────────────────────"
echo ""
echo "⚠ IMPORTANT: Submodule URLs need verification"
echo ""
echo "The .gitmodules file contains placeholder URLs."
echo "Before proceeding, you need to:"
echo ""
echo "1. Find correct Tillitis repository URLs"
echo "   Visit: https://github.com/tillitis"
echo ""
echo "2. Update .gitmodules with correct URLs"
echo ""
echo "3. Initialize submodules:"
echo "   git submodule update --init --recursive"
echo ""
read -p "Have you updated .gitmodules with correct URLs? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Initializing submodules..."
    git submodule update --init --recursive || {
        echo ""
        echo "⚠ Submodule initialization failed"
        echo "This is expected if URLs are not yet correct"
    }
else
    echo ""
    echo "Skipping submodule initialization for now"
    echo "You can do this later with:"
    echo "  git submodule update --init --recursive"
fi
echo ""
read -p "Press Enter to continue..."
echo ""

# Step 4: Explore the codebase
echo "[Step 4/5] Project Structure"
echo "─────────────────────────────────────────"
echo ""
echo "Key directories:"
echo ""
echo "  client/          - Client application (runs in initramfs)"
echo "  device-app/      - Device application (runs on TKey)"
echo "  initramfs-hooks/ - Boot integration"
echo "  test/            - Testing infrastructure"
echo "  docs/            - Documentation"
echo "  scripts/         - Build and installation scripts"
echo ""
echo "Current implementation status:"
echo "  • Project structure: ✓ Complete"
echo "  • Documentation:     ✓ Complete"
echo "  • Build system:      ✓ Complete (skeletons)"
echo "  • Client code:       ○ TODO (skeleton only)"
echo "  • Device app:        ○ TODO (skeleton only)"
echo "  • Testing:           ○ TODO"
echo ""
read -p "Press Enter to continue..."
echo ""

# Step 5: Next steps
echo "[Step 5/5] Next Steps"
echo "─────────────────────────────────────────"
echo ""
echo "What to do next:"
echo ""
echo "1. Review the detailed plan:"
echo "   less PLAN.md"
echo ""
echo "2. Review current status:"
echo "   less STATUS.md"
echo ""
echo "3. Update .gitmodules with correct Tillitis repos"
echo "   vim .gitmodules"
echo ""
echo "4. Initialize submodules:"
echo "   git submodule update --init --recursive"
echo ""
echo "5. Choose development path:"
echo "   a) Implement client (client/src/main.c)"
echo "   b) Adapt tkey-sign for device app"
echo "   c) Create test environment (test/qemu/create-vm.sh)"
echo ""
echo "6. Build when ready:"
echo "   ./scripts/build-all.sh"
echo ""
echo "7. Test in VM:"
echo "   ./test/qemu/create-vm.sh"
echo "   ./test/qemu/run-vm.sh"
echo ""
echo "For detailed instructions, see:"
echo "  • docs/SETUP.md for setup"
echo "  • docs/TESTING.md for testing"
echo "  • docs/SECURITY.md for security considerations"
echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "The project structure is ready for development."
echo "Start by reading PLAN.md and STATUS.md."
echo ""
