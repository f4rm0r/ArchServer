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

#Add parallel downloading
sed -i 's/^#Para/Para/' /etc/pacman.conf

# Activates multilib
echo "[multilib]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

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
