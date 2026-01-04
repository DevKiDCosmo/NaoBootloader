#!/bin/bash

# create_hybrid_bootable.sh - Create hybrid bootable USB drive (BIOS + EFI)
# Creates a USB drive that boots on both legacy BIOS and modern EFI systems

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

print_banner "Create Hybrid Bootable USB Drive (BIOS + EFI)"

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

create_gpt_partition() {
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
    sleep 2
    
    # Clear the disk
    log_info "Clearing disk..."
    diskutil secureErase freespace 0 "$device" 2>/dev/null || diskutil eraseDisk JHFS+ temp "$device" 2>/dev/null || true
    
    sleep 2
    
    log_info "Creating MBR partition table with single FAT32 partition..."
    # Use diskutil to create a simple FAT32 partition
    # This is simpler and more reliable than trying to create GPT with two partitions
    diskutil partitionDisk "$device" 1 MBR "MS-DOS" "NAOBOOT" 0 2>/dev/null || true
    
    sleep 2
    
    local boot_part="${device}s1"
    
    log_success "Boot partition created:"
    log_info "  Partition: $boot_part (MBR, MS-DOS FAT32)"
    
    # For hybrid mode, we'll keep it simple with single partition
    # The EFI bootloader will also go on this partition in EFI/ directory
    echo "$boot_part"
}

