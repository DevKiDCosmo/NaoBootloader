#!/bin/bash

# bootable_modes_explained.sh - Erklärung der Bootable-Modi

cat << 'EOF'

================================================================================
                   BOOTABLE USB CREATION - THREE MODES
================================================================================

Your bootloader project now supports THREE different ways to create bootable
USB drives, each optimized for different systems and use cases.

================================================================================
                            MODE COMPARISON TABLE
================================================================================

FEATURE              │  BIOS          │  EFI           │  HYBRID
─────────────────────┼────────────────┼────────────────┼──────────────────
Partition Table      │  MBR           │  GPT           │  GPT (2 partitions)
Boot Systems         │  Legacy        │  UEFI/Modern   │  Both
Number of Partitions │  1             │  1             │  2
Space Used           │  Minimal       │  Minimal       │  200MB + rest
EFI Directory        │  No            │  Yes           │  Yes
BIOS Boot Sector     │  Yes (MBR)     │  No            │  Yes
Kernel Location      │  In partition  │  In partition  │  Both partitions
─────────────────────┼────────────────┼────────────────┼──────────────────
MacBooks             │  ❌ No         │  ✅ Yes        │  ✅ Yes
Legacy PCs (pre-2010)│  ✅ Yes        │  ❌ No         │  ✅ Yes
Modern PCs (2010+)   │  ❌ No         │  ✅ Yes        │  ✅ Yes
Recommended          │  Specific      │  Specific      │  ✅ BEST

================================================================================
                           1. BIOS BOOTABLE MODE
================================================================================

Command:  sudo ./start.sh bootable
Use for:  Legacy systems (BIOS only, pre-2010s)

How it works:
  • Single FAT32 partition (MBR)
  • bootloader.bin written to disk sector 0 (MBR boot sector)
  • kernel.bin stored in partition root
  • No EFI partition or directory structure

File Layout:
  /dev/disk4s1 (single partition)
  ├── bootloader.bin
  ├── kernel.bin
  └── README.txt

Advantages:
  ✓ Simple, minimal setup
  ✓ Maximum compatibility with old BIOS systems
  ✓ Fast partition creation

Disadvantages:
  ✗ Won't boot on modern UEFI systems
  ✗ Won't boot on MacBooks
  ✗ Not suitable for mixed hardware

Best for:
  • DOS/Windows 98/XP machines
  • Old laptops (2000-2005)
  • Specific embedded systems

================================================================================
                           2. EFI BOOTABLE MODE
================================================================================

Command:  sudo ./start.sh efi
Use for:  Modern UEFI systems (EFI only)

How it works:
  • Single partition with GPT partition table
  • EFI directory structure created: EFI/BOOT/
  • bootloader.bin renamed to BOOTX64.EFI (EFI firmware looks for this)
  • kernel.bin stored alongside BOOTX64.EFI
  • UEFI firmware calls EFI/BOOT/BOOTX64.EFI automatically

File Layout:
  /dev/disk4s1 (GPT partition)
  ├── EFI/
  │   └── BOOT/
  │       └── BOOTX64.EFI  ← EFI firmware boots this
  ├── kernel.bin
  └── README_EFI.txt

Advantages:
  ✓ Native boot on MacBooks (Intel and Apple Silicon)
  ✓ Standard UEFI boot on modern PCs
  ✓ Professional/Modern approach
  ✓ Secure Boot compatible

Disadvantages:
  ✗ Won't boot on legacy BIOS systems
  ✗ More complex setup
  ✗ Requires GPT partition table

Best for:
  • MacBooks (Intel 2013+, Apple Silicon 2020+)
  • Modern Windows 10/11 PCs
  • Linux with EFI bootloader
  • Professional deployments

================================================================================
                           3. HYBRID BOOTABLE MODE
================================================================================

Command:  sudo ./start.sh hybrid
Use for:  UNIVERSAL - works on ANY computer

How it works:
  • Two GPT partitions:
    1. EFI partition (200MB) - contains EFI/BOOT/BOOTX64.EFI
    2. Boot partition (rest) - contains BIOS bootloader.bin
  • MBR boot sector written to disk for BIOS systems
  • EFI firmware uses EFI partition → EFI/BOOT/BOOTX64.EFI
  • BIOS firmware uses disk boot sector → bootloader.bin
  • Both systems can coexist on same USB

File Layout:
  /dev/disk4s1 (EFI Partition, 200MB, GPT type EFI)
  ├── EFI/
  │   └── BOOT/
  │       └── BOOTX64.EFI
  ├── kernel.bin
  └── EFI_INFO.txt

  /dev/disk4s2 (Boot Partition, remaining, GPT type Linux)
  ├── bootloader.bin
  ├── kernel.bin
  └── README.txt

  /dev/disk4 (Disk MBR boot sector)
  └── Contains bootloader.bin for BIOS boot

Advantages:
  ✓ WORKS ON EVERY COMPUTER
  ✓ Single USB boots both BIOS and EFI systems
  ✓ Maximum compatibility
  ✓ Professional solution
  ✓ No need to recreate USB for different systems

Disadvantages:
  ✗ More complex setup
  ✗ Uses 200MB for EFI partition (might be wasted on BIOS-only systems)
  ✗ Slightly slower partition creation

Best for:
  ✅ GENERAL USE - CREATE ONE USB FOR EVERYTHING
  ✅ When you don't know target system
  ✅ Portable solutions
  ✅ Production environments
  ✅ RECOMMENDED FOR MOST USERS

================================================================================
                         DECISION FLOWCHART
================================================================================

  Do you know what system you're booting?
  │
  ├─→ Yes, it's OLD (pre-2010 BIOS only)
  │   └─→ Use BIOS mode
  │       $ sudo ./start.sh bootable
  │
  ├─→ Yes, it's MODERN (MacBook or UEFI PC)
  │   └─→ Use EFI mode
  │       $ sudo ./start.sh efi
  │
  └─→ No / Need to boot multiple systems
      └─→ Use HYBRID mode (RECOMMENDED)
          $ sudo ./start.sh hybrid

================================================================================
                        TECHNICAL DETAILS
================================================================================

BIOS Boot Process:
  1. Firmware reads MBR from disk sector 0
  2. MBR contains bootloader.bin code
  3. Bootloader executes, loads kernel
  4. Kernel takes control

EFI Boot Process:
  1. Firmware looks for GPT partition table
  2. Firmware searches for EFI System Partition
  3. Firmware looks for /EFI/BOOT/BOOTX64.EFI
  4. Bootloader executes, loads kernel
  5. Kernel takes control

Hybrid Boot Process (BIOS):
  1. Legacy firmware ignores GPT, uses MBR
  2. MBR boot sector contains bootloader.bin
  3. Bootloader executes, loads kernel
  4. Kernel takes control

Hybrid Boot Process (EFI):
  1. EFI firmware reads GPT partition table
  2. Firmware finds EFI partition (partition 1)
  3. Firmware executes EFI/BOOT/BOOTX64.EFI
  4. Bootloader executes, loads kernel
  5. Kernel takes control

================================================================================
                         QUICK REFERENCE
================================================================================

Build first:
  $ ./start.sh build

Then create USB:
  $ sudo ./start.sh bootable    # BIOS only
  $ sudo ./start.sh efi         # EFI only
  $ sudo ./start.sh hybrid      # Both (RECOMMENDED)

Get detailed guide:
  $ ./start.sh info

Test the USB:
  $ ./start.sh test             # QEMU tests
  $ ./start.sh slow             # Slow-motion debugging

================================================================================

EOF
