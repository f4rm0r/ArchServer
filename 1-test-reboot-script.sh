#!/usr/bin/env bash

{
echo "--------------------------------------------------"
echo " Setting up country mirrors for optimal download  "
echo "--------------------------------------------------"

iso=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true
pacman -Syy --noconfirm pacman-contrib reflector rsync archlinux-keyring
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
pacstrap ${MOUNTPOINT}/ archlinux-keyring autoconf automake base base-devel binutils btrfs-progs dhcpcd dialog dosfstools efibootmgr gcc git grub htop libnewt linux linux-lts linux-firmware linux-headers nethogs ncdu nano rsync sudo traceroute ufw vim wget --noconfirm --needed
genfstab -U ${MOUNTPOINT} >> ${MOUNTPOINT}/etc/fstab
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf

echo "--------------------------------------------------"
echo "---  Setting key variables used during chroot  ---"
echo "--------------------------------------------------"

# Sets username variable and puts it in to a tempfile.
echo "--------------------------------------"
echo "--       Set username for user      --"
echo "--------------------------------------"
read -p "Please enter username:" username
echo username=$username >> /mnt/tempvars
clear

# Sets password variable and puts it in to a tempfile.
echo "--------------------------------------"
echo "--    Set Password for $username    --"
echo "--------------------------------------"
read -p "Enter password for $username:" password
echo password=$password >> /mnt/tempvars
clear

echo "--------------------------------------"
echo "-----   Set Password for root    -----"
echo "--------------------------------------"
read -p "Enter password for root:" rootpw
echo rootpw=$rootpw >> /mnt/tempvars
clear

echo "--------------------------------------"
echo "---------  Set hostname  -------------"
echo "--------------------------------------"
read -p "Please enter hostname:" hostname
echo hostname=$hostname >> /mnt/tempvars
clear

#copy mirrorlist and install scriptto new installation before chroot
cp /etc/pacman.d/mirrorlist ${MOUNTPOINT}/etc/pacman.d/mirrorlist
#cp /root/ArchServer/testing_scripts.sh ${MOUNTPOINT}/testing_scripts.sh

cat << EOF | sudo arch-chroot /mnt /bin/bash

source /tempvars

echo "--------------------------------------------------"
echo "--------   Bootloader GRUB Installation  ---------"
echo "--------------------------------------------------"

mkdir /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchServer

echo "---------------------------------------"
echo "------  setting up user account  ------"
echo "---------------------------------------"
useradd -m -g users -G wheel -s /bin/bash $username
echo -e "$password\n$password" | passwd $username

echo "--------------------------------------"
echo "--           Network Setup          --"
echo "--------------------------------------"
pacman -S networkmanager dhclient --noconfirm --needed
systemctl enable --now NetworkManager

cp /etc/skel/.bash_profile /home/$username/
cp /etc/skel/.bash_logout /home/$username/
cp /etc/skel/.bashrc /home/$username/.bashrc
chown -R $username: /home/$username
#    sed -n '#/home/'"$username"'/#,s#bash#zsh#' /etc/passwd

echo "--------------------------------------"
echo "--    Setting Password for Root     --"
echo "--------------------------------------"
echo -e "$rootpw\n$rootpw" | passwd root


echo "-----------------------------------------"
echo "----       Setting makeflags         ----"
echo "-----------------------------------------"

nc=$(grep -c ^processor /proc/cpuinfo)
echo "You have " $nc" cores."
echo "-----------------------------------------"
echo "Changing the makeflags for "$nc" cores."
sudo sed -i 's/#MAKEFLAGS="j2"/MAKEFLAGS="j$nc"/g' /etc/makepkg.conf
echo "Changing the compression settings for "$nc" cores."
sudo sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g' /etc/makepkg.conf

# Set keymaps
localectl --no-ask-password set-keymap sv-latin1

# Hostname
hostnamectl --no-ask-password set-hostname $hostname

# Add parallel downloading
sed -i 's/^#Para/Para/' /etc/pacman.conf

# Activates multilib
echo "[multilib]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
pacman -Syy --noconfirm

echo -e "\nInstalling Base System\n"

chmod +x /testing_scripts.sh
# /testing_scripts.sh


#
# determine processor type and install microcode
# 
proc_type=$(lscpu | awk '/Vendor ID:/ {print $3}')
case "$proc_type" in
	GenuineIntel)
		print "Installing Intel microcode"
		pacman -S --noconfirm intel-ucode
		proc_ucode=intel-ucode.img
		;;
	AuthenticAMD)
		print "Installing AMD microcode"
		pacman -S --noconfirm amd-ucode
		proc_ucode=amd-ucode.img
		;;
esac
echo -e "\nDone!\n"

EOF

#echo "-----------------------------------------------"
#echo "--------- calling the clean up crew -----------"
#echo "-----------------------------------------------"

#rm /mnt/testing_scripts
#rm /mnt/tempvars

#arch-chroot $MOUNTPOINT /home/$username/1-setup.sh

} 2>&1 | tee logfile.txt