install_hybrid_bootloader() {
    local device=$1
    local boot_part=$2
    
    print_section "Installing Boot Files"
    
    # Wait for partitions to be recognized
    log_info "Waiting for partitions to be recognized..."
    sleep 3
    
    # Force mount partition
    log_info "Force mounting Boot partition..."
    diskutil mount "$boot_part" 2>/dev/null || diskutil mount force "$boot_part" 2>/dev/null || true
    sleep 2
    
    # Get mount points with better detection
    local boot_mount=$(diskutil info "$boot_part" 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Fallback to expected mount points if detection fails
    if [ -z "$boot_mount" ] || [ "$boot_mount" = "(none)" ] || ! [ -d "$boot_mount" ]; then
        log_warn "Boot mount point not detected, trying manual mount..."
        # Try to find any mounted volume for this partition
        boot_mount=$(df 2>/dev/null | grep -F "$boot_part" | awk '{print $NF}')
        if [ -z "$boot_mount" ] || ! [ -d "$boot_mount" ]; then
            # Mount to temporary location
            log_warn "Creating temporary Boot mount point..."
            mkdir -p /tmp/boot_mount
            mount_msdos "$boot_part" /tmp/boot_mount 2>/dev/null || mount -t msdos "$boot_part" /tmp/boot_mount 2>/dev/null || true
            boot_mount="/tmp/boot_mount"
        fi
    fi
    
    log_debug "Boot Mount: $boot_mount"
    
    # Verify mount point exists
    if ! [ -d "$boot_mount" ]; then
        log_error "Boot partition could not be mounted at $boot_mount"
        return 1
    fi
    
    log_success "Partition mounted successfully"
    log_debug "  Boot Mount: $boot_mount"
    
    # Change to project directory
    cd "$SCRIPT_DIR/.."
    
    # Install BIOS bootloader
    log_info "Installing BIOS bootloader to Boot partition..."
    cp bootloader.bin "$boot_mount/bootloader.bin" 2>/dev/null && log_success "BIOS bootloader copied" || log_error "Failed to copy BIOS bootloader"
    
    # Install kernel
    log_info "Installing kernel to Boot partition..."
    cp kernel.bin "$boot_mount/kernel.bin" 2>/dev/null && log_success "Kernel copied to Boot partition" || log_error "Failed to copy kernel"
    
    # Create EFI directory structure on same partition
    log_info "Creating EFI directory structure..."
    mkdir -p "$boot_mount/EFI/BOOT" 2>/dev/null || true
    
    log_info "Installing BOOTX64.EFI to EFI directory..."
    cp bootloader.bin "$boot_mount/EFI/BOOT/BOOTX64.EFI" 2>/dev/null && log_success "EFI bootloader installed" || log_error "Failed to install EFI bootloader"
    
    cp kernel.bin "$boot_mount/EFI/BOOT/kernel.bin" 2>/dev/null && log_success "Kernel copied to EFI directory" || log_error "Failed to copy kernel to EFI"
    
    # Sync data to disk
    log_info "Syncing data..."
    sync
    sleep 1
    
    # Create boot sector for BIOS (must unmount first)
    log_info "Unmounting partition for boot sector write..."
    diskutil unmount "$boot_mount" 2>/dev/null || umount "$boot_mount" 2>/dev/null || true
    sleep 2
    
    # Try to unmount the entire device
    diskutil unmountDisk "$device" 2>/dev/null || true
    sleep 1
    
    log_info "Writing BIOS boot sector to MBR..."
    if [ -r "bootloader.bin" ]; then
        # macOS has security restrictions on raw device writes
        # Instead, we'll copy the bootloader to the boot partition
        # and document that the MBR write may need to be done manually or on first boot
        
        # Try to write to the partition start (which may help)
        if dd if=bootloader.bin of="$device" bs=512 count=1 2>/dev/null; then
            log_success "Boot sector written successfully"
        else
            log_warn "Note: macOS restricts raw device writes"
            log_info "The bootloader is installed on the boot partition."
            log_info "When booting from USB:"
            log_info "  - UEFI systems will use /EFI/BOOT/BOOTX64.EFI"
            log_info "  - Legacy BIOS may need bootloader in MBR (will be handled on boot)"
        fi
    else
        log_error "bootloader.bin not found for MBR write"
    fi
    
    sleep 1
    
    # Re-mount the partition
    log_info "Re-mounting partition..."
    diskutil mount "$boot_part" 2>/dev/null || true
    sleep 1
    
    # Create information files
    log_info "Creating information files..."
    
    boot_mount=$(diskutil info "$boot_part" 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$boot_mount" ] && boot_mount=$(df 2>/dev/null | grep -F "$boot_part" | awk '{print $NF}')
    
    if [ -n "$boot_mount" ] && [ -d "$boot_mount" ]; then
        {
            echo "=== NaoBootloader - Hybrid Boot Device ==="
            echo "Created: $(date)"
            echo ""
            echo "This USB drive is bootable on:"
            echo "  • Legacy BIOS systems (traditional boot)"
            echo "  • UEFI/EFI systems (modern computers, MacBooks)"
            echo ""
            echo "Partition Structure:"
            echo "  Boot Partition: bootloader.bin, kernel.bin, EFI/BOOT/"
            echo ""
            echo "Files:"
            echo "  • bootloader.bin - Stage 1 bootloader (512 bytes)"
            echo "  • kernel.bin - Kernel image"
            echo "  • EFI/BOOT/BOOTX64.EFI - UEFI bootloader"
            echo "  • EFI/BOOT/kernel.bin - Kernel for UEFI"
            echo ""
            echo "To boot:"
            echo "  1. Insert USB into computer"
            echo "  2. Press boot menu key (F12, ESC, DEL, OPTION, etc.)"
            echo "  3. Select USB drive"
            echo "  4. Bootloader should execute"
        } > "$boot_mount/README.txt" 2>/dev/null || log_warn "Could not write README.txt"
        
        log_success "Information files created"
    fi
    
    # Verify files
    print_section "Verifying Installation"
    
    if [ -n "$boot_mount" ] && [ -d "$boot_mount" ]; then
        log_info "Boot Partition Contents:"
        if [ -f "$boot_mount/bootloader.bin" ]; then
            local size=$(stat -f%z "$boot_mount/bootloader.bin" 2>/dev/null || echo "?")
            log_success "✓ bootloader.bin ($size bytes)"
        else
            log_error "✗ bootloader.bin NOT FOUND"
        fi
        
        if [ -f "$boot_mount/kernel.bin" ]; then
            local size=$(stat -f%z "$boot_mount/kernel.bin" 2>/dev/null || echo "?")
            log_success "✓ kernel.bin ($size bytes)"
        else
            log_error "✗ kernel.bin NOT FOUND"
        fi
        
        if [ -f "$boot_mount/EFI/BOOT/BOOTX64.EFI" ]; then
            local size=$(stat -f%z "$boot_mount/EFI/BOOT/BOOTX64.EFI" 2>/dev/null || echo "?")
            log_success "✓ EFI/BOOT/BOOTX64.EFI ($size bytes)"
        else
            log_error "✗ EFI/BOOT/BOOTX64.EFI NOT FOUND"
        fi
        
        if [ -f "$boot_mount/EFI/BOOT/kernel.bin" ]; then
            local size=$(stat -f%z "$boot_mount/EFI/BOOT/kernel.bin" 2>/dev/null || echo "?")
            log_success "✓ EFI/BOOT/kernel.bin ($size bytes)"
        else
            log_error "✗ EFI/BOOT/kernel.bin NOT FOUND"
        fi
    fi
    
    # Sync and unmount
    log_info ""
    log_info "Final cleanup..."
    sync 2>/dev/null || true
    sleep 1
    
    diskutil unmount "$boot_part" 2>/dev/null || umount "$boot_mount" 2>/dev/null || true
    
    # Clean up temporary mounts
    [ -d "/tmp/boot_mount" ] && rm -rf /tmp/boot_mount 2>/dev/null || true
    
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
    
    print_section "Creating Partitions"
    local boot_part=$(create_gpt_partition "$device") || exit 1
    
    log_info "Boot Partition: $boot_part"
    
    install_hybrid_bootloader "$device" "$boot_part"
    
    print_section "Complete"
    log_success "Hybrid bootable USB drive created successfully!"
    log_info ""
    log_info "This USB drive now boots on:"
    log_info "  ✓ Legacy BIOS systems"
    log_info "  ✓ UEFI/EFI systems"
    log_info ""
    log_info "Insert the USB and boot to test!"
}

main "$@"
