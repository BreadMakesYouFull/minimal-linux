#!/usr/bin/env bash
# Extend minimal linux image to boot into a full user space.
# This could be imported from a chroot / container.
#
# To use, place your linux root directories inside the folder:
# build/custom/rootfs
#

set -e

mkdir -p build
cd build || exit

if [ ! -d iso ]
then
    echo "Run minimal_linux.sh first"
    exit 1
fi

mkdir -p custom/rootfs
rm -rf custom/{bin,boot,dev,init,linuxrc,proc,sbin,sys,usr}
rsync -avuP iso/ custom/
rm -rf linux_custom.iso
grub-mkrescue -o linux_custom.iso custom/

echo 'To run iso directly:'
echo 'qemu-system-x86_64 -drive format=raw,file=build/linux_custom.iso -m 512 -nographic -vga std'
echo 'Select serial console option if running from command line'
echo '(to exit : CTRL+a x)'
echo ''
