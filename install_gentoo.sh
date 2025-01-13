#!/usr/bin/env bash
set -e # Breche direkt ab, wenn ein Fehler auftritt

# Configuration Variables
SSD=yes
ARCH=amd64
MICROARCH=amd64
SUFFIX=desktop-openrc
DIST="https://distfiles.gentoo.org/releases/${ARCH}/autobuilds/"
STAGE3PATH="$(wget -q -O- "${DIST}/latest-stage3-${MICROARCH}-${SUFFIX}.txt" | grep '\.tar\.xz' | grep -o '^[^ ]*\.tar\.xz')"
STAGE3="$(basename ${STAGE3PATH})"
BASEPACKETSELECTION="sys-fs/dosfstools sys-fs/btrfs-progs neovim htop"


echo "Gentoo Installation Script by Simon. This is not a general script; it is tailored to my exact use case. Read before use."
read -e -p "Do you like to configure wireless network or static ips (y/N): " wireless
if [[ "$wireless" == [Yy] ]]; then
    ip addr
    read -e -p "Please name the interface to configure: " winterface
    echo "###############Output###############"
    net-setup "$winterface"
    echo "####################################"
fi
echo "###############Output###############"
ip addr
ping -c3 "www.gentoo.org"
echo "####################################"
read -p "Please validate the internet connectivity before continuing. Press Enter when ready" < /dev/tty

echo "###############Hard Disks###############"
fdisk -l
echo "########################################"
read -e -p "Select the disk to install gentoo linux to: " harddisk

ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
swap_size_mb=$((ram_kb / 1024))

# Mit fdisk das GPT-Label setzen und Partitionen anlegen
(
  echo g         # GPT erstellen
  # EFI-Partition, 1GiB
  echo n         # neue Partition
  echo 1         # Partitionsnummer 1
  echo           # Start (Standard)
  echo +1G       # Größe
  echo t         # Partitions-Typ ändern
  echo 1         # Partitionsnummer 1 auswählen
  echo 1         # Typcode '1' (EFI System)
  
  # Swap-Partition so groß wie RAM
  echo n
  echo 2
  echo
  echo +${swap_size_mb}M
  echo t
  echo 2
  echo 19        # Typcode '19' (Linux swap)
  
  # Linux-Root-Partition
  echo n
  echo 3
  echo
  echo
  echo t
  echo 3
  echo 20        # Typcode '23' (Linux root (x86-64))
  
  echo w         # Änderungen schreiben
) | fdisk "${harddisk}"

# Partitionen benennen (Beispiel: sda1, sda2, sda3)
efi_part="${harddisk}1"
swap_part="${harddisk}2"
root_part="${harddisk}3"

echo "==> Formatiere die EFI-Partition als FAT32..."
mkfs.vfat -F 32 -n EFI "${efi_part}"

echo "==> Formatiere die Swap-Partition..."
mkswap -L SWAP "${swap_part}"
swapon "${swap_part}"  # Swap direkt aktivieren

echo "==> Formatiere die Root-Partition als Btrfs..."
mkfs.btrfs -f -L ROOT "${root_part}"

echo "==> Root-Partition wird nach /mnt/gentoo gemountet..."
mkdir -p /mnt/gentoo
mount "${root_part}" /mnt/gentoo

echo "==> Erstelle Btrfs-Subvolumes für Snapper..."
btrfs subvolume create /mnt/gentoo/@
btrfs subvolume create /mnt/gentoo/@home
btrfs subvolume create /mnt/gentoo/@snapshots
btrfs subvolume create /mnt/gentoo/@var_log
btrfs subvolume create /mnt/gentoo/@var_cache
btrfs subvolume create /mnt/gentoo/@usr_portage

echo "==> Binde Root-Partition erneut mit Subvolume '@' ein..."
umount /mnt/gentoo
mount -o subvol=@ "${root_part}" /mnt/gentoo

# Ordnerstruktur anlegen
mkdir -p /mnt/gentoo/{boot,home,.snapshots,var/log,/var/cache,/var/db/repos/gentoo}

# Weitere Subvolumes mounten
mount -o subvol=@home      "${root_part}" /mnt/gentoo/home
mount -o subvol=@snapshots "${root_part}" /mnt/gentoo/.snapshots
mount -o subvol=@var_log   "${root_part}" /mnt/gentoo/var/log
mount -o subvol=@var_cache   "${root_part}" /mnt/gentoo/var/cache
mount -o subvol=@usr_portage   "${root_part}" /mnt/gentoo/var/db/repos/gentoo

echo "==> EFI-Partition einhängen..."
mkdir -p /mnt/gentoo/efi
mount "${efi_part}" /mnt/gentoo/efi

chronyd -q

wget -q --show-progress "${DIST}/${STAGE3PATH}"

tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo

cp ./make.conf /mnt/gentoo/etc/portage/make.conf
if [ "$SSD" = "yes" ]; then
    echo "SSD erkannt: Kopiere fstab..."
    cp fstab /mnt/gentoo/etc/fstab
elif [ "$SSD" = "no" ]; then
    echo "Keine SSD: Kopiere fstab_nossd..."
    cp fstab_nossd /mnt/gentoo/etc/fstab
fi
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
cp install_gentoo_step2.sh /mnt/gentoo/

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run
## First part finishes after chroot and the script will not continue to run.
chroot /mnt/gentoo /bin/bash

