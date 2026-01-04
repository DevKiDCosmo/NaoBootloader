#!/bin/bash

# start.sh - Main entry point for NaoBootloader project
# This script provides a unified interface for all bootloader operations

# ==============================================================================
# SETUP
# ==============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Source the library
source "$SCRIPT_DIR/scripts/lib.sh"

# ==============================================================================
# CONFIGURATION
# ==============================================================================

BOOTLOADER_BIN="$PROJECT_ROOT/bootloader.bin"
STAGE2_BIN="$PROJECT_ROOT/stage2.bin"
KERNEL_BIN="$PROJECT_ROOT/kernel.bin"

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

show_help() {
    print_banner "NaoBootloader - Boot Management System"
    
    echo -e "${COLOR_BRIGHT_WHITE}USAGE:${COLOR_RESET}"
    echo "    ./start.sh [COMMAND] [OPTIONS]"
    echo ""
    echo -e "${COLOR_BRIGHT_WHITE}COMMANDS:${COLOR_RESET}"
    echo -e "    ${COLOR_BRIGHT_GREEN}build${COLOR_RESET}           Build all bootloader components"
    echo -e "    ${COLOR_BRIGHT_GREEN}clean${COLOR_RESET}           Clean build artifacts"
    echo -e "    ${COLOR_BRIGHT_GREEN}test${COLOR_RESET}            Run individual component tests (QEMU)"
    echo -e "    ${COLOR_BRIGHT_GREEN}slow${COLOR_RESET}            Run slow-motion tests (50MHz - for debugging)"
    echo -e "    ${COLOR_BRIGHT_GREEN}qemu${COLOR_RESET}            Quick QEMU test with all components"
    echo -e "    ${COLOR_BRIGHT_GREEN}virtual${COLOR_RESET}         Create/manage virtual test drives"
    echo -e "    ${COLOR_BRIGHT_GREEN}bootable${COLOR_RESET}        Create BIOS bootable USB drive (macOS)"
    echo -e "    ${COLOR_BRIGHT_GREEN}efi${COLOR_RESET}             Create EFI bootable USB drive (modern systems)"
    echo -e "    ${COLOR_BRIGHT_GREEN}hybrid${COLOR_RESET}          Create hybrid bootable USB (BIOS + EFI)"
    echo -e "    ${COLOR_BRIGHT_GREEN}info${COLOR_RESET}            Show bootable media options and guide"
    echo -e "    ${COLOR_BRIGHT_GREEN}inspect${COLOR_RESET}         Inspect virtual drive contents"
    echo -e "    ${COLOR_BRIGHT_GREEN}cleanup${COLOR_RESET}         Clean up ghost disk images"
    echo -e "    ${COLOR_BRIGHT_GREEN}status${COLOR_RESET}          Show project status"
    echo -e "    ${COLOR_BRIGHT_GREEN}help${COLOR_RESET}            Show this help message"
    echo ""
    echo -e "${COLOR_BRIGHT_WHITE}EXAMPLES:${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}./start.sh build${COLOR_RESET}              # Build all components"
    echo -e "    ${COLOR_CYAN}./start.sh test${COLOR_RESET}               # Run interactive tests"
    echo -e "    ${COLOR_CYAN}./start.sh slow${COLOR_RESET}               # Run slow-motion debugging"
    echo -e "    ${COLOR_CYAN}./start.sh qemu${COLOR_RESET}               # Quick QEMU test"
    echo -e "    ${COLOR_CYAN}./start.sh virtual 1g${COLOR_RESET}         # Create 1GB virtual drive"
    echo -e "    ${COLOR_CYAN}./start.sh bootable${COLOR_RESET}           # Create BIOS bootable USB (requires sudo)"
    echo -e "    ${COLOR_CYAN}./start.sh efi${COLOR_RESET}                # Create EFI bootable USB (requires sudo)"
    echo -e "    ${COLOR_CYAN}./start.sh hybrid${COLOR_RESET}             # Create hybrid USB (BIOS+EFI, requires sudo)"
    echo -e "    ${COLOR_CYAN}./start.sh status${COLOR_RESET}             # Show build status"
    echo ""
    echo -e "${COLOR_BRIGHT_WHITE}TESTING:${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}./start.sh test${COLOR_RESET}               # Interactive test menu"
    echo -e "    ${COLOR_CYAN}./start.sh test 1${COLOR_RESET}             # Test Stage 1 only"
    echo -e "    ${COLOR_CYAN}./start.sh test 2${COLOR_RESET}             # Test Stage 1 + Stage 2"
    echo -e "    ${COLOR_CYAN}./start.sh test 3${COLOR_RESET}             # Test complete system"
    echo ""
    echo -e "${COLOR_BRIGHT_WHITE}ENVIRONMENT:${COLOR_RESET}"
    echo -e "    Set ${COLOR_YELLOW}CURRENT_LOG_LEVEL${COLOR_RESET} to control verbosity:"
    echo "        0 = TRACE, 1 = DEBUG, 2 = INFO, 3 = WARN, 4 = ERROR, 5 = FATAL"
    echo ""
}

