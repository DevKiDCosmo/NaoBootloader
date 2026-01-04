#!/bin/bash

# Test two-stage bootloader with QEMU

BOOTLOADER_BIN="./bootloader.bin"
STAGE2_BIN="./stage2.bin"
# Allow overriding the payload (e.g., ./scripts/test_qemu.sh ./osshell.bin)
KERNEL_BIN="${1:-./kernel.bin}"
DISK_IMAGE="./boot_disk.img"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== QEMU Two-Stage Bootloader Test ===${NC}"

# Validate payload presence before proceeding
if [ ! -f "$KERNEL_BIN" ]; then
    echo -e "${RED}Payload not found:${NC} $KERNEL_BIN"
    echo -e "${YELLOW}Usage:${NC} ./scripts/test_qemu.sh [path/to/payload.bin]"
    exit 1
fi

# Build binaries
echo -e "${GREEN}Building binaries...${NC}"
make clean
make

# Create disk image (10MB)
echo -e "${GREEN}Creating bootable disk image with MBR...${NC}"
dd if=/dev/zero of="$DISK_IMAGE" bs=1M count=10 2>/dev/null

# Create MBR partition table
echo -e "${GREEN}Creating MBR partition table...${NC}"
cat > /tmp/fdisk_commands.txt << EOF
o
n
p
1

+9M
a
w
EOF

# Apply partition table (using fdisk if available, otherwise continue)
if command -v fdisk >/dev/null 2>&1; then
    fdisk "$DISK_IMAGE" < /tmp/fdisk_commands.txt >/dev/null 2>&1 || true
    echo -e "${GREEN}Partition table created${NC}"
else
    echo -e "${YELLOW}fdisk not available, creating raw bootable disk${NC}"
fi
rm -f /tmp/fdisk_commands.txt

# Write bootloader to MBR (sector 0)
echo -e "${GREEN}Writing stage 1 bootloader to MBR (sector 0)...${NC}"
dd if="$BOOTLOADER_BIN" of="$DISK_IMAGE" bs=446 count=1 conv=notrunc 2>/dev/null

# Preserve boot signature at bytes 510-511
echo -e "${GREEN}Writing boot signature (0x55AA)...${NC}"
printf '\x55\xAA' | dd of="$DISK_IMAGE" bs=1 seek=510 count=2 conv=notrunc 2>/dev/null

# Write stage 2 loader to sectors 2-3
echo -e "${GREEN}Writing stage 2 loader to sectors 2-3...${NC}"
dd if="$STAGE2_BIN" of="$DISK_IMAGE" bs=512 seek=2 conv=notrunc 2>/dev/null

# Write kernel/payload starting at sector 4
echo -e "${GREEN}Writing payload starting at sector 4...${NC}"
dd if="$KERNEL_BIN" of="$DISK_IMAGE" bs=512 seek=4 conv=notrunc 2>/dev/null

echo -e "${GREEN}Disk image created successfully${NC}"
echo -e "${YELLOW}Starting QEMU...${NC}"
echo -e "${YELLOW}You should see the colored debug messages in the QEMU window${NC}"
echo ""

# Run QEMU with legacy BIOS boot
qemu-system-x86_64 \
    -drive file="$DISK_IMAGE",format=raw,if=ide \
    -m 128M \
    -boot c \
    -no-reboot \
    -no-shutdown

echo -e "${GREEN}QEMU exited${NC}"
