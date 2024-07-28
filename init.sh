#!/bin/sh
# Init script for initramfs
#
# If a rootfs folder can be mounted at root, switches to full user space.
# Else, jumps into a busybox (a)sh shell.
#
# This process can be thought of as:
#
#   ( start machine )
#           |
# [ BIOS/UEFI firmware   ]
#           |
# [ load GRUB/bootloader ]
#           |
# [  init linux kernel   ]
#           |
# [  load initramfs      ]
#           |
# [       /init          ]
#           |
# ( does rootfs exist? )
#           |        |
#           V        V
#        [ yes ]   [ no ]---> [ /bin/sh ] --> ( stop inside initramfs )
#           |
#           V
# < Can rootfs fit in memory? >
#           |        |
#           V        V
#        [ yes ]   [ no ]---> [ readonly rootfs! ]
#           |                              |
#           V                              |
#  [ copy rootfs to tmpfs ]                |
#           |                              |
#           |<------------------------------
#           V
# < does rootfs contain /sbin/init ? >
#           |        |
#           V        V
#        [ yes ]   [ no ]----------------
#           |                            |
#           V                            |
#  [ switch_root rootfs /sbin/init ]     |
#           |                            |
#           V                            V
#      < Success? > -----[ no ]---> [ chroot rootfs bash]
#           |                            |
#        [ yes ]                         |
#           |                            |
#           |<---------------------------
#           V
#      < Success? > ---[ no ]---> [ /bin/sh ] --> ( stop inside initramfs)
#           |
#        [ yes ]
#           |
#           V
#       ( stop inside rootfs userspace )
#   
#
# Notes:
# * Rootfs may be on the iso directly
# * Alternatively rootfs may be avirtio filesystem named "rootfs"
# * If there is enough space, rootfs will be copied to memory.
# * If there is not enough space, rootfs will be readonly.
# * Either way rootfs will be non-persistant.

# Mount kernel / virtual filesystems
mount -t devtmpfs none /dev
mount -t proc none /proc
mount -t sysfs none /sys

# Make rootfs mountpoint
mkdir -p /mnt/rootfs

# Mount rootfs if stored on /dev/sda (This image)
mkdir -p /mnt/sda
mount /dev/sda /mnt/sda
mount /mnt/sda/rootfs /mnt/rootfs

# Mount rootfs of virtual filesystem if found (libvirt / qemu / virsh / virtmanager)
# This allows for using containers/chroots as root userspace.
mount -t 9p -o trans=virtio,rw,version=9p2000.L rootfs /mnt/rootfs 2>/dev/null

# Usually an init would want to umount these,
# but busybox should handle this for us:
umount /dev
umount /sys
umount /proc

switch_to_rootfs() {
    # Chroot to rootfs
    # switch_root must run as PID 1
    echo 'Attempting to switch root...'
    exec busybox switch_root . "/sbin/init" "$@"
}
chroot_to_rootfs() {
    # chroot to rootfs
    echo 'Attempting to chroot...'
    chroot . bash
}
initramfs_shell(){
    # Basic shell, silence job control warnings
    echo 'Running interactive initramfs.'
    clear
    sleep 1
    clear
    cat /etc/hello.ascii
    sh +m
}

if [ ! -d /mnt/rootfs/bin ];
then
    initramfs_shell
else
    echo 'Mount available for userspace root filesystem.'
    echo 'Copying rootfs data into memory... (changes will not persist between restarts)'
    mkdir -p /tmp/rootfs
    mount -t tmpfs tmpfs /tmp/rootfs
    n=$(find /mnt/rootfs/ -maxdepth 1 | wc -l)
    i=1
    rootfs=/mnt/rootfs
    for d in /mnt/rootfs/*
    do
        cp -aR "$d" /tmp/rootfs/ 2>/dev/null || { rootfs=/mnt/rootfs ; break ; }
        i=$(( $i + 1  ))
        pcnt=$(echo "scale=2;  $i / $n * 100" | bc)
        echo "Copying rootfs: $pcnt %"
        rootfs=/tmp/rootfs
    done
    if [ "$rootfs" = "/tmp/rootfs" ]
    then
        echo '...complete.'
    else
        echo '...not enough space, filesystem will be READ ONLY!'
	umount /tmp/rootfs
	sleep 5
    fi
    cd $rootfs

    # Modify this file for automated start
    echo 'Select mode (within 10 seconds):'
    echo 'Default / no selection : 1 -> 2 -> 3'
    echo '1) switch_root rootfs /sbin/init'
    echo '2) chroot rootfs bash'
    echo '3) initramfs /bin/sh'
    if read -t 10 input
    then
        case "$input" in
          1)
            switch_to_rootfs
            ;;
        
          2)
            chroot_to_rootfs
            ;;
        
          3)
            initramfs_shell
            ;;
        
          *)
            ;;
        esac
    else
        echo 'Attempting to switch root...'
        exec busybox switch_root . "/sbin/init" "$@" \
            || { echo 'switch_root failed!... trying chroot... ' ; chroot . bash ; } \
            || { echo 'switch and chroot failed!... staying in initramfs! :( ' ; sh +m ; }
    fi
fi
