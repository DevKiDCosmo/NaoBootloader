#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Bootloader Binary Inspection Tools ===${NC}"
echo ""

# Check if binaries exist
if [ ! -f "osshell.bin" ]; then
    echo -e "${RED}Error: osshell.bin not found${NC}"
    exit 1
fi

echo -e "${CYAN}1. File Information${NC}"
echo "Size and type of binaries:"
ls -lh bootloader.bin stage2.bin osshell.bin 2>/dev/null
file bootloader.bin stage2.bin osshell.bin 2>/dev/null
echo ""

echo -e "${CYAN}2. Hexdump (first 512 bytes)${NC}"
echo "Bootloader.bin:"
hexdump -C bootloader.bin | head -20
echo ""
echo "Stage2.bin:"
hexdump -C stage2.bin | head -20
echo ""
echo "Osshell.bin (first 512 bytes):"
hexdump -C osshell.bin | head -20
echo ""

echo -e "${CYAN}3. Disassembly (16-bit x86)${NC}"
echo "Bootloader.bin disassembly:"
ndisasm -b16 -o0x7C00 bootloader.bin | head -30
echo ""
echo "Stage2.bin disassembly:"
ndisasm -b16 -o0x7E00 stage2.bin | head -30
echo ""
echo "Osshell.bin disassembly:"
ndisasm -b16 -o0x10000 osshell.bin | head -30
echo ""

echo -e "${CYAN}4. Boot Signature Check${NC}"
echo "Bootloader.bin boot signature (should end with 55 AA):"
xxd -s 510 -l 2 bootloader.bin
echo ""

echo -e "${CYAN}5. Strings in binaries${NC}"
echo "Bootloader.bin strings:"
strings bootloader.bin
echo ""
echo "Stage2.bin strings:"
strings stage2.bin
echo ""
echo "Osshell.bin strings:"
strings osshell.bin | head -20
echo ""

echo -e "${YELLOW}=== QEMU Debug Options ===${NC}"
echo ""
echo -e "${CYAN}Run with CPU state logging:${NC}"
echo "  qemu-system-x86_64 -drive file=boot_disk.img,format=raw,if=floppy -d cpu,int -no-reboot"
echo ""
echo -e "${CYAN}Run with full execution trace:${NC}"
echo "  qemu-system-x86_64 -drive file=boot_disk.img,format=raw,if=floppy -d exec,cpu,int -D qemu.log -no-reboot"
echo "  tail -f qemu.log"
echo ""
echo -e "${CYAN}Run with GDB debugging:${NC}"
echo "  Terminal 1: qemu-system-x86_64 -drive file=boot_disk.img,format=raw,if=floppy -s -S"
echo "  Terminal 2: gdb"
echo "    (gdb) target remote localhost:1234"
echo "    (gdb) set architecture i8086"
echo "    (gdb) break *0x7c00"
echo "    (gdb) continue"
echo ""
echo -e "${CYAN}Run with serial output:${NC}"
echo "  qemu-system-x86_64 -drive file=boot_disk.img,format=raw,if=floppy -serial stdio"
echo ""
echo -e "${CYAN}Bochs debugging (if installed):${NC}"
echo "  bochs -q 'boot:floppy' 'floppya: 1_44=boot_disk.img, status=inserted'"
echo ""

echo -e "${YELLOW}=== Memory Layout ===${NC}"
echo "0x7C00: Stage 1 bootloader (512 bytes)"
echo "0x7E00: Stage 2 loader (loaded by stage 1)"
echo "0x10000: Kernel/OSShell (loaded by stage 2, up to 80 sectors = 40KB)"
echo ""