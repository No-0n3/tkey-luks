# TKey-LUKS Client Makefile

CC = gcc
CFLAGS = -Wall -Wextra -O2 -std=c11
LDFLAGS = 
TARGET = tkey-luks-unlock

# For static linking (required for initramfs)
STATIC = -static

# Source files
SRCS = src/main.c
OBJS = $(SRCS:.c=.o)

# Include paths (update when tkey-libs submodule is added)
INCLUDES = -I../submodules/tkey-libs/include

# Libraries (update when dependencies are clear)
LIBS = -lusb-1.0 -lcryptsetup

# Default target
all: $(TARGET)

# Build statically linked binary
$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $(STATIC) -o $@ $^ $(LIBS)
	@echo ""
	@echo "Built: $(TARGET)"
	@ls -lh $(TARGET)
	@echo ""
	@echo "Checking binary:"
	@file $(TARGET)
	@echo ""
	@echo "Dependencies:"
	@ldd $(TARGET) 2>&1 || echo "✓ Statically linked"

# Compile source files
%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Clean build artifacts
clean:
	rm -f $(OBJS) $(TARGET)
	@echo "Cleaned build artifacts"

# Install to system (requires root)
install: $(TARGET)
	install -D -m 755 $(TARGET) /usr/lib/tkey-luks/$(TARGET)
	@echo "Installed to /usr/lib/tkey-luks/$(TARGET)"

# Development build (with debug symbols)
debug: CFLAGS += -g -DDEBUG
debug: clean $(TARGET)

# Test target
test: $(TARGET)
	@echo "Running basic tests..."
	./$(TARGET) --help
	@echo "✓ Help output works"

# Show configuration
config:
	@echo "Build configuration:"
	@echo "  CC: $(CC)"
	@echo "  CFLAGS: $(CFLAGS)"
	@echo "  LDFLAGS: $(LDFLAGS)"
	@echo "  INCLUDES: $(INCLUDES)"
	@echo "  LIBS: $(LIBS)"
	@echo "  TARGET: $(TARGET)"

.PHONY: all clean install debug test config

# Notes for future development:
# 
# TODO: Add actual TKey library dependencies
# TODO: Add cryptsetup library integration  
# TODO: Implement static linking with musl-libc for smaller binary
# TODO: Add tests for each component
# TODO: Add cross-compilation support
#
# For musl-libc static build:
#   CC=musl-gcc make
#
# For minimal size:
#   CFLAGS="-Os -s" make
