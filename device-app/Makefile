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
CFLAGS += -static -std=gnu99 -O2 -ffast-math -ffreestanding
CFLAGS += -fno-common -fno-builtin-printf -fno-builtin-putchar
CFLAGS += -nostdlib -mno-relax -flto
CFLAGS += -Wall -Werror=implicit-function-declaration
# Disable QEMU debug output for real TKey hardware
# CFLAGS += -DQEMU_DEBUG

# Library paths
LIBDIR = ../submodules/tkey-libs

# Linker flags (matching tkey-device-signer)
LDFLAGS = -T $(LIBDIR)/app.lds
LDFLAGS += -L $(LIBDIR)
LDFLAGS += -lcommon -lcrt0
LDFLAGS += -nostdlib -mno-relax
LDFLAGS += -fuse-ld=lld

# Target binary
TARGET = tkey-luks-device
ELF = $(TARGET).elf
BIN = $(TARGET).bin

# Required tkey-libs version
TKEY_LIBS_VERSION = v0.1.2

# Source files
SRCS = src/main.c src/app_proto.c

OBJS = $(SRCS:.c=.o)

# Include paths
INCLUDES = -I$(LIBDIR)/include -I$(LIBDIR)

# Default target
all: check-toolchain check-libs $(BIN)

# Generate compile_commands.json for clangd/IDE support
# Generates in workspace root with absolute paths for IDE extensions
compile_commands.json: check-libs
	@echo "Generating compile_commands.json in workspace root..."
	@echo '[' > ../$@
	@first=true; \
	for src in $(SRCS); do \
		if [ "$$first" = true ]; then \
			first=false; \
		else \
			echo ',' >> ../$@; \
		fi; \
		obj=$${src%.c}.o; \
		abs_src="$(shell pwd)/$$src"; \
		abs_obj="$(shell pwd)/$$obj"; \
		echo '  {' >> ../$@; \
		echo "    \"directory\": \"$(shell pwd)\"," >> ../$@; \
		echo "    \"command\": \"$(CC) $(CFLAGS) $(INCLUDES) -c $$abs_src -o $$abs_obj\"," >> ../$@; \
		echo "    \"file\": \"$$abs_src\"" >> ../$@; \
		echo -n '  }' >> ../$@; \
	done
	@echo '' >> ../$@
	@echo ']' >> ../$@
	@echo "Generated ../$@ with absolute paths"

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
	@which lld > /dev/null 2>&1 || { \
		echo "ERROR: LLD linker not found"; \
		echo "Install: apt-get install lld"; \
		exit 1; \
	}

# Check if tkey-libs exists and is at correct version
check-libs:
	@if [ ! -d "$(LIBDIR)" ]; then \
		echo "ERROR: tkey-libs not found at $(LIBDIR)"; \
		echo ""; \
		echo "Initialize git submodules:"; \
		echo "  cd .. && git submodule update --init"; \
		exit 1; \
	fi
	@if [ ! -f "$(LIBDIR)/libcommon.a" ]; then \
		echo "Building tkey-libs $(TKEY_LIBS_VERSION)..."; \
		$(MAKE) -C $(LIBDIR); \
	fi

# Build tkey-libs if needed
build-libs:
	@echo "Building tkey-libs $(TKEY_LIBS_VERSION)..."
	$(MAKE) -C $(LIBDIR)

# Build ELF executable
$(ELF): $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) $(LDFLAGS) -L $(LIBDIR) -lmonocypher -o $@

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

# Deep clean including tkey-libs
clean-all: clean
	@if [ -d "$(LIBDIR)" ]; then \
		echo "Cleaning tkey-libs..."; \
		$(MAKE) -C $(LIBDIR) clean; \
	fi

# Install to system
install: $(BIN)
	install -D -m 644 $(BIN) /usr/local/lib/tkey-luks/$(BIN)
	@echo "Installed to /usr/local/lib/tkey-luks/$(BIN)"

# Show build configuration
config:
	@echo "Device app build configuration:"
	@echo "  CC: $(CC)"
	@echo "  CFLAGS: $(CFLAGS)"
	@echo "  LDFLAGS: $(LDFLAGS)"
	@echo "  tkey-libs: $(LIBDIR) ($(TKEY_LIBS_VERSION))"
	@echo "  TARGET: $(TARGET)"
	@echo "  Output: $(BIN)"

.PHONY: all check-toolchain check-libs build-libs clean clean-all install config compile_commands.json
