#!/bin/bash

# NaoBootloader Virtual Drive Creation Script (macOS)
# Creates a virtual drive image for testing bootloader installation without needing a real USB drive

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VIRTUAL_DRIVE_SIZE="${1:-512m}"  # Size of virtual drive (default 512MB)
VIRTUAL_DRIVE_PATH="${2:-.}"     # Path where to store the image (default current directory)
DRIVE_IMAGE_NAME="virtual_usb_drive"
DRIVE_IMAGE_BASE="$VIRTUAL_DRIVE_PATH/$DRIVE_IMAGE_NAME"
DRIVE_IMAGE_PATH="$DRIVE_IMAGE_BASE.sparseimage"  # hdiutil adds .sparseimage automatically
MOUNT_POINT="/Volumes/NAOBOOT_VIRTUAL"

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

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to check if virtual drive already exists
check_existing_drive() {
    if [ -f "$DRIVE_IMAGE_PATH" ]; then
        print_warning "Virtual drive image already exists at: $DRIVE_IMAGE_PATH"
        read -p "Do you want to remove it and create a new one? (yes/no): " response
        if [ "$response" = "yes" ] || [ "$response" = "y" ]; then
            cleanup_existing_drive
        else
            print_info "Using existing virtual drive"
            return 1  # Use existing
        fi
    fi
    return 0  # Create new
}

# Function to cleanup existing drive
cleanup_existing_drive() {
    print_info "Cleaning up existing virtual drive..."
    
    # Unmount if mounted
    if [ -d "$MOUNT_POINT" ]; then
        diskutil unmount "$MOUNT_POINT" 2>/dev/null || true
    fi
    
    # Detach the image
    hdiutil detach "$DRIVE_IMAGE_PATH" 2>/dev/null || true
    
    # Wait a moment
    sleep 1
    
    # Remove the image file
    if [ -f "$DRIVE_IMAGE_PATH" ]; then
        rm -f "$DRIVE_IMAGE_PATH"
        print_info "Existing virtual drive removed"
    fi
}

# Function to create virtual disk image
create_disk_image() {
    print_info "Creating virtual disk image..."
    print_info "Size: $VIRTUAL_DRIVE_SIZE"
    print_info "Location: $DRIVE_IMAGE_BASE"
    
    # Create a sparse disk image
    # Note: hdiutil will add .sparse extension automatically
    hdiutil create -size "$VIRTUAL_DRIVE_SIZE" \
        -type SPARSE \
        -fs "MS-DOS" \
        -volname "NAOBOOT_VIRTUAL" \
        -imagekey zlib-level=9 \
        "$DRIVE_IMAGE_BASE" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create disk image"
        exit 1
    fi
    
    print_info "Virtual disk image created successfully"
}

