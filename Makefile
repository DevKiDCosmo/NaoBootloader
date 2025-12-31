# Makefile for NaoBootloader
# Builds the bootloader and kernel binaries

AS = nasm
ASFLAGS = -f bin

.PHONY: all clean example-binaries

all: example-binaries

example-binaries: bootloader.bin kernel.bin

bootloader.bin: bootloader.asm
	@echo "Building bootloader..."
	@if command -v $(AS) >/dev/null 2>&1; then \
		$(AS) $(ASFLAGS) -o $@ $<; \
		echo "Bootloader built successfully"; \
	else \
		echo "Warning: nasm not found, creating dummy bootloader binary"; \
		dd if=/dev/zero of=$@ bs=512 count=1 2>/dev/null; \
		echo "Dummy bootloader created"; \
	fi

kernel.bin: kernel.asm
	@echo "Building kernel..."
	@if command -v $(AS) >/dev/null 2>&1; then \
		$(AS) $(ASFLAGS) -o $@ $<; \
		echo "Kernel built successfully"; \
	else \
		echo "Warning: nasm not found, creating dummy kernel binary"; \
		dd if=/dev/zero of=$@ bs=1024 count=10 2>/dev/null; \
		echo "Dummy kernel created"; \
	fi

clean:
	@echo "Cleaning build artifacts..."
	@rm -f bootloader.bin kernel.bin
	@echo "Clean complete"
