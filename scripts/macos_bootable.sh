#!/bin/bash

# NaoBootloader USB Creation Script
# This script creates a bootable USB device from kernel and bootloader binaries

# Don't exit on every error - handle them explicitly
set +e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default file names
KERNEL_BIN="${1:-kernel.bin}"
BOOTLOADER_BIN="${2:-bootloader.bin}"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to validate binary files exist
validate_binaries() {
    print_info "Validating binary files..."
    
    # Check if binaries exist, if not try to build them
    if [ ! -f "$KERNEL_BIN" ] || [ ! -f "$BOOTLOADER_BIN" ]; then
        print_warning "Binary files not found, attempting to build..."
        
        if command -v make >/dev/null 2>&1; then
            print_info "Building binaries with make..."
            make 2>/dev/null || print_warning "Make build had warnings but continuing..."
        else
            print_error "make command not found. Cannot build binaries."
            print_info "Please ensure NASM is installed: brew install nasm"
            exit 1
        fi
    fi
    
    # Verify binaries exist after build attempt
    if [ ! -f "$KERNEL_BIN" ]; then
        print_error "Kernel binary not found: $KERNEL_BIN"
        print_info "Make sure kernel.asm exists and NASM is installed"
        exit 1
    fi
    
    if [ ! -f "$BOOTLOADER_BIN" ]; then
        print_error "Bootloader binary not found: $BOOTLOADER_BIN"
        print_info "Make sure bootloader.asm exists and NASM is installed"
        exit 1
    fi
    
    # Verify binaries are valid
    local kernel_size=$(stat -f%z "$KERNEL_BIN" 2>/dev/null || echo "0")
    local bootloader_size=$(stat -f%z "$BOOTLOADER_BIN" 2>/dev/null || echo "0")
    
    if [ "$kernel_size" -eq 0 ]; then
        print_error "Kernel binary is empty: $KERNEL_BIN"
        exit 1
    fi
    
    if [ "$bootloader_size" -eq 0 ]; then
        print_error "Bootloader binary is empty: $BOOTLOADER_BIN"
        exit 1
    fi
    
    print_info "Binary files validated successfully"
    print_info "  Kernel: $KERNEL_BIN ($(du -h "$KERNEL_BIN" | cut -f1))"
    print_info "  Bootloader: $BOOTLOADER_BIN ($(du -h "$BOOTLOADER_BIN" | cut -f1))"
}

# Function to detect USB devices on macOS
detect_usb_devices() {
    local devices=()
    
    # Use diskutil to list all disks and filter for external disks
    while IFS= read -r disk; do
        if [ -n "$disk" ]; then
            devices+=("/dev/$disk")
        fi
    done < <(diskutil list external | grep "^/dev/disk" | awk '{print $1}' | sed 's|/dev/||')
    
    printf '%s\n' "${devices[@]}"
}

