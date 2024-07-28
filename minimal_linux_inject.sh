#!/usr/bin/env bash
# Inject minimal linux into an existing image.
# Example used debian stable.
# This can be run after minimal_linux.sh and injects a custom initramfs into debian stable.

mkdir -p build
cd build || exit

if [ ! -d iso ]
then
    echo "Run minimal_linux.sh first"
    exit 1
fi

# Download debian base iso if not present
iso_url="${1:-https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/debian-live-12.5.0-amd64-standard.iso}"

iso_name=$(basename "$iso_url")
wget --no-clobber "$iso_url" -O "$iso_name"

# Copy iso contents
mkdir -p "inject"
7z x "$iso_name" -o./inject

# Replace initramfs with our version
cp iso/boot/initramfs.cpio.gz "inject/boot/"
# Minimal change to point to our ramdisk
sed -i 's|initrd.*|initrd /boot/initramfs.cpio.gz|' "inject/boot/grub/grub.cfg"

mkisofs -J -r -o "minimal_linux_inject.iso" "inject/"

echo ''
echo "Injected minimal_linux into ${iso_name}"
echo ''
echo 'To run iso directly:'
echo 'qemu-system-x86_64 -drive format=raw,file=build/minimal_linux_inject.iso -m 512 -nographic -vga std'
echo 'Select serial console option if running from command line'
echo '(to exit : CTRL+a x)'
echo ''

