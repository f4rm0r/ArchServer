#!/usr/bin/env bash
read -p "Please enter username:" username

echo -e "$username"

arch-chroot /mnt/ArchServer sh useradd -m -g users -G wheel -s /bin/bash $username
cp -R ~/ArchServer /home/$username/

    echo "--------------------------------------"
    echo "--      Set Password for $username  --"
    echo "--------------------------------------"
    echo "Enter password for $username user: "
    passwd $username

    cp /etc/skel/.bash_profile /home/$username/
    cp /etc/skel/.bash_logout /home/$username/
    cp /etc/skel/.bashrc /home/$username/.bashrc
    chown -R $username: /home/$username
    sed -n '#/home/'"$username"'/#,s#bash#zsh#' /etc/passwd