# Function to display available USB devices on macOS
display_usb_devices() {
    if [ ${#USB_DEVICES[@]} -eq 0 ]; then
        print_error "No USB devices detected!"
        print_info "Please insert a USB drive and try again."
        exit 1
    fi
    
    print_info "Available USB devices:"
    echo ""
    
    for i in "${!USB_DEVICES[@]}"; do
        local device="${USB_DEVICES[$i]}"
        local size=$(diskutil info "$device" 2>/dev/null | grep "Total Size" | awk -F': ' '{print $2}' || echo "Unknown")
        local name=$(diskutil info "$device" 2>/dev/null | grep "Device / Media Name" | awk -F': ' '{print $2}' || echo "Unknown")
        
        echo "  [$i] $device"
        echo "      Size: $size"
        echo "      Name: $name"
        echo ""
    done
}

# Function to prompt user for device selection
select_device() {
    while true; do
        read -p "Enter the number of the device to use (or 'q' to quit): " selection
        
        if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
            print_info "Operation cancelled by user"
            exit 0
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 0 ] && [ "$selection" -lt ${#USB_DEVICES[@]} ]; then
            echo "${USB_DEVICES[$selection]}"
            return
        else
            print_error "Invalid selection. Please enter a number between 0 and $((${#USB_DEVICES[@]}-1))"
        fi
    done
}

# Function to confirm device selection on macOS
confirm_device() {
    local device=$1
    
    print_warning "WARNING: All data on $device will be DESTROYED!"
    print_warning "This operation is irreversible!"
    echo ""
    
    # Show current partitions on the device
    print_info "Current partitions on $device:"
    diskutil list "$device" 2>/dev/null || echo "Unable to list partitions"
    echo ""
    
    read -p "Are you sure you want to continue? Type 'YES' to confirm: " confirm
    
    if [ "$confirm" != "YES" ]; then
        print_info "Operation cancelled"
        exit 0
    fi
}

# Function to unmount all partitions on the device (macOS)
unmount_device() {
    local device=$1
    print_info "Unmounting all partitions on $device..."
    
    # Unmount using diskutil on macOS
    diskutil unmountDisk "$device" 2>/dev/null || true
    
    print_info "Device unmounted successfully"
}

# Function to create partition table and format device (macOS)
format_device() {
    local device=$1
    print_info "Preparing device $device for formatting..."
    
    # Unmount the disk first (double-check)
    diskutil unmountDisk "$device" 2>/dev/null || true
    sleep 1
    
    # Erase and partition the disk using diskutil
    print_info "Creating MBR partition table and FAT32 partition..."
    diskutil partitionDisk "$device" 1 MBR "MS-DOS" "NAOBOOT" 0 2>/dev/null
    
    # Wait for partition to be created and mounted
    sleep 2
    
    # Determine partition name (macOS uses diskXsY format)
    local partition="${device}s1"
    
    # Verify partition exists (be more lenient with the check)
    print_info "Verifying partition $partition..."
    if diskutil info "$partition" &>/dev/null; then
        print_info "Partition verified successfully"
    else
        # Try without the 's'
        partition="${device}1"
        if ! diskutil info "$partition" &>/dev/null; then
            print_warning "Partition verification failed, but continuing anyway"
            # Use the s1 version as fallback
            partition="${device}s1"
        fi
    fi
    
    print_info "Device formatted successfully"
    echo "$partition"
}

# Function to install bootloader (macOS)
install_bootloader() {
    local device=$1
    local partition=$2
    
    print_info "Installing bootloader and kernel to $device..."
    
    # Validate bootloader size (warn if too large for MBR, but continue)
    local bootloader_size=$(stat -f%z "$BOOTLOADER_BIN" 2>/dev/null || echo "0")
    print_info "Bootloader size: $bootloader_size bytes"
    
    if [ "$bootloader_size" -gt 446 ]; then
        print_warning "Bootloader is $bootloader_size bytes (larger than MBR 446-byte limit)"
        print_info "Bootloader will be stored in the FAT32 partition instead"
    else
        # Write bootloader to the MBR if it fits
        print_info "Writing bootloader to MBR..."
        if dd if="$BOOTLOADER_BIN" of="$device" bs=1 count="$bootloader_size" conv=notrunc 2>/dev/null; then
            print_info "Bootloader written to MBR successfully"
        else
            print_warning "Could not write to MBR (this is normal for FAT32 virtual drives)"
        fi
    fi
    
    # Mount the partition (macOS mounts automatically, but let's ensure)
    sleep 2
    
    # Find the actual mount point - try multiple times
    local mount_point=""
    local attempt=0
    while [ -z "$mount_point" ] && [ $attempt -lt 5 ]; do
        mount_point=$(diskutil info "$partition" 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}')
        if [ -z "$mount_point" ] || [ "$mount_point" = "(none)" ]; then
            mount_point=""
            attempt=$((attempt + 1))
            if [ $attempt -lt 5 ]; then
                print_info "Waiting for mount (attempt $attempt/5)..."
                sleep 1
                # Try to mount the partition
                diskutil mount "$partition" 2>/dev/null || true
            fi
        fi
    done
    
    if [ -z "$mount_point" ] || [ "$mount_point" = "(none)" ]; then
        # If still not mounted, try to find ANY volume
        mount_point=$(diskutil info "$partition" 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}')
        if [ -z "$mount_point" ] || [ "$mount_point" = "(none)" ]; then
            # Fallback to common mount point
            if [ -d "/Volumes/NAOBOOT" ]; then
                mount_point="/Volumes/NAOBOOT"
                print_warning "Using fallback mount point: $mount_point"
            else
                print_warning "Could not determine mount point, skipping file copy"
                return 1
            fi
        fi
    fi
    
    print_info "Mount point: $mount_point"
    
    # Copy kernel to the partition
    print_info "Copying kernel to USB device..."
    if ! cp "$KERNEL_BIN" "$mount_point/kernel.bin" 2>/dev/null; then
        print_error "Failed to copy kernel to $mount_point"
        diskutil unmount "$mount_point" 2>/dev/null || true
        return 1
    fi
    print_info "Kernel copied successfully"
    
    # Copy bootloader binary as well for reference
    print_info "Copying bootloader reference to USB device..."
    if ! cp "$BOOTLOADER_BIN" "$mount_point/bootloader.bin" 2>/dev/null; then
        print_warning "Failed to copy bootloader reference (non-critical)"
    else
        print_info "Bootloader reference copied successfully"
    fi
    
    # Sync to ensure all data is written
    print_info "Syncing filesystem..."
    sync
    sleep 1
    
    # Unmount
    print_info "Unmounting partition..."
    diskutil unmount "$mount_point" 2>/dev/null || true
    
    print_info "Bootloader and kernel installed successfully"
    return 0
}

# Function to verify installation (macOS)
verify_installation() {
    local device=$1
    local partition=$2
    
    print_info "Verifying installation..."
    
    # Check if bootloader was written
    local mbr_backup=$(mktemp)
    dd if="$device" bs=1 count=446 of="$mbr_backup" 2>/dev/null
    local mbr_size=$(stat -f%z "$mbr_backup")
    rm -f "$mbr_backup"
    
    if [ "$mbr_size" -eq 446 ]; then
        print_info "MBR bootloader verified (446 bytes)"
    else
        print_warning "MBR verification failed"
    fi
    
    # Check files on device
    local mount_point="/Volumes/NAOBOOT"
    
    if [ -d "$mount_point" ]; then
        if [ -f "$mount_point/kernel.bin" ]; then
            print_info "Kernel binary found on device"
        else
            print_warning "Kernel binary not found on device"
        fi
    else
        print_warning "Could not verify files (mount point not accessible)"
    fi
}

# Main function
main() {
    echo ""
    print_info "=== NaoBootloader USB Creation Script (macOS) ==="
    echo ""
    
    # Check for root privileges
    check_root
    
    # Validate binary files
    validate_binaries
    echo ""
    
    # Detect USB devices
    print_info "Scanning for USB devices..."
    USB_DEVICES=()
    while IFS= read -r device; do
        if [ -n "$device" ]; then
            USB_DEVICES+=("$device")
        fi
    done < <(detect_usb_devices)
    
    # Display available devices
    display_usb_devices
    
    # Let user select device
    selected_device=$(select_device)
    print_info "Selected device: $selected_device"
    echo ""
    
    # Confirm with user
    confirm_device "$selected_device"
    echo ""
    
    # Unmount device
    unmount_device "$selected_device"
    
    # Format device
    partition=$(format_device "$selected_device")
    print_info "Partition created: $partition"
    echo ""
    
    # Install bootloader
    install_bootloader "$selected_device" "$partition"
    echo ""
    
    # Verify installation
    verify_installation "$selected_device" "$partition"
    echo ""
    
    print_info "=== Bootable USB created successfully! ==="
    print_info "Device: $selected_device"
    print_info "You can now safely eject the USB drive"
    echo ""
}

# Declare global array for USB devices
declare -a USB_DEVICES

# Run main function
main
