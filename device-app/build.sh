#!/bin/sh
# SPDX-FileCopyrightText: 2026 TKey-LUKS Project
# SPDX-License-Identifier: BSD-2-Clause

set -eu

tkey_libs_version="v0.1.2"

printf "Building tkey-luks device app\n"
printf "tkey-libs version: %s\n\n" "$tkey_libs_version"

# Check if tkey-libs exists and is at correct version
if [ -d ../submodules/tkey-libs ]; then
    cd ../submodules/tkey-libs
    current_version=$(git describe --tags 2>/dev/null || echo "unknown")
    
    if [ "$current_version" != "$tkey_libs_version" ]; then
        printf "Checking out tkey-libs %s (current: %s)\n" "$tkey_libs_version" "$current_version"
        git fetch --tags 2>/dev/null || true
        git checkout "$tkey_libs_version"
    else
        printf "tkey-libs already at %s\n" "$tkey_libs_version"
    fi
    
    cd ../../device-app
else
    printf "ERROR: tkey-libs not found at ../submodules/tkey-libs\n"
    printf "\nInitialize git submodules:\n"
    printf "  cd .. && git submodule update --init\n"
    exit 1
fi

# Build tkey-libs
printf "\nBuilding tkey-libs...\n"
make -j -C ../submodules/tkey-libs

# Build device app
printf "\nBuilding device app...\n"
make -j

if [ -f "tkey-luks-device.bin" ]; then
    printf "\n✓ Device app built successfully: ./tkey-luks-device.bin\n"
else
    printf "\n✗ Device app build failed\n"
    exit 1