# Function to attach and mount the virtual drive
attach_virtual_drive() {
    print_info "Attaching virtual drive..."
    
    # Attach the disk image and capture output
    local attach_output=$(hdiutil attach "$DRIVE_IMAGE_PATH" 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "hdiutil attach command failed"
        print_error "Output: $attach_output"
        exit 1
    fi
    
    # Extract device from hdiutil output (looks for /dev/disk* lines)
    local device=$(echo "$attach_output" | grep "/dev/disk" | head -1 | awk '{print $1}')
    
    if [ -z "$device" ]; then
        print_error "Failed to extract device path from hdiutil output"
        print_error "hdiutil output: $attach_output"
        exit 1
    fi
    
    print_info "Virtual drive attached as: $device"
    
    # Wait for mount to complete
    sleep 3
    
    # Verify it's mounted by checking if mount point exists
    if [ ! -d "$MOUNT_POINT" ]; then
        # Try alternative: check if device is in diskutil list
        if ! diskutil list "$device" &>/dev/null; then
            print_error "Virtual drive did not mount to $MOUNT_POINT"
            print_warning "Attempting to detach..."
            hdiutil detach "$device" 2>/dev/null || true
            exit 1
        fi
        print_warning "Mount point not found, but device is attached"
    fi
    
    echo "$device"
}

# Function to prepare the virtual drive
prepare_virtual_drive() {
    local device=$1
    
    print_info "Preparing virtual drive for use..."
    
    # The disk image is already formatted as MS-DOS/FAT32, but let's ensure it's properly set up
    # The filesystem is already MS-DOS, so we just need to verify it
    
    print_info "Virtual drive is ready at: $MOUNT_POINT"
    print_info "Device path: $device"
}

# Function to display usage information
display_usage_info() {
    echo ""
    print_header "Virtual Drive Information:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_info "Image File: $DRIVE_IMAGE_PATH"
    echo ""
    
    # Get the mounted device
    local device=$(diskutil info "$MOUNT_POINT" 2>/dev/null | grep "Device Node" | awk '{print $3}')
    if [ -n "$device" ]; then
        print_info "Device Path: $device"
    fi
    
    print_info "Mount Point: $MOUNT_POINT"
    echo ""
    print_info "You can now use this virtual drive with the bootloader installation script:"
    echo ""
    echo "  sudo ./macos_bootable.sh kernel.bin bootloader.bin $device"
    echo ""
    echo "Or run it interactively and select the virtual drive when prompted:"
    echo ""
    echo "  sudo ./macos_bootable.sh"
    echo ""
    print_header "To detach and cleanup the virtual drive, run:"
    echo ""
    echo "  sudo ./create_virtual_drive.sh --cleanup"
    echo ""
}

# Function to cleanup and detach virtual drive
cleanup() {
    print_info "Detaching virtual drive..."
    
    # Unmount if mounted
    if [ -d "$MOUNT_POINT" ]; then
        diskutil unmount "$MOUNT_POINT" 2>/dev/null || true
        sleep 1
    fi
    
    # Detach the image
    if [ -f "$DRIVE_IMAGE_PATH" ]; then
        hdiutil detach "$DRIVE_IMAGE_PATH" 2>/dev/null || true
        sleep 1
    fi
    
    print_info "Virtual drive detached"
}

# Function to list mounted virtual drives
list_virtual_drives() {
    echo ""
    print_header "Mounted Virtual Drives:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ ! -d "$MOUNT_POINT" ]; then
        print_info "No virtual drives currently mounted"
        return
    fi
    
    local device=$(diskutil info "$MOUNT_POINT" 2>/dev/null | grep "Device Node" | awk '{print $3}')
    print_info "Mount Point: $MOUNT_POINT"
    if [ -n "$device" ]; then
        print_info "Device: $device"
    fi
    
    echo ""
    print_info "Image File: $DRIVE_IMAGE_PATH"
    if [ -f "$DRIVE_IMAGE_PATH" ]; then
        local size=$(du -h "$DRIVE_IMAGE_PATH" | awk '{print $1}')
        print_info "Image Size: $size"
    fi
    echo ""
}

# Main function
main() {
    echo ""
    print_header "═══════════════════════════════════════════════════════════"
    print_header "  NaoBootloader Virtual Drive Creation Script (macOS)      "
    print_header "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Parse command line arguments
    if [ "$1" = "--cleanup" ] || [ "$1" = "-c" ]; then
        check_root
        cleanup
        exit 0
    elif [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
        list_virtual_drives
        exit 0
    elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        print_header "Usage:"
        echo "  sudo ./create_virtual_drive.sh [size] [path]"
        echo ""
        print_header "Options:"
        echo "  --cleanup, -c     Detach and cleanup the virtual drive"
        echo "  --list, -l        List mounted virtual drives"
        echo "  --help, -h        Show this help message"
        echo ""
        print_header "Arguments:"
        echo "  size              Size of virtual drive (default: 512m)"
        echo "                    Examples: 256m, 512m, 1g, 2g"
        echo "  path              Directory to store the image (default: current directory)"
        echo ""
        print_header "Examples:"
        echo "  sudo ./create_virtual_drive.sh"
        echo "  sudo ./create_virtual_drive.sh 1g"
        echo "  sudo ./create_virtual_drive.sh 512m /tmp"
        exit 0
    fi
    
    # Check for root privileges
    check_root
    
    # Validate size format
    if [[ ! "$VIRTUAL_DRIVE_SIZE" =~ ^[0-9]+[kmgt]?$ ]]; then
        print_error "Invalid size format: $VIRTUAL_DRIVE_SIZE"
        print_info "Valid formats: 256m, 512m, 1g, 2g, etc."
        exit 1
    fi
    
    # Create parent directory if needed
    if [ ! -d "$VIRTUAL_DRIVE_PATH" ]; then
        print_info "Creating directory: $VIRTUAL_DRIVE_PATH"
        mkdir -p "$VIRTUAL_DRIVE_PATH"
    fi
    
    # Check if we should create a new drive or use existing
    if ! check_existing_drive; then
        # Use existing drive
        print_info "Attaching existing virtual drive..."
        local device=$(attach_virtual_drive)
        display_usage_info
        exit 0
    fi
    
    # Create new virtual drive
    create_disk_image
    echo ""
    
    # Attach the virtual drive
    local device=$(attach_virtual_drive)
    echo ""
    
    # Prepare the virtual drive
    prepare_virtual_drive "$device"
    echo ""
    
    # Display usage information
    display_usage_info
}

# Run main function with all arguments
main "$@"
