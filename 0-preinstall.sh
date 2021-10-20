#!/usr/bin/env bash

echo "--------------------------------------------------"
echo "Setting up country mirrors for optimal download   "
echo "--------------------------------------------------"

countrycode=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true
pacman -S --noconfirm pacman-contrib reflector rsync
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector -a 48 -c $countrycode -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

echo -e "\nInstalling prerequisits...\n$HR"
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
