#!/usr/bin/env bash
# A very basic linux image

set -e

mkdir -p build
cd build || exit

kernel_url=https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.7.tar.xz
libre_kernel_url=https://linux-libre.fsfla.org/pub/linux-libre/releases/LATEST-6.N/linux-libre-6.7-gnu.tar.xz
# Optionally use libre kernel instead:
#kernel_url=$libre_kernel_url
busybox_url=https://busybox.net/downloads/busybox-1.34.1.tar.bz2

REQUIRED_PKGS=(
    bc
    bison
    build-essential
    flex
    gcc
    grub-common
    grub-pc-bin
    grub-pc
    grub-efi
    libelf-dev
    libncurses5-dev
    libssl-dev
    pv
    xorriso
    xz-utils
)

check_requirements(){
    if dpkg -l "${REQUIRED_PKGS[@]}" 2>&1 | grep -E 'no packages'
    then
        echo "Packages missing, run:"
        echo "sudo apt-get -y install ${REQUIRED_PKGS[@]}"
	exit 1
    fi
}

# Check requirements
check_requirements

# Create iso structure
mkdir -p iso
rm -rf iso/*
cd iso || exit
mkdir -p dev proc sys
cd ..

# Compile linux kernel
if [ ! -d "linux" ]; then
    wget --no-clobber "$kernel_url"
    tar xf linux-*.tar.*
    linux_folder=$(find . -type d -name "linux[0-9._-]*" -print -quit)
    mv "$linux_folder" linux
    cd linux || exit
    make defconfig
    # Manually configure with:
    # make menuconfig
    make -j $(nproc)
    cd .. || exit
fi

# Compile busybox
if [ ! -d "busybox" ]; then
    wget --no-clobber "$busybox_url"
    tar xf busybox-1.34.1.tar.bz2
    busybox_folder=$(find . -type d -name "busybox[0-9._-]*" -print -quit)
    mv "$busybox_folder" busybox
    cd busybox || exit
    export LDFLAGS='--static'
    make defconfig

    # FIXME: https://bugs.busybox.net/show_bug.cgi?id=15934
    # Bug 15934 - Busybox fails to build with linux kernels >= 6.8 
    # Temporary workaround: remove tc from the build with:
    # CONFIG_TC is not defined
    sed -i .config -e 's/CONFIG_TC=y/CONFIG_TC=n/'

    make -j $(nproc)
    make install
    cd .. || exit
fi

# Copy busybox to iso
cp -r busybox/_install/* iso/

# Create init script.
cp ../init.sh iso/init
chmod +x iso/init


# Create init message
mkdir -p iso/etc/
cp ../hello.ascii iso/etc/

# Generate initramfs from iso.
# Also ensure switch_root is not included in this
rm -rf ./initramfs.cpio.gz
cd iso || exit
find . | grep -v switch_root | cpio -ov --format=newc | gzip -9 > ../initramfs.cpio.gz
cd .. || exit

# Make bootable with GRUB
mkdir -p iso/boot/grub
# Copy kernel and initramfs
cp linux/arch/x86_64/boot/bzImage iso/boot/
mv initramfs.cpio.gz iso/boot/
# Copy grub.cfg
# Currently using mbr only
# NOTE GRUB CAN BE TRICKY TO CONFIGURE
# ESPECIALLY IN A WAY THAT WORKS ACROSS ALL MACHINES.
cp ../grub*.cfg iso/boot/grub/

echo "Attempting to create bootable iso:"
rm -rf minimal_linux.iso
grub-mkrescue -o minimal_linux.iso iso/

echo ''
echo 'To run kernel and initramfs in a new terminal window:'
echo 'qemu-system-x86_64 -kernel ./build/iso/boot/bzImage -initrd ./build/iso/boot/initramfs.cpio.gz -nographic -append "console=ttyS0" -vga std'
echo 'Select serial console option if running from command line'
echo '(to exit : CTRL+a x)'
echo ''
echo 'To run iso directly:'
echo 'qemu-system-x86_64 -drive format=raw,file=build/minimal_linux.iso -m 512 -nographic -vga std'
echo 'Select serial console option if running from command line'
echo '(to exit : CTRL+a x)'
echo ''

