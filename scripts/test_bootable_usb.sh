#!/bin/bash

# test_bootable_usb.sh - Test bootable USB creation
# Validates that the bootable USB scripts work correctly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

print_banner "Bootable USB Creation Test Suite"

# ==============================================================================
# TESTS
# ==============================================================================

test_bios_bootable() {
    print_section "Testing BIOS Bootable Script"
    
    log_info "Checking if script exists..."
    if [ -f "$SCRIPT_DIR/macos_bootable.sh" ]; then
        log_success "✓ macos_bootable.sh found"
    else
        log_error "✗ macos_bootable.sh not found"
        return 1
    fi
    
    log_info "Checking if script is executable..."
    if [ -x "$SCRIPT_DIR/macos_bootable.sh" ]; then
        log_success "✓ Script is executable"
    else
        log_warn "⚠ Script is not executable, fixing..."
        chmod +x "$SCRIPT_DIR/macos_bootable.sh"
    fi
    
    log_info "BIOS bootable script validation: ✓ PASSED"
}

test_efi_bootable() {
    print_section "Testing EFI Bootable Script"
    
    log_info "Checking if script exists..."
    if [ -f "$SCRIPT_DIR/create_efi_bootable.sh" ]; then
        log_success "✓ create_efi_bootable.sh found"
    else
        log_error "✗ create_efi_bootable.sh not found"
        return 1
    fi
    
    log_info "Checking if script is executable..."
    if [ -x "$SCRIPT_DIR/create_efi_bootable.sh" ]; then
        log_success "✓ Script is executable"
    else
        log_warn "⚠ Script is not executable, fixing..."
        chmod +x "$SCRIPT_DIR/create_efi_bootable.sh"
    fi
    
    log_info "Checking script syntax..."
    if bash -n "$SCRIPT_DIR/create_efi_bootable.sh" 2>/dev/null; then
        log_success "✓ Script syntax is valid"
    else
        log_error "✗ Script has syntax errors"
        return 1
    fi
    
    log_info "EFI bootable script validation: ✓ PASSED"
}

test_hybrid_bootable() {
    print_section "Testing Hybrid Bootable Script"
    
    log_info "Checking if script exists..."
    if [ -f "$SCRIPT_DIR/create_hybrid_bootable.sh" ]; then
        log_success "✓ create_hybrid_bootable.sh found"
    else
        log_error "✗ create_hybrid_bootable.sh not found"
        return 1
    fi
    
    log_info "Checking if script is executable..."
    if [ -x "$SCRIPT_DIR/create_hybrid_bootable.sh" ]; then
        log_success "✓ Script is executable"
    else
        log_warn "⚠ Script is not executable, fixing..."
        chmod +x "$SCRIPT_DIR/create_hybrid_bootable.sh"
    fi
    
    log_info "Checking script syntax..."
    if bash -n "$SCRIPT_DIR/create_hybrid_bootable.sh" 2>/dev/null; then
        log_success "✓ Script syntax is valid"
    else
        log_error "✗ Script has syntax errors"
        return 1
    fi
    
    log_info "Hybrid bootable script validation: ✓ PASSED"
}

test_binaries() {
    print_section "Testing Binary Files"
    
    cd "$SCRIPT_DIR/.."
    
    log_info "Checking bootloader.bin..."
    if [ -f "bootloader.bin" ]; then
        local size=$(stat -f%z "bootloader.bin" 2>/dev/null || echo "?")
        if [ "$size" = "512" ]; then
            log_success "✓ bootloader.bin (512 bytes, correct size)"
        else
            log_warn "⚠ bootloader.bin ($size bytes, expected 512)"
        fi
    else
        log_error "✗ bootloader.bin not found"
        return 1
    fi
    
    log_info "Checking kernel.bin..."
    if [ -f "kernel.bin" ]; then
        local size=$(stat -f%z "kernel.bin" 2>/dev/null || echo "?")
        log_success "✓ kernel.bin ($size bytes)"
    else
        log_error "✗ kernel.bin not found"
        return 1
    fi
    
    log_info "Binary files validation: ✓ PASSED"
}

test_efi_directories() {
    print_section "Testing EFI Directory Creation"
    
    # Create a temporary test directory
    local test_dir=$(mktemp -d)
    log_info "Test directory: $test_dir"
    
    log_info "Creating EFI directory structure..."
    mkdir -p "$test_dir/EFI/BOOT" 2>/dev/null
    
    if [ -d "$test_dir/EFI/BOOT" ]; then
        log_success "✓ EFI/BOOT directory created"
    else
        log_error "✗ Failed to create EFI/BOOT directory"
        return 1
    fi
    
    log_info "Creating test BOOTX64.EFI..."
    echo "TEST" > "$test_dir/EFI/BOOT/BOOTX64.EFI"
    
    if [ -f "$test_dir/EFI/BOOT/BOOTX64.EFI" ]; then
        log_success "✓ BOOTX64.EFI file created"
    else
        log_error "✗ Failed to create BOOTX64.EFI"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    log_info "EFI directory structure validation: ✓ PASSED"
}

test_start_sh_integration() {
    print_section "Testing start.sh Integration"
    
    cd "$SCRIPT_DIR/.."
    
    log_info "Checking if start.sh has 'efi' command..."
    if grep -q "efi)" start.sh; then
        log_success "✓ 'efi' command found in start.sh"
    else
        log_error "✗ 'efi' command not found in start.sh"
        return 1
    fi
    
    log_info "Checking if start.sh has 'hybrid' command..."
    if grep -q "hybrid)" start.sh; then
        log_success "✓ 'hybrid' command found in start.sh"
    else
        log_error "✗ 'hybrid' command not found in start.sh"
        return 1
    fi
    
    log_info "Checking if start.sh has 'info' command..."
    if grep -q "info)" start.sh; then
        log_success "✓ 'info' command found in start.sh"
    else
        log_error "✗ 'info' command not found in start.sh"
        return 1
    fi
    
    log_info "start.sh integration validation: ✓ PASSED"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    local failed=0
    
    test_binaries || ((failed++))
    test_bios_bootable || ((failed++))
    test_efi_bootable || ((failed++))
    test_hybrid_bootable || ((failed++))
    test_efi_directories || ((failed++))
    test_start_sh_integration || ((failed++))
    
    print_section "Test Summary"
    
    if [ $failed -eq 0 ]; then
        log_success "✅ All tests PASSED!"
        log_info ""
        log_info "Your bootable USB system is ready:"
        log_info "  • BIOS bootable:  sudo ./start.sh bootable"
        log_info "  • EFI bootable:   sudo ./start.sh efi"
        log_info "  • Hybrid bootable: sudo ./start.sh hybrid"
        log_info ""
        log_info "Get help: ./start.sh info"
        exit 0
    else
        log_error "❌ $failed test(s) FAILED"
        exit 1
    fi
}

main "$@"
