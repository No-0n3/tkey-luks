# TKey-LUKS Client Makefile
# Go implementation - uses build.sh for full build with dependency management

# Go build settings
GOCMD = go
GOBUILD = CGO_ENABLED=0 $(GOCMD) build
GOCLEAN = $(GOCMD) clean
GOTEST = $(GOCMD) test
GOMOD = $(GOCMD) mod

# Binary names
BINARY = tkey-luks-client
HASH = $(BINARY).sha512

# Build flags for static linking and reduced size
LDFLAGS = -ldflags="-s -w -extldflags '-static'"

# Default target - build binary and optionally verify hash
all: $(BINARY) verify-hash

# Build the Go binary
$(BINARY): main.go go.mod
	$(GOBUILD) $(LDFLAGS) -o $(BINARY)
	@echo ""
	@echo "Built: $(BINARY)"
	@ls -lh $(BINARY)

# Verify binary integrity against existing hash
verify-hash:
	@if [ "$(VERIFY_HASH)" != "1" ]; then \
		echo "Skipping hash verification (set VERIFY_HASH=1 to enable)."; \
	elif [ ! -f "$(HASH)" ]; then \
		echo "Warning: Hash file $(HASH) not found. Skipping verification."; \
	else \
		echo "Verifying $(BINARY) against existing hash..."; \
		sha512sum -c $(HASH) && echo "✓ Binary verified" || (echo "✗ Verification failed - binary differs from expected hash" && exit 1); \
	fi

# Generate new SHA-512 hash (use this to update the hash file)
generate-hash: $(BINARY)
	@echo "Generating SHA-512 hash..."
	@sha512sum $(BINARY) > $(HASH)
	@echo "Hash file: $(HASH)"

# Verify binary integrity against hash (alias for verify-hash)
verify: VERIFY_HASH=1
verify: verify-hash
	@echo "Verifying $(BINARY) integrity..."
	@sha512sum -c $(HASH) && echo "✓ Binary verified" || (echo "✗ Verification failed" && exit 1)

# Clean build artifacts
clean:
	$(GOCLEAN)
	rm -f $(BINARY)
	@echo "Cleaned build artifacts"

# Download and verify dependencies
deps:
	$(GOMOD) download
	$(GOMOD) verify
	@echo "✓ Dependencies downloaded and verified"

# Run tests
test:
	$(GOTEST) -v ./...

# Install to system (requires selecting appropriate location)
install: $(BINARY)
	install -D -m 755 $(BINARY) /usr/local/bin/$(BINARY)
	@echo "Installed to /usr/local/bin/$(BINARY)"

# Development build (with debug info)
debug: LDFLAGS = -ldflags="-w"
debug: clean all

# Show build configuration
config:
	@echo "Build configuration:"
	@echo "  Go: $(shell go version)"
	@echo "  GOCMD: $(GOCMD)"
	@echo "  LDFLAGS: $(LDFLAGS)"
	@echo "  Binary: $(BINARY)"
	@echo ""
	@echo "Dependencies:"
	@$(GOMOD) graph | head -20

.PHONY: all verify verify-hash generate-hash clean deps test install debug config
