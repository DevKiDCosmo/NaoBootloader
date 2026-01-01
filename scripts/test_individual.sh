#!/bin/bash

# Individual Bootloader Testing Script

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}=== Individual Bootloader Component Tests ===${NC}"
echo ""

# Test 1: Stage 1 only (should show disk error since stage 2 is missing)
echo -e "${CYAN}Test 1: Stage 1 Bootloader Only${NC}"
echo "Expected: Shows '[DEBUG] Stage 1: Bootloader Init' then disk error"
echo "Command:"
echo "  dd if=/dev/zero of=test1.img bs=512 count=2880 2>/dev/null"
echo "  dd if=bootloader.bin of=test1.img bs=512 count=1 conv=notrunc 2>/dev/null"
echo "  qemu-system-x86_64 -drive file=test1.img,format=raw,if=floppy"
echo ""

# Test 2: Stage 1 + Stage 2 (should show stage 2 error since kernel is missing)
echo -e "${CYAN}Test 2: Stage 1 + Stage 2 (no kernel)${NC}"
echo "Expected: Shows Stage 1 debug, then Stage 2 debug, then kernel read error"
echo "Command:"
echo "  dd if=/dev/zero of=test2.img bs=512 count=2880 2>/dev/null"
echo "  dd if=bootloader.bin of=test2.img bs=512 count=1 conv=notrunc 2>/dev/null"
echo "  dd if=stage2.bin of=test2.img bs=512 seek=2 conv=notrunc 2>/dev/null"
echo "  qemu-system-x86_64 -drive file=test2.img,format=raw,if=floppy"
echo ""

# Test 3: Complete system
echo -e "${CYAN}Test 3: Complete System (Stage 1 + Stage 2 + Kernel)${NC}"
echo "Expected: Shows all debug messages and kernel shell"
echo "Command:"
echo "  dd if=/dev/zero of=test3.img bs=512 count=2880 2>/dev/null"
echo "  dd if=bootloader.bin of=test3.img bs=512 count=1 conv=notrunc 2>/dev/null"
echo "  dd if=stage2.bin of=test3.img bs=512 seek=2 conv=notrunc 2>/dev/null"
echo "  dd if=kernel.bin of=test3.img bs=512 seek=4 conv=notrunc 2>/dev/null"
echo "  qemu-system-x86_64 -drive file=test3.img,format=raw,if=floppy"
echo ""

echo -e "${YELLOW}Choose a test to run (1-3) or 'all' to run test 3:${NC}"
read -p "Enter choice: " choice

case $choice in
    1)
        echo -e "${GREEN}Running Test 1...${NC}"
        dd if=/dev/zero of=test1.img bs=512 count=2880 2>/dev/null
        dd if=bootloader.bin of=test1.img bs=512 count=1 conv=notrunc 2>/dev/null
        qemu-system-x86_64 -drive file=test1.img,format=raw,if=floppy
        ;;
    2)
        echo -e "${GREEN}Running Test 2...${NC}"
        dd if=/dev/zero of=test2.img bs=512 count=2880 2>/dev/null
        dd if=bootloader.bin of=test2.img bs=512 count=1 conv=notrunc 2>/dev/null
        dd if=stage2.bin of=test2.img bs=512 seek=2 conv=notrunc 2>/dev/null
        qemu-system-x86_64 -drive file=test2.img,format=raw,if=floppy
        ;;
    3|all)
        echo -e "${GREEN}Running Test 3 (Complete System)...${NC}"
        dd if=/dev/zero of=test3.img bs=512 count=2880 2>/dev/null
        dd if=bootloader.bin of=test3.img bs=512 count=1 conv=notrunc 2>/dev/null
        dd if=stage2.bin of=test3.img bs=512 seek=2 conv=notrunc 2>/dev/null
        dd if=kernel.bin of=test3.img bs=512 seek=4 conv=notrunc 2>/dev/null
        qemu-system-x86_64 -drive file=test3.img,format=raw,if=floppy
        ;;
    *)
        echo -e "${YELLOW}Invalid choice. Running Test 3 by default...${NC}"
        dd if=/dev/zero of=test3.img bs=512 count=2880 2>/dev/null
        dd if=bootloader.bin of=test3.img bs=512 count=1 conv=notrunc 2>/dev/null
        dd if=stage2.bin of=test3.img bs=512 seek=2 conv=notrunc 2>/dev/null
        dd if=kernel.bin of=test3.img bs=512 seek=4 conv=notrunc 2>/dev/null
        qemu-system-x86_64 -drive file=test3.img,format=raw,if=floppy
        ;;
esac

echo ""
echo -e "${GREEN}Test completed${NC}"
