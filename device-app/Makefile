# TKey-LUKS Device Application Makefile

# This builds the device application that runs on TKey hardware
# The output is a binary that gets loaded onto the TKey

# Compiler for TKey (RISC-V 32-bit)
# Using LLVM/Clang to match official Tillitis build system
CC = clang
OBJCOPY = llvm-objcopy

# Flags for TKey target (matching tkey-libs build)
CFLAGS = -target riscv32-unknown-none-elf
CFLAGS += -march=rv32iczmmul -mabi=ilp32 -mcmodel=medany
CFLAGS += -static -std=gnu99 -O2 -ffast-math
CFLAGS += -fno-common -fno-builtin-printf -fno-builtin-putchar
CFLAGS += -nostdlib -mno-relax -flto
CFLAGS += -Wall -Werror=implicit-function-declaration

# Linker flags
LDFLAGS = -T ../submodules/tkey-libs/app.ld
LDFLAGS += -nostdlib -mno-relax
LDFLAGS += -fuse-ld=lld-20

# Target binary
TARGET = tkey-luks-device
ELF = $(TARGET).elf
BIN = $(TARGET).bin

# Source files
SRCS = src/main.c
# TODO: Add TKey SDK sources when submodules are set up
# SRCS += ../submodules/tkey-libs/app_start.S
# SRCS += ../submodules/tkey-libs/blake2s.c

OBJS = $(SRCS:.c=.o)
OBJS := $(OBJS:.S=.o)

# Include paths
INCLUDES = -I../submodules/tkey-libs/include

# Default target
all: check-toolchain $(BIN)

# Check if LLVM/Clang toolchain is available
check-toolchain:
	@which $(CC) > /dev/null 2>&1 || { \
		echo "ERROR: Clang not found"; \
		echo ""; \
		echo "The TKey device app requires LLVM/Clang 15+ with RISC-V support."; \
		echo ""; \
		echo "Install options:"; \
		echo "  Ubuntu/Debian: apt-get install clang lld llvm"; \
		echo "  Fedora: dnf install clang lld llvm"; \
		echo "  Arch: pacman -S clang lld llvm"; \
		echo ""; \
		echo "Verify RISC-V support: clang --print-targets | grep riscv"; \
		echo ""; \
		echo "Alternative: Use existing tkey-device-signer app"; \
		echo "  See: https://github.com/tillitis/tkey-device-signer"; \
		exit 1; \
	}
	@which lld-20 > /dev/null 2>&1 || which lld > /dev/null 2>&1 || { \
		echo "ERROR: LLD linker not found"; \
		echo "Install: apt-get install lld or lld-20"; \
		exit 1; \
	}

# Build ELF executable
$(ELF): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

# Convert ELF to raw binary for TKey
$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@
	@echo ""
	@echo "Built: $(BIN)"
	@ls -lh $(BIN)
	@echo ""
	@echo "Device app ready for TKey"

# Compile C sources
%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Compile assembly sources  
%.o: %.S
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Clean build artifacts
clean:
	rm -f $(OBJS) $(ELF) $(BIN)
	@echo "Cleaned build artifacts"

# Install to system
install: $(BIN)
	install -D -m 644 $(BIN) /usr/lib/tkey-luks/$(BIN)
	@echo "Installed to /usr/lib/tkey-luks/$(BIN)"

# Show build configuration
config:
	@echo "Device app build configuration:"
	@echo "  CC: $(CC)"
	@echo "  CFLAGS: $(CFLAGS)"
	@echo "  LDFLAGS: $(LDFLAGS)"
	@echo "  TARGET: $(TARGET)"
	@echo "  Output: $(BIN)"

.PHONY: all clean install config check-toolchain

# Development notes:
#
# TODO: Set up proper TKey SDK integration
# TODO: Add actual cryptographic operations
# TODO: Test on real TKey hardware
# TODO: Optimize for size (TKey has limited flash)
#
# Alternative approach:
# Instead of building custom device app, consider using tkey-sign:
#   1. Clone tkey-sign as submodule
#   2. Build tkey-sign  
#   3. Use its signing capabilities for key derivation
#   4. This might be simpler and more secure
#
# To test on TKey hardware:
#   tkey-runapp $(BIN)
