#!/usr/bin/env bash
{

echo "--------------------------------------"
echo "--            Grub Setup            --"
echo "--------------------------------------"

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchServer

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
    echo "password=$password" >> /ArchServer/install.conf
fi

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
)

for PKG in "${PKGS[@]}"; do
    echo "INSTALLING: ${PKG}"
    sudo pacman -S "$PKG" --noconfirm --needed
done

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


echo -e "\nINSTALLING AUR SOFTWARE\n"

echo "CLONING YAY"
cd ~
git clone "https://aur.archlinux.org/yay.git"
cd ${HOME}/yay
makepkg -si --noconfirm
cd ~


PKGSA=(
    'nerd-fonts-fira-code'
    'timeshift-bin'
    'ttf-meslo'
    )

    for PKG in "${PKG[@]}"; do
        yay -S --noconfirm $PKG
    done

} 2>&1 | tee logfile_1-setup.txt
~/ArchServer/2-AUR
