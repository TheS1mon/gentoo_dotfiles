#!/usr/bin/env bash
set -e # Breche direkt ab, wenn ein Fehler auftritt

#### Configuration Variables ####



#################################

## Enabling Doas ability to temporarily dont ask you for a password
echo "app-admin/doas persist" > /etc/portage/package.use/doas

## Emerge needed apps
emerge -v app-shells/zsh app-shells/zsh-completions app-shells/gentoo-zsh-completions app-admin/doas

## Create Doas Configs
echo "permit persist :wheel" > /etc/doas.conf
chown -c root:root /etc/doas.conf
chmod -c 0400 /etc/doas.conf

## Create an non-root user
read -e -p "Specify your username: " username
useradd -m -G users,wheel,audio,cdrom -s /bin/zsh ${username}
passwd ${username}

## Disable root login
passwd -l root

## Create an empty zsh config file so the first run init do not appear when changing user
echo "# This is a dump comment" > /home/${username}/.zshrc
## Set up environment for script continuation
chown ${username}:${username} /home/${username}/.zshrc

su - ${username} -c 'bash -s' <<'EOF'
#!/usr/bin/env bash
set-e # Breche direkt ab, wenn ein Fehler auftritt

## Das Zsh Install Script dazu anweisen, nicht automatisch die Shell zu wechseln.
export CHSH=no
export RUNZSH=no

cd ~/

## Setup Oh-My-Zsh
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
## Setup Auto Update
sed -i '/zstyle .*mode auto/ s/^#\s*//' ~/.zshrc
## Set the correct date format
sed -i 's/^#\s*HIST_STAMPS="mm\/dd\/yyyy"/HIST_STAMPS="dd.mm.yyyy"/' ~/.zshrc
## Set the EDITOR env variable in zshrc
echo "export EDITOR='nvim'" >> ~/.zshrc
## Install Oh-My-ZSH Plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
sed -i '/^plugins=(/ s/)/ colored-man-pages zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

## Delete zshrc backup file
rm .zshrc.pre-oh-my-zsh
EOF

echo "Installation finished. You are now logged in as the new user."
cd /home/${username}
su ${username}
