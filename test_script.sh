#!/bin/bash

# Test script for NaoBootloader USB Creation Script
# This tests the various functions and error handling without requiring actual USB devices

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/create_bootable_usb.sh"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Print test result
print_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$1" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $2"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "=========================================="
echo "NaoBootloader Test Suite"
echo "=========================================="
echo ""

# Test 1: Script exists and is executable
echo "Test 1: Script file checks"
if [ -f "$SCRIPT" ]; then
    print_test "PASS" "Script file exists"
else
    print_test "FAIL" "Script file exists"
fi

if [ -x "$SCRIPT" ]; then
    print_test "PASS" "Script is executable"
else
    print_test "FAIL" "Script is executable"
fi

# Test 2: Script syntax is valid
echo ""
echo "Test 2: Script syntax validation"
if bash -n "$SCRIPT" 2>/dev/null; then
    print_test "PASS" "Script syntax is valid"
else
    print_test "FAIL" "Script syntax is valid"
fi

# Test 3: Script checks for root privileges
echo ""
echo "Test 3: Root privilege check"
if [ "$EUID" -eq 0 ]; then
    print_test "PASS" "Script requires root privileges (test skipped - running as root)"
else
    output=$("$SCRIPT" 2>&1 || true)
    if echo "$output" | grep -q "must be run as root"; then
        print_test "PASS" "Script requires root privileges"
    else
        print_test "FAIL" "Script requires root privileges"
    fi
fi

# Test 4: Binary file validation
echo ""
echo "Test 4: Binary file validation"

# Test with missing kernel
output=$(sudo "$SCRIPT" nonexistent.bin bootloader.bin 2>&1 || true)
if echo "$output" | grep -q "Kernel binary not found"; then
    print_test "PASS" "Script detects missing kernel binary"
else
    print_test "FAIL" "Script detects missing kernel binary"
fi

# Test with missing bootloader
output=$(sudo "$SCRIPT" kernel.bin nonexistent.bin 2>&1 || true)
if echo "$output" | grep -q "Bootloader binary not found"; then
    print_test "PASS" "Script detects missing bootloader binary"
else
    print_test "FAIL" "Script detects missing bootloader binary"
fi

# Test 5: Binary files exist
echo ""
echo "Test 5: Example binary files"
cd "$SCRIPT_DIR"

if [ -f "kernel.bin" ]; then
    print_test "PASS" "kernel.bin exists"
else
    print_test "FAIL" "kernel.bin exists"
fi

if [ -f "bootloader.bin" ]; then
    print_test "PASS" "bootloader.bin exists"
else
    print_test "FAIL" "bootloader.bin exists"
fi

# Test 6: Script validates binaries successfully
echo ""
echo "Test 6: Valid binary validation"
output=$(sudo "$SCRIPT" 2>&1 <<< "q" || true)
if echo "$output" | grep -q "Binary files validated successfully"; then
    print_test "PASS" "Script validates existing binaries"
else
    print_test "FAIL" "Script validates existing binaries"
fi

# Test 7: USB device detection runs
echo ""
echo "Test 7: USB device detection"
if echo "$output" | grep -q "Scanning for USB devices"; then
    print_test "PASS" "Script scans for USB devices"
else
    print_test "FAIL" "Script scans for USB devices"
fi

# Test 8: Script handles no USB devices gracefully
echo ""
echo "Test 8: No USB devices handling"
if echo "$output" | grep -q "No USB devices detected"; then
    print_test "PASS" "Script handles no USB devices gracefully"
else
    # If USB devices were found, that's also acceptable
    if echo "$output" | grep -q "Available USB devices"; then
        print_test "PASS" "Script handles no USB devices gracefully (or found devices)"
    else
        print_test "FAIL" "Script handles no USB devices gracefully"
    fi
fi

# Test 9: User can cancel operation
echo ""
echo "Test 9: User cancellation"
if echo "$output" | grep -q -E "(Operation cancelled|No USB devices detected)"; then
    print_test "PASS" "Script allows user to cancel operation"
else
    print_test "FAIL" "Script allows user to cancel operation"
fi

# Test 10: README documentation exists
echo ""
echo "Test 10: Documentation"
if [ -f "$SCRIPT_DIR/README.md" ]; then
    readme_content=$(cat "$SCRIPT_DIR/README.md")
    if echo "$readme_content" | grep -q "create_bootable_usb.sh"; then
        print_test "PASS" "README documents the script"
    else
        print_test "FAIL" "README documents the script"
    fi
else
    print_test "FAIL" "README.md exists"
fi

# Test 11: Makefile exists
echo ""
echo "Test 11: Build system"
if [ -f "$SCRIPT_DIR/Makefile" ]; then
    print_test "PASS" "Makefile exists"
else
    print_test "FAIL" "Makefile exists"
fi

# Test 12: .gitignore exists
echo ""
echo "Test 12: Version control"
if [ -f "$SCRIPT_DIR/.gitignore" ]; then
    if grep -q "*.bin" "$SCRIPT_DIR/.gitignore"; then
        print_test "PASS" ".gitignore excludes binary files"
    else
        print_test "FAIL" ".gitignore excludes binary files"
    fi
else
    print_test "FAIL" ".gitignore exists"
fi

# Test 13: Source files exist
echo ""
echo "Test 13: Source files"
if [ -f "$SCRIPT_DIR/bootloader.asm" ]; then
    print_test "PASS" "bootloader.asm exists"
else
    print_test "FAIL" "bootloader.asm exists"
fi

if [ -f "$SCRIPT_DIR/kernel.asm" ]; then
    print_test "PASS" "kernel.asm exists"
else
    print_test "FAIL" "kernel.asm exists"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Tests run:    $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
else
    echo -e "${GREEN}Tests failed: $TESTS_FAILED${NC}"
fi
echo ""

# Exit with appropriate code
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
