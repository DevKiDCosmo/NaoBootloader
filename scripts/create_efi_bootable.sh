#!/bin/bash

# create_efi_bootable.sh - Create EFI bootable USB drive
# Creates a USB drive with GPT partition table for EFI systems

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

print_banner "Create EFI Bootable USB Drive"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

validate_binaries() {
    log_info "Validating binary files..."
    
    cd "$SCRIPT_DIR/.."
    
    if [ ! -f "bootloader.bin" ] || [ ! -f "kernel.bin" ]; then
        log_warn "Binary files not found, attempting to build..."
        make 2>/dev/null || true
    fi
    
    if [ ! -f "bootloader.bin" ] || [ ! -f "kernel.bin" ]; then
        log_error "Binary files not found"
        return 1
    fi
    
    log_success "Binaries validated"
    return 0
}

detect_usb_devices() {
    diskutil list external 2>/dev/null | grep "^/dev/disk" | awk '{print $1}'
}

display_usb_devices() {
    local devices=()
    while IFS= read -r device; do
        if [ -n "$device" ]; then
            devices+=("$device")
        fi
    done < <(detect_usb_devices)
    
    if [ ${#devices[@]} -eq 0 ]; then
        log_error "No USB devices detected"
        return 1
    fi
    
    log_info "Available USB devices:"
    for i in "${!devices[@]}"; do
        local device="${devices[$i]}"
        local size=$(diskutil info "$device" 2>/dev/null | grep "Total Size" | awk -F': ' '{print $2}')
        local name=$(diskutil info "$device" 2>/dev/null | grep "Device / Media Name" | awk -F': ' '{print $2}')
        echo "  [$i] $device - $name ($size)"
    done
    
    echo ""
    read -p "Select device number: " selection
    echo "${devices[$selection]}"
}

create_efi_partition() {
    local device=$1
    
    print_separator
    log_warn "WARNING: All data on $device will be DESTROYED!"
    print_separator
    read -p "Type 'YES' to confirm: " confirm
    
    if [ "$confirm" != "YES" ]; then
        log_info "Cancelled"
        return 1
    fi
    
    # Unmount
    log_info "Unmounting device..."
    diskutil unmountDisk "$device" 2>/dev/null || true
    sleep 1
    
    # Clear and create GPT
    log_info "Clearing disk..."
    diskutil secureErase freespace 0 "$device" 2>/dev/null || diskutil eraseDisk JHFS+ temp "$device" 2>/dev/null || true
    
    sleep 2
    
    log_info "Creating GPT partition table with EFI partition..."
    diskutil partitionDisk "$device" GPT "MS-DOS" "EFINOLOAD" 0 2>/dev/null || true
    
    sleep 2
    
    local efi_part="${device}s1"
    
    log_success "EFI Partition: $efi_part (GPT, MS-DOS 100%)"
    
    echo "$efi_part"
}

install_efi_bootloader() {
    local device=$1
    local efi_part=$2
    
    print_section "Installing EFI Boot Files"
    
    # Mount partition
    log_info "Mounting EFI partition..."
    diskutil mount "$efi_part" 2>/dev/null || true
    sleep 1
    
    # Get mount point
    local efi_mount=$(diskutil info "$efi_part" 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}')
    
    if [ -z "$efi_mount" ] || [ "$efi_mount" = "(none)" ]; then
        efi_mount="/Volumes/EFINOLOAD"
    fi
    
    log_debug "EFI Mount: $efi_mount"
    
    # Change to project directory
    cd "$SCRIPT_DIR/.."
    
    # Create EFI directory structure
    log_info "Creating EFI directory structure..."
    mkdir -p "$efi_mount/EFI/BOOT" 2>/dev/null || true
    
    # Install bootloader as BOOTX64.EFI
    log_info "Installing BOOTX64.EFI..."
    cp bootloader.bin "$efi_mount/EFI/BOOT/BOOTX64.EFI" 2>/dev/null && log_success "EFI bootloader installed" || log_error "Failed to install EFI bootloader"
    
    # Install kernel
    log_info "Installing kernel..."
    cp kernel.bin "$efi_mount/kernel.bin" 2>/dev/null && log_success "Kernel copied" || log_error "Failed to copy kernel"
    
    # Create info files
    log_info "Creating information files..."
    
    {
        echo "=== NaoBootloader - EFI Boot Device ==="
        echo "Created: $(date)"
        echo ""
        echo "This USB drive is bootable on UEFI/EFI systems:"
        echo "  • Modern MacBooks (Intel and Apple Silicon)"
        echo "  • UEFI PCs (Windows 8+, Linux with EFI)"
        echo ""
        echo "EFI Boot Structure:"
        echo "  • EFI/BOOT/BOOTX64.EFI - Main EFI bootloader"
        echo "  • kernel.bin - Kernel image"
        echo ""
        echo "To boot:"
        echo "  1. Insert USB into computer"
        echo "  2. Hold OPTION/ALT (Mac) or press boot menu key during startup"
        echo "  3. Select USB drive"
        echo "  4. Bootloader should execute"
    } > "$efi_mount/README_EFI.txt"
    
    # Verify files
    print_section "Verifying Installation"
    
    log_info "EFI Partition Contents:"
    if [ -f "$efi_mount/EFI/BOOT/BOOTX64.EFI" ]; then
        local size=$(stat -f%z "$efi_mount/EFI/BOOT/BOOTX64.EFI" 2>/dev/null || echo "?")
        log_success "✓ EFI/BOOT/BOOTX64.EFI ($size bytes)"
    else
        log_error "✗ EFI/BOOT/BOOTX64.EFI NOT FOUND"
    fi
    
    if [ -f "$efi_mount/kernel.bin" ]; then
        local size=$(stat -f%z "$efi_mount/kernel.bin" 2>/dev/null || echo "?")
        log_success "✓ kernel.bin ($size bytes)"
    else
        log_error "✗ kernel.bin NOT FOUND"
    fi
    
    # Sync and unmount
    log_info ""
    log_info "Syncing and unmounting..."
    sync
    sleep 1
    diskutil unmount "$efi_mount" 2>/dev/null || true
    
    log_success "Installation complete"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    check_root || exit 1
    validate_binaries || exit 1
    
    print_section "USB Device Selection"
    local device=$(display_usb_devices) || exit 1
    
    log_info "Selected device: $device"
    
    print_section "Creating EFI Partition"
    local efi_part=$(create_efi_partition "$device") || exit 1
    
    install_efi_bootloader "$device" "$efi_part"
    
    print_section "Complete"
    log_success "EFI bootable USB drive created successfully!"
    log_info ""
    log_info "This USB drive now boots on:"
    log_info "  ✓ UEFI/EFI systems (MacBooks, modern PCs)"
    log_info ""
    log_info "Insert the USB and boot to test!"
}

main "$@"
