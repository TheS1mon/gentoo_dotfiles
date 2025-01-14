#!/usr/bin/env bash
set -e # Breche direkt ab, wenn ein Fehler auftritt

#### Configuration Variables ####
			 
BASEPACKETSELECTION="sys-fs/dosfstools sys-fs/btrfs-progs app-editors/nano app-editors/neovim sys-process/htop net-misc/dhcpcd app-admin/sysklogd sys-process/cronie sys-apps/mlocate app-shells/bash-completion net-misc/chrony sys-block/io-scheduler-udev-rules app-misc/fastfetch sys-apps/less dev-vcs/git net-misc/wget sys-apps/man-pages app-misc/tmux app-shells/gentoo-bashcomp app-portage/portage-utils sys-apps/pciutils"
HOSTNAME="gentoo-tvstation"
INTELCPU="yes"

#################################

source /etc/profile
export PS1="(chroot) ${PS1}"

echo "Welcome in your new system (at least in your new chroot environment)."
emerge --verbose --sync
eselect news read
eselect profile list | less

read -e -p "Select Profile Number: " profilenb
eselect profile set "$profilenb"

echo "Examining CPU capabilities"
emerge --oneshot app-portage/cpuid2cpuflags
cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags

emerge --verbose --update --deep --newuse @world
emerge --verbose ${BASEPACKETSELECTION}
emerge --verbose --depclean

ln -sf ../usr/share/zoneinfo/Europe/Berlin /etc/localtime
cat <<EOF > /etc/locale.gen
en_US ISO-8859-1
en_US.UTF-8 UTF-8
EOF

locale-gen
locale -a

read -e -p "Select Locale (number of displayed language): " locale
eselect locale set "$locale"

env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

emerge sys-kernel/linux-firmware
if [ "$INTELCPU" = "yes" ]; then
    emerge sys-firmware/sof-firmware
    emerge sys-firmware/intel-microcode
fi

echo "sys-kernel/installkernel grub dracut" > /etc/portage/package.use/installkernel
emerge --verbose sys-kernel/installkernel
emerge --verbose sys-kernel/gentoo-kernel
sed -i 's/^\(USE="[^"]*\)"/\1 dist-kernel"/' /etc/portage/make.conf

echo "$HOSTNAME" > /etc/hostname
rc-update add dhcpcd default
echo "Set root users password"
passwd
nvim /etc/rc.conf
nvim /etc/conf.d/keymaps
nvim /etc/conf.d/hwclock
rc-update add sysklogd default
rc-update add cronie default
rc-update add chronyd default

emerge --verbose sys-boot/grub
grub-install --efi-directory=/efi
grub-mkconfig -o /boot/grub/grub.cfg

emerge --verbose --update --deep --newuse @world
emerge --verbose --depclean
eselect news read

cd /root
git clone https://github.com/TheS1mon/gentoo_dotfiles.git

fastfetch

echo "Installation completed. TODO List before rebooting:"
echo "If you use WiFi or advanced networking you need to configure it before booting into your new system."
echo "When you exit the chroot environment, the system will reboot."

