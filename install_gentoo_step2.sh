source /etc/profile
export PS1="(chroot) ${PS1}"

echo "Welcome in your new system (at least in your new chroot environment)."
emerge --sync
eselect news read
eselect profile list

read -e -p "Select Profile Number: " profilenb
eselect profile set "$profilenb"

emerge --oneshot app-portage/cpuid2cpuflags
cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags

emerge --ask --verbose --update --deep --changed-use @world
emerge -av ${BASEPACKETSELECTION}
emerge -av --depclean

ln -sf ../usr/share/zoneinfo/Europe/Berlin /etc/localtime
cat <<EOF > /etc/locale.gen
en_US ISO-8859-1
en_US.UTF-8 UTF-8
EOF

locale-gen
locale -a

read -e -p "Select Locale: " locale
eselect locale set "$locale"

env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

emerge --ask sys-kernel/linux-firmware
# Intel CPU
# emerge --ask sys-firmware/sof-firmware
# emerge --ask sys-firmware/intel-microcode

echo "sys-kernel/installkernel grub dracut" > /etc/portage/package.use/installkernel
emerge -av sys-kernel/installkernel
emerge -v sys-kernel/gentoo-kernel
