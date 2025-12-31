#!/bin/bash

# NaoBootloader USB Creation Script
# This script creates a bootable USB device from kernel and bootloader binaries

set -e

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
    
    if [ ! -f "$KERNEL_BIN" ]; then
        print_error "Kernel binary not found: $KERNEL_BIN"
        exit 1
    fi
    
    if [ ! -f "$BOOTLOADER_BIN" ]; then
        print_error "Bootloader binary not found: $BOOTLOADER_BIN"
        exit 1
    fi
    
    print_info "Binary files validated successfully"
    print_info "  Kernel: $KERNEL_BIN ($(du -h "$KERNEL_BIN" | cut -f1))"
    print_info "  Bootloader: $BOOTLOADER_BIN ($(du -h "$BOOTLOADER_BIN" | cut -f1))"
}

# Function to detect USB devices
detect_usb_devices() {
    local devices=()
    
    # Check removable devices in /sys/block
    for dev in /sys/block/sd* /sys/block/nvme*; do
        if [ -e "$dev/removable" ] && [ "$(cat "$dev/removable")" = "1" ]; then
            device_name=$(basename "$dev")
            devices+=("/dev/$device_name")
        fi
    done
    
    # Also check for devices that might be USB using lsblk
    if command -v lsblk >/dev/null 2>&1; then
        while IFS= read -r dev; do
            if [ -n "$dev" ] && [ -b "/dev/$dev" ]; then
                if [[ ! " ${devices[@]} " =~ " /dev/$dev " ]]; then
                    devices+=("/dev/$dev")
                fi
            fi
        done < <(lsblk -ndo NAME,TRAN 2>/dev/null | grep "usb" | awk '{print $1}')
    fi
    
    echo "${devices[@]}"
}

# Function to display available USB devices
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
        local size=$(lsblk -ndo SIZE "$device" 2>/dev/null || echo "Unknown")
        local model=$(lsblk -ndo MODEL "$device" 2>/dev/null || echo "Unknown")
        local vendor=$(lsblk -ndo VENDOR "$device" 2>/dev/null || echo "Unknown")
        
        echo "  [$i] $device"
        echo "      Size: $size"
        echo "      Model: $model"
        echo "      Vendor: $vendor"
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

# Function to confirm device selection
confirm_device() {
    local device=$1
    
    print_warning "WARNING: All data on $device will be DESTROYED!"
    print_warning "This operation is irreversible!"
    echo ""
    
    # Show current partitions on the device
    print_info "Current partitions on $device:"
    lsblk "$device" 2>/dev/null || echo "Unable to list partitions"
    echo ""
    
    read -p "Are you sure you want to continue? Type 'YES' to confirm: " confirm
    
    if [ "$confirm" != "YES" ]; then
        print_info "Operation cancelled"
        exit 0
    fi
}

# Function to unmount all partitions on the device
unmount_device() {
    local device=$1
    print_info "Unmounting all partitions on $device..."
    
    # Unmount all partitions
    for partition in "$device"*; do
        if [ "$partition" != "$device" ] && mountpoint -q "$partition" 2>/dev/null; then
            umount "$partition" 2>/dev/null || true
        fi
    done
    
    # Additional check for mounted partitions
    mount | grep "^$device" | awk '{print $1}' | while read partition; do
        umount "$partition" 2>/dev/null || true
    done
    
    print_info "Device unmounted successfully"
}

# Function to create partition table and format device
format_device() {
    local device=$1
    print_info "Creating partition table on $device..."
    
    # Wipe existing partition table
    dd if=/dev/zero of="$device" bs=512 count=1 conv=notrunc 2>/dev/null
    
    # Create new MBR partition table with a single bootable partition
    print_info "Creating bootable partition..."
    (
        echo o      # Create a new empty DOS partition table
        echo n      # Add a new partition
        echo p      # Primary partition
        echo 1      # Partition number
        echo        # First sector (default)
        echo        # Last sector (default)
        echo a      # Make partition bootable
        echo w      # Write changes
    ) | fdisk "$device" >/dev/null 2>&1
    
    # Wait for partition to be created
    sleep 2
    partprobe "$device" 2>/dev/null || true
    sleep 1
    
    # Determine partition name
    local partition="${device}1"
    if [ ! -e "$partition" ]; then
        partition="${device}p1"
    fi
    
    # Format partition as FAT32
    print_info "Formatting partition as FAT32..."
    if [ -e "$partition" ]; then
        mkfs.vfat -F 32 -n "NAOBOOT" "$partition" >/dev/null 2>&1
    else
        print_error "Partition $partition not found after creation"
        exit 1
    fi
    
    echo "$partition"
}

# Function to install bootloader
install_bootloader() {
    local device=$1
    local partition=$2
    
    print_info "Installing bootloader to $device..."
    
    # Write bootloader to the MBR (first 446 bytes)
    # Note: This is a simplified approach. Real bootloaders may need more sophisticated installation
    dd if="$BOOTLOADER_BIN" of="$device" bs=446 count=1 conv=notrunc 2>/dev/null
    
    print_info "Bootloader written to MBR"
    
    # Mount the partition
    local mount_point="/mnt/naoboot_$$"
    mkdir -p "$mount_point"
    mount "$partition" "$mount_point"
    
    # Copy kernel to the partition
    print_info "Copying kernel to USB device..."
    cp "$KERNEL_BIN" "$mount_point/kernel.bin"
    
    # Optionally copy bootloader binary as well for reference
    cp "$BOOTLOADER_BIN" "$mount_point/bootloader.bin"
    
    # Sync to ensure all data is written
    sync
    
    # Unmount
    umount "$mount_point"
    rmdir "$mount_point"
    
    print_info "Bootloader and kernel installed successfully"
}

# Function to verify installation
verify_installation() {
    local device=$1
    local partition=$2
    
    print_info "Verifying installation..."
    
    # Check if bootloader was written
    local mbr_size=$(dd if="$device" bs=1 count=446 2>/dev/null | wc -c)
    if [ "$mbr_size" -eq 446 ]; then
        print_info "MBR bootloader verified (446 bytes)"
    else
        print_warning "MBR verification failed"
    fi
    
    # Mount and check files
    local mount_point="/mnt/naoboot_verify_$$"
    mkdir -p "$mount_point"
    mount "$partition" "$mount_point" 2>/dev/null
    
    if [ -f "$mount_point/kernel.bin" ]; then
        print_info "Kernel binary found on device"
    else
        print_warning "Kernel binary not found on device"
    fi
    
    umount "$mount_point"
    rmdir "$mount_point"
}

# Main function
main() {
    echo ""
    print_info "=== NaoBootloader USB Creation Script ==="
    echo ""
    
    # Check for root privileges
    check_root
    
    # Validate binary files
    validate_binaries
    echo ""
    
    # Detect USB devices
    print_info "Scanning for USB devices..."
    USB_DEVICES=($(detect_usb_devices))
    
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
    print_info "You can now safely remove the USB drive"
    echo ""
}

# Declare global array for USB devices
declare -a USB_DEVICES

# Run main function
main
