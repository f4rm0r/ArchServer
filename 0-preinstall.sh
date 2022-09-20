#!/usr/bin/env bash

{
echo "--------------------------------------------------"
echo "Setting up country mirrors for optimal download   "
echo "--------------------------------------------------"

iso=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true
pacman -S --noconfirm pacman-contrib reflector rsync
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

echo -e "\nInstalling prereqs...\n$HR"
pacman -S --noconfirm gptfdisk btrfs-progs

echo "--------------------------------------------------"
echo "--------    Select your disk to format    --------"
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
wipefs -a -t btrfs ${DISK}2 # removes all of the btrfs signatures and wipe partition clean 

# make filesystems
echo -e "\nCreating Filesystems...\n$HR"

mkfs.vfat -F32 -n "UEFISYS" "${DISK}1"
mkfs.btrfs -L "ROOT" "${DISK}2"
;;
esac

echo "--------------------------------------------------"
echo "-----------------Select mountpoint----------------"
echo "--------------------------------------------------"

echo "Please enter mountpoint to mount disks: (Example /mnt"
read MOUNTPOINT
echo "THIS WILL DELETE ANY EXISTING DATA IN FOLDER!"
read -p "are you sure you want to continue (Y/N):" mountpoint
case $mountpoint in

y|Y|yes|Yes|YES)

mkdir -p ${MOUNTPOINT}
echo -e "\nMounting filesystems on ${MOUNTPOINT}"
mount -t btrfs "${DISK}2" ${MOUNTPOINT}
btrfs subvolume create ${MOUNTPOINT}/@
umount ${MOUNTPOINT}
;;
esac

#mount target
mount -t btrfs -o subvol=@ "${DISK}2" ${MOUNTPOINT}
rm -r ${MOUNTPOINT}/*
mkdir -p ${MOUNTPOINT}/boot
mkdir -p ${MOUNTPOINT}/boot/efi
mount -t vfat "${DISK}1" ${MOUNTPOINT}/boot

echo "--------------------------------------------------"
echo "-------- Arch Install on Main Drive       --------"
echo "--------------------------------------------------"
pacstrap ${MOUNTPOINT}/ base base-devel linux linux-firmware vim grub nano sudo archlinux-keyring wget libnewt --noconfirm --needed
genfstab -U ${MOUNTPOINT} >> ${MOUNTPOINT}/etc/fstab
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf

echo "--------------------------------------------------"
echo "--------   Bootloader GRUB Installation  ---------"
echo "--------------------------------------------------"

grub-install --target=x86_64-efi --efi-directory=esp --bootloader-id=GRUB

cp /etc/pacman.d/mirrorlist ${MOUNTPOINT}/etc/pacman.d/mirrorlist


echo "--------------------------------------------------"
echo "----------   System ready for 1-setup   ----------"
echo "--------------------------------------------------"

arch-chroot $MOUNTPOINT /home/$username/1-setup.sh

} 2>&1 | tee logfile.txt
