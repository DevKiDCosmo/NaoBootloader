# NaoBootloader

A bootloader creation tool that formats USB devices and installs bootloader and kernel binaries to create bootable USB drives.

## Features

- 🔍 Automatic USB device detection
- 💾 Interactive device selection with detailed information
- 🛡️ Safety confirmations before destructive operations
- 📝 Clear progress indicators and colored output
- ✅ Installation verification
- 🔧 Support for custom kernel and bootloader binaries

## Requirements

- Linux operating system
- Root/sudo privileges (required for disk operations)
- USB drive (will be formatted - all data will be lost!)
- `fdisk`, `mkfs.vfat`, `lsblk`, `dd` (standard Linux utilities)

## Quick Start

### 1. Build Example Binaries

```bash
make
```

This creates example `bootloader.bin` and `kernel.bin` files.

### 2. Create Bootable USB

**⚠️ WARNING: This will ERASE ALL DATA on the selected USB device!**

```bash
sudo ./create_bootable_usb.sh
```

Or with custom binary files:

```bash
sudo ./create_bootable_usb.sh /path/to/kernel.bin /path/to/bootloader.bin
```

### 3. Follow Interactive Prompts

The script will:
1. Validate your binary files
2. Scan for available USB devices
3. Display detected devices with size and model information
4. Ask you to select a device
5. Request confirmation before formatting
6. Create a bootable USB with your bootloader and kernel

## Usage

```bash
sudo ./create_bootable_usb.sh [kernel_binary] [bootloader_binary]
```

**Arguments:**
- `kernel_binary` - Path to kernel binary file (default: `kernel.bin`)
- `bootloader_binary` - Path to bootloader binary file (default: `bootloader.bin`)

**Example:**
```bash
# Use default binaries (kernel.bin and bootloader.bin in current directory)
sudo ./create_bootable_usb.sh

# Use custom binaries
sudo ./create_bootable_usb.sh ./my_kernel.bin ./my_bootloader.bin
```

## How It Works

1. **Validation**: Checks that kernel and bootloader binary files exist
2. **Detection**: Scans for removable USB devices using `/sys/block` and `lsblk`
3. **Selection**: Presents available devices with size, model, and vendor information
4. **Confirmation**: Requires explicit "YES" confirmation before proceeding
5. **Unmounting**: Unmounts all partitions on the target device
6. **Partitioning**: Creates a new MBR partition table with a single bootable partition
7. **Formatting**: Formats the partition as FAT32 with label "NAOBOOT"
8. **Installation**: 
   - Writes bootloader to the MBR (first 446 bytes)
   - Copies kernel binary to the USB partition
   - Copies bootloader binary to the USB partition for reference
9. **Verification**: Checks that files were written correctly
10. **Completion**: Syncs all data and displays success message

## File Structure

```
NaoBootloader/
├── create_bootable_usb.sh    # Main USB creation script
├── bootloader.asm            # Example bootloader assembly source
├── kernel.asm                # Example kernel assembly source
├── Makefile                  # Build script for example binaries
├── bootloader.bin            # Compiled bootloader binary (generated)
├── kernel.bin                # Compiled kernel binary (generated)
└── README.md                 # This file
```

## Creating Your Own Bootloader

The example files provide a starting point. To create your own:

1. Write your bootloader in assembly (or C with appropriate compilation)
2. Ensure bootloader fits in 446 bytes for MBR
3. Compile to raw binary format
4. Create your kernel binary
5. Use the script to install them on a USB device

### Example with NASM

```bash
# Compile bootloader
nasm -f bin -o bootloader.bin bootloader.asm

# Compile kernel  
nasm -f bin -o kernel.bin kernel.asm

# Create bootable USB
sudo ./create_bootable_usb.sh kernel.bin bootloader.bin
```

## Safety Features

- Requires root privileges (prevents accidental execution)
- Shows detailed device information before selection
- Requires typing "YES" (not just "y") to confirm
- Displays current partitions before formatting
- Unmounts device safely before operations
- Verifies installation after completion

## Troubleshooting

### No USB devices detected
- Ensure USB drive is properly inserted
- Check if device appears in `lsblk` output
- Try unplugging and re-inserting the USB drive

### Permission denied
- Script must be run with `sudo` or as root
- Check device permissions with `ls -l /dev/sd*`

### Verification failed
- Device may not have synced properly
- Try ejecting and re-inserting the USB
- Check USB drive is not defective

### Bootloader doesn't work
- Ensure bootloader binary is valid x86 boot code
- Verify bootloader ends with 0xAA55 signature (for MBR)
- Check that bootloader is less than 446 bytes

## Development

### Clean build artifacts

```bash
make clean
```

### Testing (without actual USB)

The script requires actual hardware and root access. For testing changes:

1. Review the script logic
2. Test with a virtual machine and virtual USB
3. Or use a dedicated test USB drive with no important data

## License

This project is licensed under the Apache License 2.0. See the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Disclaimer

⚠️ **Use at your own risk!** This tool performs destructive disk operations. Always:
- Double-check your device selection
- Backup any important data before using this tool
- Verify you're not selecting your system drive
- Test on non-critical devices first

The authors are not responsible for data loss or hardware damage resulting from the use of this tool.