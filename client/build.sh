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

# Verifying SHA-512 hash
printf "\nVerifying SHA-512 hash...\n"
if [ "$(sha512sum tkey-luks-client)" = "$(cat tkey-luks-client.sha512)" ]; then
    printf "✓ SHA-512 hash verified\n"
else
    printf "✗ SHA-512 verification failed\n"
    exit 1
fi