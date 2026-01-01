#!/bin/bash

# NaoBootloader Virtual Drive Inspector Script (macOS)
# Displays information about the virtual drive including format, files, and usage

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Virtual drive configuration
VIRTUAL_DRIVE_PATH="${1:-.}"
DRIVE_IMAGE_NAME="virtual_usb_drive.sparseimage"
DRIVE_IMAGE_PATH="$VIRTUAL_DRIVE_PATH/$DRIVE_IMAGE_NAME"
MOUNT_POINT=""  # Will be detected dynamically

# Function to find the actual mount point of the virtual drive
find_mount_point() {
    # Try common mount point names
    if [ -d "/Volumes/NAOBOOT" ]; then
        MOUNT_POINT="/Volumes/NAOBOOT"
        return 0
    elif [ -d "/Volumes/NAOBOOT_VIRTUAL" ]; then
        MOUNT_POINT="/Volumes/NAOBOOT_VIRTUAL"
        return 0
    fi
    
    # If not found, try to find any volume mounted from the disk image
    local device=$(hdiutil info 2>/dev/null | grep -A5 "image-path: $DRIVE_IMAGE_PATH" | grep "^/dev/" | head -1 | awk '{print $1}')
    
    if [ -n "$device" ]; then
        # Find the partition (usually deviceX or deviceXsY)
        local partition="${device}s1"
        if [ ! -e "$partition" ]; then
            partition="${device}1"
        fi
        
        # Get mount point from diskutil
        local mount=$(diskutil info "$partition" 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}')
        if [ -n "$mount" ] && [ "$mount" != "(none)" ]; then
            MOUNT_POINT="$mount"
            return 0
        fi
    fi
    
    return 1
}

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

print_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Function to check if virtual drive exists
check_drive_exists() {
    if [ ! -f "$DRIVE_IMAGE_PATH" ]; then
        print_error "Virtual drive image not found: $DRIVE_IMAGE_PATH"
        print_info "Create one first with: sudo ./create_virtual_drive.sh"
        exit 1
    fi
}

# Function to attach virtual drive if not mounted
ensure_drive_mounted() {
    # First try to find if already mounted
    find_mount_point
    if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
        print_info "Virtual drive already mounted at: $MOUNT_POINT"
        return 0
    fi
    
    print_info "Virtual drive not mounted, attaching..."
    
    if hdiutil attach "$DRIVE_IMAGE_PATH" 2>/dev/null; then
        sleep 2
        
        # Try to find the new mount point
        find_mount_point
        if [ -n "$MOUNT_POINT" ]; then
            print_info "Virtual drive attached successfully at: $MOUNT_POINT"
            return 0
        else
            print_warning "Drive attached but could not find mount point"
            return 1
        fi
    else
        print_warning "Could not auto-mount drive"
        print_info "Try manually: hdiutil attach \"$DRIVE_IMAGE_PATH\""
        return 1
    fi
}

# Function to display image file information
show_image_info() {
    print_section "Image File Information"
    
    print_info "Path: $DRIVE_IMAGE_PATH"
    
    if [ -f "$DRIVE_IMAGE_PATH" ]; then
        local file_size=$(du -h "$DRIVE_IMAGE_PATH" | awk '{print $1}')
        print_info "File Size: $file_size"
        
        local creation_date=$(stat -f%Sm "$DRIVE_IMAGE_PATH" 2>/dev/null)
        print_info "Created: $creation_date"
        
        local modify_date=$(stat -f%Sm "$DRIVE_IMAGE_PATH" 2>/dev/null)
        print_info "Modified: $modify_date"
    fi
}

# Function to display mount status
show_mount_status() {
    print_section "Mount Status"
    
    if [ -d "$MOUNT_POINT" ]; then
        print_info "Status: ${GREEN}MOUNTED${NC}"
        print_info "Mount Point: $MOUNT_POINT"
        
        # Get device information
        local device=$(diskutil info "$MOUNT_POINT" 2>/dev/null | grep "Device Node" | awk -F': ' '{print $2}')
        if [ -n "$device" ]; then
            print_info "Device Node: $device"
        fi
        
        # Get filesystem info
        local filesystem=$(diskutil info "$MOUNT_POINT" 2>/dev/null | grep "Type (Bundle)" | awk -F': ' '{print $2}')
        if [ -z "$filesystem" ]; then
            filesystem=$(diskutil info "$MOUNT_POINT" 2>/dev/null | grep "File System Personality" | awk -F': ' '{print $2}')
        fi
        if [ -n "$filesystem" ]; then
            print_info "File System: $filesystem"
        fi
    else
        print_warning "Status: ${YELLOW}NOT MOUNTED${NC}"
        print_info "To mount the drive, you can attach it with:"
        echo "  hdiutil attach \"$DRIVE_IMAGE_PATH\""
    fi
}

