#!/bin/bash

# test_slow.sh - Slow QEMU testing for debugging bootloader
# Run QEMU at reduced CPU speed to observe debug messages clearly

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Configuration
BOOTLOADER_BIN="${SCRIPT_DIR}/../bootloader.bin"
STAGE2_BIN="${SCRIPT_DIR}/../stage2.bin"
KERNEL_BIN="${SCRIPT_DIR}/../kernel.bin"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "================================================================================"
echo "  QEMU Slow-Motion Bootloader Test"
echo "================================================================================"
echo -e "${NC}"

# Build binaries
echo -e "${GREEN}Building binaries...${NC}"
cd "$SCRIPT_DIR/.."
make clean
make

# Get test choice
echo ""
echo -e "${YELLOW}Choose test mode:${NC}"
echo "  1 = Stage 1 only (slowest: 10 MHz)"
echo "  2 = Stage 1 + Stage 2 (slow: 25 MHz)"
echo "  3 = Complete system (medium-slow: 50 MHz)"
echo "  4 = Complete system with timestamps (100 MHz)"
echo ""
read -p "Enter choice (1-4, default 3): " choice
choice=${choice:-3}

case $choice in
    1)
        SPEED="10M"
        DESC="Stage 1 Only (10 MHz)"
        TEST_NUM=1
        ;;
    2)
        SPEED="25M"
        DESC="Stage 1 + Stage 2 (25 MHz)"
        TEST_NUM=2
        ;;
    3)
        SPEED="50M"
        DESC="Complete System (50 MHz)"
        TEST_NUM=3
        ;;
    4)
        SPEED="100M"
        DESC="Complete System with Timestamps (100 MHz)"
        TEST_NUM=3
        WITH_TIMESTAMPS=1
        ;;
    *)
        SPEED="50M"
        DESC="Complete System (50 MHz)"
        TEST_NUM=3
        ;;
esac

echo ""
echo -e "${GREEN}Running test: $DESC${NC}"
echo -e "${YELLOW}QEMU will run at $SPEED (very slow to watch debug output)${NC}"
echo ""

# Create disk image based on test choice
DISK_IMAGE="./boot_disk_slow.img"

echo -e "${GREEN}Creating disk image...${NC}"
dd if=/dev/zero of="$DISK_IMAGE" bs=512 count=2880 2>/dev/null

echo -e "${GREEN}Writing bootloader...${NC}"
dd if="$BOOTLOADER_BIN" of="$DISK_IMAGE" bs=512 count=1 conv=notrunc 2>/dev/null

if [ "$TEST_NUM" -ge 2 ]; then
    echo -e "${GREEN}Writing stage 2 loader...${NC}"
    dd if="$STAGE2_BIN" of="$DISK_IMAGE" bs=512 seek=2 conv=notrunc 2>/dev/null
fi

if [ "$TEST_NUM" -ge 3 ]; then
    echo -e "${GREEN}Writing kernel...${NC}"
    dd if="$KERNEL_BIN" of="$DISK_IMAGE" bs=512 seek=4 conv=notrunc 2>/dev/null
fi

echo ""
echo -e "${CYAN}Starting QEMU in slow motion...${NC}"
echo -e "${YELLOW}Speed: $SPEED | CPU will appear to run much slower${NC}"
echo -e "${YELLOW}You'll see all debug messages [DEBUG] Stage 1, [DEBUG] Stage 2, etc.${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to exit QEMU${NC}"
echo ""

# Run QEMU with slow CPU speed
# Using -icount to slow down CPU execution
# shift parameter controls slowdown: shift=1 means 1/N speed
if [ "$WITH_TIMESTAMPS" = "1" ]; then
    # With timestamps for better timing visibility
    echo "[QEMU] Slow test starting at $(date '+%H:%M:%S')" 
    qemu-system-x86_64 \
        -drive file="$DISK_IMAGE",format=raw,if=floppy \
        -m 128M \
        -boot a \
        -cpu max \
        -icount shift=5 \
        -rtc clock=vm \
        2>&1 | while IFS= read -r line; do
            echo "[$(date '+%H:%M:%S.%3N')] $line"
        done
    echo "[QEMU] Slow test ended at $(date '+%H:%M:%S')"
else
    # Standard slow test without timestamps
    qemu-system-x86_64 \
        -drive file="$DISK_IMAGE",format=raw,if=floppy \
        -m 128M \
        -boot a \
        -cpu max \
        -icount shift=5
fi

echo ""
echo -e "${GREEN}Test completed${NC}"
