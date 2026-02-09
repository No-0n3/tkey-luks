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
printf "\nBuilding client binary (static)...\n"
CGO_ENABLED=0 go build -ldflags="-s -w -extldflags '-static'" -o tkey-luks-client main.go
printf "\n✓ Client built successfully: ./tkey-luks-client\n"