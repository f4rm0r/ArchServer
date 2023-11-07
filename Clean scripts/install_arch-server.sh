#!/usr/bin/env bash

{
before_reboot(){
echo -ne "
--------------------------------------------------
Setting up country mirrors for optimal download
--------------------------------------------------
"

iso=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true
pacman -Syy --noconfirm pacman-contrib reflector rsync archlinux-keyring
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

echo -ne "
Installing prereqs...
"
pacman -S --noconfirm gptfdisk

echo -ne "
 --------    Select your disk to format    --------
 --------------------------------------------------
 --------------------------------------------------
"

lsblk
echo "Please enter disk to work on: (example /dev/sda)"
read DISK
echo "THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK!"
read -p "are you sure you want to continue (Y/N):" formatdisk
case $formatdisk in

y|Y|yes|Yes|YES)

echo -ne "

 --------------------------------------------------
 Formatting disk...
 --------------------------------------------------

"
# disk prep
sgdisk --zap-all --clear ${DISK} # zap all on disk
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1:0:+1000M ${DISK} # partition 1 (UEFI SYS), default start block, 512MB
sgdisk -n 2:0:0     ${DISK} # partition 2 (Root), default start, remaining

# set partition types
sgdisk -t 1:ef00 ${DISK}
sgdisk -t 2:8300 ${DISK}


# label partitions
sgdisk -c 1:"UEFISYS" ${DISK}
sgdisk -c 2:"ROOT" ${DISK}

# make filesystems
echo -ne "

Creating Filesystems...

"
mkfs.vfat -F32 -n "UEFISYS" "${DISK}1"
mkfs.ext4 -L "ROOT" "${DISK}2"
;;
esac

echo -ne "
--------------------------------------------------
-----------------Select mountpoint----------------
--------------------------------------------------

"
echo "Please enter mountpoint to mount disks: (Example /mnt"
read MOUNTPOINT
echo "THIS WILL DELETE ANY EXISTING DATA IN FOLDER!"
read -p "are you sure you want to continue (Y/N):" mountpoint
case $mountpoint in

y|Y|yes|Yes|YES)

mkdir -p ${MOUNTPOINT}
echo -e "\nMounting filesystems on ${MOUNTPOINT}"
mount -t ext4 "${DISK}2" ${MOUNTPOINT}
btrfs subvolume create ${MOUNTPOINT}/@
umount ${MOUNTPOINT}
;;
esac

#mount target
mount -t ext4 "${DISK}2" ${MOUNTPOINT}
rm -r ${MOUNTPOINT}/*
mkdir -p ${MOUNTPOINT}/boot
mkdir -p ${MOUNTPOINT}/boot/efi
mount -t vfat "${DISK}1" ${MOUNTPOINT}/boot

echo -ne "
--------------------------------------------------
-------- Arch Install on Main Drive       --------
--------------------------------------------------

"
pacstrap ${MOUNTPOINT}/ archlinux-keyring autoconf automake base base-devel binutils dhcpcd dialog dosfstools efibootmgr gcc git grub htop libnewt linux linux-firmware linux-headers nano rsync sudo traceroute ufw vim wget --noconfirm --needed
genfstab -U ${MOUNTPOINT} >> ${MOUNTPOINT}/etc/fstab

echo -ne "
--------------------------------------------------
---------   Setting up reboot script    ----------
--------------------------------------------------

"

cp $0 ${MOUNTPOINT}/root/

}

after_reboot(){






}

if [ -f /var/run/rebooting-for-installation ]; then
    after_reboot
    rm /var/run/rebooting-for-installation
    systemctl disable installation.service
    rm -r /etc/systemd/system/installation.service

else
    before_reboot 
    touch /var/run/rebooting-for-installation
tee -a /etc/systemd/system/installation.service > /dev/null <<EOT
[Unit]
Description=Remote desktop service (VNC)

[Service]
Type=simple
# ExecStartPre=/bin/sh -c ''
ExecStart=/root/install_arch-server.sh

[Install]
WantedBy=multi-user.target network-online.target sockets.target
EOT

systemctl daemon-reload
systemctl enable installation.service


fi

} 2>&1 | tee logfile.txt