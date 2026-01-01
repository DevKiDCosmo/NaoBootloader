#!/bin/bash

# NaoBootloader Ghost Disk Cleanup Script (macOS)
# Removes orphaned disk images that are mounted but point to non-existent files

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to find all ghost disk devices
find_ghost_disk_devices() {
    # Get all disk images from hdiutil
    local ghost_devices=()
    
    # Use hdiutil info to get all attached images and their devices
    local hdiutil_output=$(hdiutil info 2>/dev/null)
    
    # Parse the output to find orphaned disks
    echo "$hdiutil_output" | grep -E "^/dev/disk" | while read device rest; do
        # Get the image path for this device
        local image_path=$(echo "$hdiutil_output" | grep -A20 "^$device" | grep "image-path:" | head -1 | awk -F': ' '{print $2}')
        
        if [ -n "$image_path" ] && [ ! -f "$image_path" ]; then
            echo "$device"
        fi
    done
}

# Function to get all mounted disk image devices
get_all_disk_image_devices() {
    # List all /dev/disk* devices that are mounted and check if they're disk images
    diskutil list 2>/dev/null | grep "^/dev/disk" | awk '{print $1}' | while read device; do
        # Check if this device is a disk image by examining its properties
        local is_image=$(diskutil info "$device" 2>/dev/null | grep -i "virtual" | head -1)
        if [ -n "$is_image" ]; then
            echo "$device"
        fi
    done
}

# Function to check if disk image file exists
check_image_exists() {
    local image_path="$1"
    
    if [ -f "$image_path" ]; then
        return 0  # File exists
    else
        return 1  # File does not exist
    fi
}

# Function to check if device is a disk image (virtual)
is_disk_image() {
    local device="$1"
    
    local device_info=$(diskutil info "$device" 2>/dev/null)
    
    if echo "$device_info" | grep -qi "virtual\|disk image\|iso\|sparseimage"; then
        return 0  # Is disk image
    fi
    
    return 1  # Not a disk image
}

# Function to list ghost disks
list_ghost_disks() {
    print_section "Scanning for Ghost Disks"
    
    print_info "Checking disk image devices..."
    echo ""
    
    # Get all disk devices
    diskutil list 2>/dev/null | grep "^/dev/disk" | awk '{print $1}' | while read device; do
        if [ -z "$device" ]; then
            continue
        fi
        
        # Try to get image path from hdiutil
        local image_path=$(hdiutil info 2>/dev/null | grep -A20 "^$device" | grep "image-path:" | head -1 | awk -F': ' '{print $2}')
        
        if [ -z "$image_path" ] || [ ! -f "$image_path" ]; then
            # No image path or file doesn't exist - it's a ghost
            echo -e "${RED}[GHOST]${NC} Device: $device"
            if [ -n "$image_path" ]; then
                echo "         Image: $image_path (FILE MISSING)"
            else
                echo "         Image: (no backing file)"
            fi
            echo ""
        fi
    done
    
    echo ""
    echo "To remove all ghost disks, run:"
    echo "  sudo $0 --clean"
}

# Function to remove a specific ghost disk
remove_ghost_disk() {
    local device="$1"
    
    print_info "Attempting to detach: $device"
    
    # Try to detach the device directly
    if hdiutil detach "$device" 2>/dev/null; then
        print_info "Successfully detached: $device"
        return 0
    else
        # Try force detach
        print_warning "Normal detach failed, attempting force detach..."
        if hdiutil detach -force "$device" 2>/dev/null; then
            print_info "Successfully force detached: $device"
            return 0
        else
            print_error "Failed to detach: $device"
            return 1
        fi
    fi
}