# Function to display disk usage
show_disk_usage() {
    print_section "Disk Usage"
    
    if [ ! -d "$MOUNT_POINT" ]; then
        print_warning "Mount point not accessible"
        return
    fi
    
    # Total disk usage
    local total_usage=$(df -h "$MOUNT_POINT" 2>/dev/null | tail -1)
    if [ -n "$total_usage" ]; then
        echo "  $(echo "$total_usage" | awk '{printf "Filesystem: %s\nTotal Size: %s\nUsed: %s\nAvailable: %s\nUsage: %s\n", $1, $2, $3, $4, $5}')"
    fi
    
    # Used space by files on the drive
    local files_size=$(du -sh "$MOUNT_POINT" 2>/dev/null | awk '{print $1}')
    if [ -n "$files_size" ]; then
        print_info "Files Size: $files_size"
    fi
}

# Function to display files on the drive
show_files() {
    print_section "Files on Virtual Drive"
    
    if [ ! -d "$MOUNT_POINT" ]; then
        print_warning "Mount point not accessible"
        return
    fi
    
    if [ -z "$(ls -A "$MOUNT_POINT" 2>/dev/null)" ]; then
        print_info "Drive is empty"
        return
    fi
    
    echo "Contents of $MOUNT_POINT:"
    echo ""
    
    # Use ls with human-readable sizes and details
    ls -lh "$MOUNT_POINT" | tail -n +2 | while read line; do
        echo "  $line"
    done
    
    echo ""
    
    # Show detailed file listing with tree-like structure if tree is available
    if command -v tree &> /dev/null; then
        echo "Tree view:"
        tree "$MOUNT_POINT"
    else
        # Fallback to find command
        echo "Detailed file listing:"
        find "$MOUNT_POINT" -type f -exec ls -lh {} \; | while read line; do
            echo "  $line"
        done
    fi
}

# Function to display bootloader information if present
show_bootloader_info() {
    print_section "Bootloader Information"
    
    if [ ! -d "$MOUNT_POINT" ]; then
        print_warning "Mount point not accessible"
        return
    fi
    
    if [ -f "$MOUNT_POINT/bootloader.bin" ]; then
        print_info "Bootloader found: ${GREEN}bootloader.bin${NC}"
        local bootloader_size=$(stat -f%z "$MOUNT_POINT/bootloader.bin" 2>/dev/null)
        print_info "Size: $bootloader_size bytes"
        if [ "$bootloader_size" -gt 446 ]; then
            print_warning "Bootloader is larger than MBR size (446 bytes)"
        else
            print_info "Bootloader fits in MBR (${GREEN}OK${NC})"
        fi
    else
        print_warning "No bootloader.bin found on drive"
    fi
    
    if [ -f "$MOUNT_POINT/kernel.bin" ]; then
        print_info "Kernel found: ${GREEN}kernel.bin${NC}"
        local kernel_size=$(stat -f%z "$MOUNT_POINT/kernel.bin" 2>/dev/null)
        print_info "Size: $kernel_size bytes"
    else
        print_warning "No kernel.bin found on drive"
    fi
}

# Function to show mount/unmount options
show_mount_options() {
    print_section "Mount/Unmount Options"
    
    if [ -d "$MOUNT_POINT" ]; then
        echo "To unmount the drive, run:"
        echo "  sudo hdiutil detach \"$MOUNT_POINT\""
        echo ""
        echo "Or:"
        echo "  diskutil unmount \"$MOUNT_POINT\""
    else
        echo "To mount the drive, run:"
        echo "  hdiutil attach \"$DRIVE_IMAGE_PATH\""
        echo ""
        echo "Or use the virtual drive creation script:"
        echo "  sudo ./create_virtual_drive.sh"
    fi
}

# Main function
main() {
    echo ""
    print_header "═══════════════════════════════════════════════════════════"
    print_header "  NaoBootloader Virtual Drive Inspector (macOS)            "
    print_header "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Check for --help
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "Usage: $0 [path]"
        echo ""
        echo "Options:"
        echo "  path       Directory where virtual drive image is stored (default: current directory)"
        echo "  --help, -h Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                    # Inspect in current directory"
        echo "  $0 /tmp               # Inspect in /tmp directory"
        exit 0
    fi
    
    # Check if drive exists
    check_drive_exists
    
    # Ensure drive is mounted
    ensure_drive_mounted
    echo ""
    
    # Display all information
    show_image_info
    show_mount_status
    show_disk_usage
    show_files
    show_bootloader_info
    show_mount_options
    
    echo ""
}

# Run main function
main "$@"