show_status() {
    print_section "Project Status"
    
    log_info "Build artifacts:"
    
    if file_exists "$BOOTLOADER_BIN"; then
        log_success "bootloader.bin ($(get_file_size "$BOOTLOADER_BIN"))"
    else
        log_failure "bootloader.bin (not built)"
    fi
    
    if file_exists "$STAGE2_BIN"; then
        log_success "stage2.bin ($(get_file_size "$STAGE2_BIN"))"
    else
        log_failure "stage2.bin (not built)"
    fi
    
    if file_exists "$KERNEL_BIN"; then
        log_success "kernel.bin ($(get_file_size "$KERNEL_BIN"))"
    else
        log_failure "kernel.bin (not built)"
    fi
    
    echo ""
    log_info "Available scripts:"
    for script in "$SCRIPT_DIR"/scripts/*.sh; do
        [ -f "$script" ] && echo "  - $(basename "$script")"
    done
    
    echo ""
    log_info "Testing tools:"
    if command_exists qemu-system-x86_64; then
        log_success "QEMU installed"
    else
        log_failure "QEMU not installed (run: brew install qemu)"
    fi
    
    if command_exists nasm; then
        log_success "NASM installed ($(nasm -v))"
    else
        log_failure "NASM not installed (run: brew install nasm)"
    fi
}

# ==============================================================================
# COMMAND HANDLERS
# ==============================================================================

cmd_build() {
    print_section "Building NaoBootloader"
    
    if ! command_exists nasm; then
        log_error "NASM not found. Install with: brew install nasm"
        return 1
    fi
    
    run_command "Cleaning previous build" make clean
    run_command "Building bootloader components" make
    
    echo ""
    show_status
}

cmd_clean() {
    print_section "Cleaning Build Artifacts"
    
    run_command "Running make clean" make clean
    run_command "Removing test images" rm -f "$PROJECT_ROOT"/*.img
    
    log_success "Clean complete"
}

cmd_test() {
    local test_num="$1"
    
    print_section "Running Bootloader Tests"
    
    if [ -z "$test_num" ]; then
        # Interactive mode
        bash "$SCRIPT_DIR/scripts/test_individual.sh"
    else
        # Direct test
        echo "$test_num" | bash "$SCRIPT_DIR/scripts/test_individual.sh"
    fi
}

cmd_qemu() {
    print_section "Quick QEMU Test"
    
    bash "$SCRIPT_DIR/scripts/test_qemu.sh"
}

cmd_virtual() {
    local size="${1:-1g}"
    
    print_section "Virtual Drive Management"
    
    if [ "$size" = "--cleanup" ] || [ "$size" = "--list" ] || [ "$size" = "--help" ]; then
        bash "$SCRIPT_DIR/scripts/create_virtual_drive.sh" "$size"
    else
        log_info "Creating virtual drive with size: $size"
        bash "$SCRIPT_DIR/scripts/create_virtual_drive.sh" "$size"
    fi
}

cmd_bootable() {
    print_section "Create BIOS Bootable Drive"
    
    if ! is_root; then
        log_warn "This command requires sudo privileges"
        log_info "Run: sudo ./start.sh bootable"
        return 1
    fi
    
    bash "$SCRIPT_DIR/scripts/macos_bootable.sh"
}

cmd_efi() {
    print_section "Create EFI Bootable Drive"
    
    if ! is_root; then
        log_warn "This command requires sudo privileges"
        log_info "Run: sudo ./start.sh efi"
        return 1
    fi
    
    bash "$SCRIPT_DIR/scripts/create_efi_bootable.sh"
}

cmd_hybrid() {
    print_section "Create Hybrid Bootable Drive (BIOS + EFI)"
    
    if ! is_root; then
        log_warn "This command requires sudo privileges"
        log_info "Run: sudo ./start.sh hybrid"
        return 1
    fi
    
    bash "$SCRIPT_DIR/scripts/create_hybrid_bootable.sh"
}

cmd_info() {
    bash "$SCRIPT_DIR/scripts/bootable_info.sh"
}

cmd_inspect() {
    print_section "Inspect Virtual Drive"
    
    if ! is_root; then
        log_warn "This command requires sudo privileges"
        log_info "Run: sudo ./start.sh inspect"
        return 1
    fi
    
    bash "$SCRIPT_DIR/scripts/inspect_virtual_drive.sh"
}

cmd_cleanup() {
    print_section "Cleanup Ghost Disks"
    
    if ! is_root; then
        log_warn "This command requires sudo privileges"
        log_info "Run: sudo ./start.sh cleanup"
        return 1
    fi
    
    bash "$SCRIPT_DIR/scripts/cleanup_ghost_disks.sh" --clean
}

cmd_slow() {
    print_section "Slow-Motion Bootloader Test"
    
    bash "$SCRIPT_DIR/scripts/test_slow.sh"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        build)
            cmd_build "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        test|--test)
            cmd_test "$@"
            ;;
        slow)
            cmd_slow "$@"
            ;;
        qemu)
            cmd_qemu "$@"
            ;;
        virtual)
            cmd_virtual "$@"
            ;;
        bootable)
            cmd_bootable "$@"
            ;;
        efi)
            cmd_efi "$@"
            ;;
        hybrid)
            cmd_hybrid "$@"
            ;;
        info)
            cmd_info "$@"
            ;;
        inspect)
            cmd_inspect "$@"
            ;;
        cleanup)
            cmd_cleanup "$@"
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