# Function to clean all ghost disks
clean_all_ghost_disks() {
    print_section "Removing All Ghost Disks"
    
    local success_count=0
    local fail_count=0
    local total_count=0
    
    # Get all disk devices
    diskutil list 2>/dev/null | grep "^/dev/disk" | awk '{print $1}' | while read device; do
        if [ -z "$device" ]; then
            continue
        fi
        
        # Try to get image path from hdiutil
        local image_path=$(hdiutil info 2>/dev/null | grep -A20 "^$device" | grep "image-path:" | head -1 | awk -F': ' '{print $2}')
        
        # If no image path or file doesn't exist, it's a ghost
        if [ -z "$image_path" ] || [ ! -f "$image_path" ]; then
            total_count=$((total_count + 1))
            
            if remove_ghost_disk "$device"; then
                success_count=$((success_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
            echo ""
        fi
    done
    
    echo ""
    print_info "Cleanup Results:"
    print_info "  Processed: $total_count ghost disk(s)"
    print_info "  Successfully removed: $success_count"
    if [ $fail_count -gt 0 ]; then
        print_error "  Failed to remove: $fail_count"
    fi
    
    if [ $fail_count -eq 0 ] && [ $total_count -gt 0 ]; then
        echo ""
        print_info "All ghost disks removed successfully!"
    elif [ $total_count -eq 0 ]; then
        print_info "No ghost disks found to remove"
    fi
}

# Function to interactively remove ghost disks
interactive_cleanup() {
    print_section "Interactive Ghost Disk Cleanup"
    
    local counter=0
    
    # Get all disk devices
    diskutil list 2>/dev/null | grep "^/dev/disk" | awk '{print $1}' | while read device; do
        if [ -z "$device" ]; then
            continue
        fi
        
        # Try to get image path from hdiutil
        local image_path=$(hdiutil info 2>/dev/null | grep -A20 "^$device" | grep "image-path:" | head -1 | awk -F': ' '{print $2}')
        
        # If no image path or file doesn't exist, it's a ghost
        if [ -z "$image_path" ] || [ ! -f "$image_path" ]; then
            counter=$((counter + 1))
            
            echo -e "${RED}[GHOST $counter]${NC} $device"
            if [ -n "$image_path" ]; then
                echo "Image: $image_path"
            else
                echo "Image: (no backing file)"
            fi
            
            read -p "Remove this ghost disk? (yes/no): " response
            echo ""
            
            if [ "$response" = "yes" ] || [ "$response" = "y" ]; then
                remove_ghost_disk "$device"
            else
                print_info "Skipped"
            fi
            echo ""
        fi
    done
}

# Main function
main() {
    echo ""
    print_header "═══════════════════════════════════════════════════════════"
    print_header "  NaoBootloader Ghost Disk Cleanup Script (macOS)         "
    print_header "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Parse command line arguments
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "Usage: sudo $0 [command]"
        echo ""
        echo "Commands:"
        echo "  (no args)    List ghost disks"
        echo "  --clean, -c  Automatically remove all ghost disks"
        echo "  --interactive, -i  Interactively remove ghost disks (one by one)"
        echo "  --help, -h   Show this help message"
        echo ""
        echo "Examples:"
        echo "  sudo $0              # Scan and list ghost disks"
        echo "  sudo $0 --clean      # Remove all ghost disks automatically"
        echo "  sudo $0 -i           # Remove ghost disks one by one"
        exit 0
    fi
    
    # Check for root privileges
    check_root
    
    # Parse command
    case "$1" in
        --clean|-c)
            list_ghost_disks
            if [ $? -eq 0 ]; then
                echo ""
                read -p "Are you sure you want to remove all ghost disks? (yes/no): " confirm
                if [ "$confirm" = "yes" ] || [ "$confirm" = "y" ]; then
                    clean_all_ghost_disks
                else
                    print_info "Cleanup cancelled"
                fi
            fi
            ;;
        --interactive|-i)
            list_ghost_disks
            if [ $? -eq 0 ]; then
                echo ""
                interactive_cleanup
            fi
            ;;
        *)
            # Default: just list
            if list_ghost_disks; then
                echo ""
                echo "To remove these ghost disks, run:"
                echo "  sudo $0 --clean"
                echo ""
                echo "Or interactively:"
                echo "  sudo $0 --interactive"
            fi
            ;;
    esac
    
    echo ""
}

# Run main function
main "$@"
