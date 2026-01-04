#!/bin/bash

# bootable_info.sh - Information about bootable media options
# Provides guidance on which bootable method to use

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

print_banner "NaoBootloader - Bootable Media Options"

print_section "Available Bootable Modes"

echo ""
echo -e "${COLOR_BRIGHT_GREEN}1. BIOS Bootable (Legacy)${COLOR_RESET}"
echo "   Command: sudo ./start.sh bootable"
echo "   • Traditional BIOS boot (older computers)"
echo "   • Compatible with systems from 2000-2010"
echo "   • Simpler setup, single boot method"
echo ""

echo -e "${COLOR_BRIGHT_GREEN}2. EFI Bootable (Modern)${COLOR_RESET}"
echo "   Command: sudo ./start.sh efi"
echo "   • UEFI/EFI boot (modern systems)"
echo "   • Compatible with MacBooks, modern Windows/Linux PCs"
echo "   • Requires GPT partition table"
echo ""

echo -e "${COLOR_BRIGHT_GREEN}3. Hybrid Bootable (Universal)${COLOR_RESET}"
echo "   Command: sudo ./start.sh hybrid"
echo "   • Boots on both BIOS and EFI systems"
echo "   • Works on both old and new computers"
echo "   • Recommended for maximum compatibility"
echo ""

print_section "Choosing the Right Mode"

echo -e "${COLOR_YELLOW}For MacBooks:${COLOR_RESET}"
echo "  • Use ${COLOR_BRIGHT_GREEN}EFI${COLOR_RESET} or ${COLOR_BRIGHT_GREEN}Hybrid${COLOR_RESET}"
echo "  • Modern Macs use UEFI only (no BIOS fallback)"
echo ""

echo -e "${COLOR_YELLOW}For Windows/Linux (Modern):${COLOR_RESET}"
echo "  • Use ${COLOR_BRIGHT_GREEN}EFI${COLOR_RESET} or ${COLOR_BRIGHT_GREEN}Hybrid${COLOR_RESET}"
echo "  • Most systems from 2010+ support UEFI"
echo ""

echo -e "${COLOR_YELLOW}For Legacy Systems:${COLOR_RESET}"
echo "  • Use ${COLOR_BRIGHT_GREEN}BIOS${COLOR_RESET} or ${COLOR_BRIGHT_GREEN}Hybrid${COLOR_RESET}"
echo "  • Older systems require traditional BIOS"
echo ""

echo -e "${COLOR_YELLOW}When in Doubt:${COLOR_RESET}"
echo "  • Use ${COLOR_BRIGHT_GREEN}Hybrid${COLOR_RESET}${COLOR_RESET} - it works everywhere"
echo ""

print_section "Requirements"

echo -e "${COLOR_CYAN}Hardware:${COLOR_RESET}"
echo "  • USB drive (at least 100MB)"
echo "  • Bootable USB compatible device"
echo ""

echo -e "${COLOR_CYAN}Software:${COLOR_RESET}"
echo "  • macOS system (for script execution)"
echo "  • Compiled binaries (bootloader.bin, kernel.bin)"
echo "  • Root/sudo privileges"
echo ""

echo -e "${COLOR_CYAN}Built Binaries:${COLOR_RESET}"
if [ -f "$SCRIPT_DIR/../bootloader.bin" ]; then
    echo -e "  ${COLOR_BRIGHT_GREEN}✓${COLOR_RESET} bootloader.bin"
else
    echo -e "  ${COLOR_BRIGHT_RED}✗${COLOR_RESET} bootloader.bin (not found - run ./start.sh build)"
fi
if [ -f "$SCRIPT_DIR/../kernel.bin" ]; then
    echo -e "  ${COLOR_BRIGHT_GREEN}✓${COLOR_RESET} kernel.bin"
else
    echo -e "  ${COLOR_BRIGHT_RED}✗${COLOR_RESET} kernel.bin (not found - run ./start.sh build)"
fi
echo ""

print_section "Step-by-Step Guide"

echo -e "${COLOR_BRIGHT_WHITE}Step 1: Build${COLOR_RESET}"
echo "  ./start.sh build"
echo ""

echo -e "${COLOR_BRIGHT_WHITE}Step 2: Choose Mode${COLOR_RESET}"
echo "  • BIOS:   sudo ./start.sh bootable"
echo "  • EFI:    sudo ./start.sh efi"
echo "  • Hybrid: sudo ./start.sh hybrid"
echo ""

echo -e "${COLOR_BRIGHT_WHITE}Step 3: Boot${COLOR_RESET}"
echo "  • Insert USB drive into target computer"
echo "  • During startup, press boot menu key (F12, ESC, DEL, etc.)"
echo "  • Select USB drive from boot menu"
echo "  • Watch bootloader execute"
echo ""

print_section "Troubleshooting"

echo -e "${COLOR_YELLOW}USB not recognized:${COLOR_RESET}"
echo "  • Try different USB port"
echo "  • Try another USB drive"
echo "  • Check BIOS boot order settings"
echo ""

echo -e "${COLOR_YELLOW}Permission denied:${COLOR_RESET}"
echo "  • Prefix command with sudo:"
echo "    sudo ./start.sh bootable"
echo ""

echo -e "${COLOR_YELLOW}Binaries not found:${COLOR_RESET}"
echo "  • Build first: ./start.sh build"
echo "  • Check with: ./start.sh status"
echo ""

print_section "Complete"

echo -e "${COLOR_BRIGHT_GREEN}Ready to create bootable media!${COLOR_RESET}"
echo ""
