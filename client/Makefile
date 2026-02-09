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

# Build flags for static linking and reduced size
LDFLAGS = -ldflags="-s -w -extldflags '-static'"

# Default target - build binary
all: $(BINARY)

# Build the Go binary
$(BINARY): main.go go.mod
	$(GOBUILD) $(LDFLAGS) -o $(BINARY)
	@echo ""
	@echo "Built: $(BINARY)"
	@ls -lh $(BINARY)


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

.PHONY: all clean deps test install debug config
