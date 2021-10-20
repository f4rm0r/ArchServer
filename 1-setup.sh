#!/usr/bin/env bash

echo "--------------------------------------"
echo "--           Network Setup          --"
echo "--------------------------------------"
pacman -S networkmanager dhclient --noconfirm --needed
systemctl enable --now NetworkManager

echo "--------------------------------------"
echo "--      Set Password for Root       --"
echo "--------------------------------------"
echo "Enter password for root: "
passwd root

if ! source install.conf; then
    read -p "Please enter hostname:" hostname

    read -p "Please enter username:" username
    echo "username=$username" >> /ArchServer/install.conf
    echo "password=$password" >> /ArchServer/install.conf
fi

echo "-----------------------------------------"
echo "----       Setting makeflags         ----"
echo "-----------------------------------------"

nc=$(grep -c ^processor /proc/cpuinfo)
echo "You have " $nc" cores."
echo "-----------------------------------------"
echo "Changing the makeflags for "$nc" cores."
sudo sed -i 's /#MAKEFLAGS="j2"/MAKEFLAGS="j$nc"/g' /etc/makepkg.conf
echo "Changing the compression settings for "$nc" cores."
sudo sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g' /etc/makepkg.conf

echo "-------------------------------------------------"
echo "       Setup Language to US and set locale       "
echo "-------------------------------------------------"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
timedatectl --no-ask-password set-timezone Europe/Stockholm
timedatectl --no-ask-password set-ntp 1
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_COLLATE="" LC_TIME="en_US.UTF-8"

# Set keymaps
localectl --no-ask-password set-keymap sv-latin1

# Hostname
hostnamectl --no-ask-password set-hostname $hostname

# Add sudo no password rights
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

#Add parallel downloading
sed -i 's/^#Para/Para/' /etc/pacman.conf

#Enable multilib
cat <<EOF >> /etc/pacman.conf
[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
pacman -Syy --noconfirm

echo -e "\nInstalling Base System\n"

PKGS=(
    'ark'
    'autoconf'
    'automake'
    'base'
    'biunutils'
    'btrfs-progs'
    'dhcpcd'
    'dialog'
    'dosfstools'
    'efibootmgr'
    'gcc'
    'git'
    'htop'
    'nethogs'
    'ncdu'
    'linux'
    'linux-lts'
    'linux-firmware'
    'linux-headers'
    'neofetch'
    'rsync'
    'sudo'
    'traceroute'
    'ufw'
    'zsh'
    'zsh-syntax-highlighting'
    'zsh-autosuggestions'
)

for PKG in "${PKGS[@]}"; do
    echo "INSTALLING: ${PKG}"
    sudo pacman -S "$PKG" --noconfirm --needed
done