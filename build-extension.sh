#!/bin/bash
#
# Build script for hk3350-ir-volume.tcz extension
#

set -e

EXTENSION_NAME="hk3350-ir-volume"
BUILD_DIR="extension"
OUTPUT_DIR="."

echo "Building ${EXTENSION_NAME}.tcz extension..."
echo

# Check if extension directory exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "ERROR: Extension directory '$BUILD_DIR' not found!"
    exit 1
fi

# Check if mksquashfs is available
if ! command -v mksquashfs >/dev/null 2>&1; then
    echo "ERROR: mksquashfs not found!"
    echo "Install squashfs-tools:"
    echo "  Debian/Ubuntu: sudo apt-get install squashfs-tools"
    echo "  Fedora: sudo dnf install squashfs-tools"
    echo "  Arch: sudo pacman -S squashfs-tools"
    exit 1
fi

# Clean up old extension if it exists
if [ -f "${OUTPUT_DIR}/${EXTENSION_NAME}.tcz" ]; then
    echo "Removing old extension package..."
    rm -f "${OUTPUT_DIR}/${EXTENSION_NAME}.tcz"
fi

# Build the extension
echo "Creating squashfs package..."
cd "$BUILD_DIR"
mksquashfs usr "${OUTPUT_DIR}/${EXTENSION_NAME}.tcz" \
    -b 4k \
    -no-xattrs \
    -noappend \
    -all-root

cd ..

# Verify the extension was created
if [ ! -f "${OUTPUT_DIR}/${EXTENSION_NAME}.tcz" ]; then
    echo "ERROR: Failed to create extension package!"
    exit 1
fi

# Calculate MD5 checksum
echo "Calculating MD5 checksum..."
md5sum "${OUTPUT_DIR}/${EXTENSION_NAME}.tcz" > "${OUTPUT_DIR}/${EXTENSION_NAME}.tcz.md5.txt"

# Display extension info
echo
echo "Extension built successfully!"
echo
echo "Package: ${EXTENSION_NAME}.tcz"
echo "Size: $(du -h "${OUTPUT_DIR}/${EXTENSION_NAME}.tcz" | cut -f1)"
echo
echo "Files included:"
unsquashfs -ll "${OUTPUT_DIR}/${EXTENSION_NAME}.tcz"
echo
echo "To verify the extension structure:"
echo "  mkdir -p test"
echo "  sudo mount -o loop ${EXTENSION_NAME}.tcz test"
echo "  tree test"
echo "  sudo umount test"
echo
echo "To install on PiCorePlayer:"
echo "  1. Copy ${EXTENSION_NAME}.tcz to /mnt/mmcblk0p2/tce/optional/"
echo "  2. Add ${EXTENSION_NAME}.tcz to /mnt/mmcblk0p2/tce/onboot.lst"
echo "  3. Run: tce-load -i ${EXTENSION_NAME}"
echo "  4. Run: hk3350-setup"
echo "  5. Backup via PiCorePlayer web GUI"
echo
