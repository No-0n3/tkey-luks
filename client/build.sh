#!/bin/sh
# SPDX-FileCopyrightText: 2026 TKey-LUKS Project
# SPDX-License-Identifier: BSD-2-Clause

set -eu

printf "Building tkey-luks client\n"
printf "========================\n\n"

# Get Go dependencies
printf "Downloading dependencies...\n"
go mod download
go mod verify

# Build client
printf "\nBuilding client binary...\n"
go build -o tkey-luks-client main.go

# Generate SHA-512 hash
printf "\nGenerating SHA-512 hash...\n"
sha512sum tkey-luks-client > tkey-luks-client.sha512

printf "\n✓ Build complete\n"
printf "Binary: tkey-luks-client\n"
printf "Hash:   tkey-luks-client.sha512\n"
ls -lh tkey-luks-client
cat tkey-luks-client.sha512
