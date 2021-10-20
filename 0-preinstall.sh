#!/usr/bin/env bash

echo "--------------------------------------------------"
echo "Setting up country mirrors for optimal download   "
echo "--------------------------------------------------"

countrycode=$(curl -4 ifconfig.co/country.iso)
timedatectl set-ntp true
pacman -S --noconfirm pacman-contrib reflector rsync
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector -a 48 -c $countrycode -f 10 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
mkdir /mnt

echo -e "\n Installing prerequisits...\n$HR"
pacman -S --noconfirm gptfdisk btrfs-progs

echo "--------------------------------------------------"
echo "------------Select your disk to format------------"
echo "--------------------------------------------------"
lsblk
echo "Please enter disk to work on: (example /dev/sda)"
read DISK
echo "THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK!"
read -p "are you sure you want to continue (Y/N):" formatdisk
case $formatdisk in

y|Y|yes|Yes|YES)

echo "--------------------------------------------------"
echo -e "\nFormatting disk...\n$HR"
echo "--------------------------------------------------"

#disk prep
sgdisk -Z ${DISK} # Zap all on disk
sgdisk -a 2048 -o ${DISK} # New GPT table with 2048 alignment

# Create partitions
sgdisk -n 1:0:+200M ${DISK} # Partition 1 (UEFI SYS), default stat block, 512MB
sgdisk -n 2:0:0     ${DISK} # Partition 2 (Root), default start, remaining

# set partition types
sgdisk -t 1:ef00 ${DISK}
sgdisk -t 2:8300 ${DISK}

# label partitions
sgdisk -c 1:"UEFISYS" ${DISK}
sgdisk -c 2:"ROOT" ${DISK}

# make filesystems

echo -e "\nCreating filesystems\n$HR"

mkfs.vfat -F32 -n "UEFISYS" "${DISK}1"
mkfs.btrfs -L "ROOT" "${DISK}2"

echo "--------------------------------------------------"
echo "-----------------Select mountpoint----------------"
echo "--------------------------------------------------"

echo "Please enter mountpoint to mount disks: (Example /mnt"
read MOUNTPOINT
echo "THIS WILL DELETE ANY EXISTING DATA IN FOLDER!"
read -p "are you sure you want to continue (Y/N):" mountpoint
case $mountpoint in

y|Y|yes|Yes|YES)

echo -e "\nMounting filesystems on ${MOUNTPOINT}"
mount -t btrfs "${DISK}2" ${MOUNTPOINT}
btrfs subvolume create /mnt/@
umount ${MOUNTPOINT}
;;
esac

#mount targe
mount -t btrfs -o subvol=@ "${DISK}2" ${MOUNTPOINT}
rm -r ${MOUNTPOINT}/*
mkdir -p ${MOUNTPOINT}/boot
mkdir -p ${MOUNTPOINT}/boot/efi
mount -t vfat "${DISK}1" ${MOUNTPOINT}/boot
