#!/bin/bash

set -ouex pipefail
export HOME=/root
echo "--- GPG SETUP START ---"
echo "Ensuring GPG directory exists at $HOME/.gnupg (which is $(readlink -f "$HOME")/.gnupg )"
mkdir -vp "$HOME/.gnupg"
if [ ! -d "$HOME/.gnupg" ]; then
  echo "ERROR: $HOME/.gnupg was NOT created."
  echo "Attempting to list $HOME and its target (if symlink):"
  ls -ld "$HOME" || echo "$HOME not found or not listable"
  if [ -L "$HOME" ]; then
    ls -ld "$(readlink -f "$HOME")" || echo "Target of $HOME symlink not found or not listable"
    ls -ld "$(readlink -f "$HOME")/.gnupg" || echo "Target $HOME/.gnupg not found or not listable after mkdir attempt"
  fi
  exit 1
fi
chmod 700 "$HOME/.gnupg"
echo "GPG directory $HOME/.gnupg ensured and permissions set."
echo "--- GPG SETUP END ---"

# Install RPM Fusion free and nonfree repositories
dnf5 install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Enable Bazzite and uBlue COPRs
dnf5 copr enable -y bazzite-org/bazzite
dnf5 copr enable -y ublue-os/packages

# Install Hyprland and essential desktop components
dnf5 update -y
dnf5 install -y \
  hyprland waybar wofi kitty mako swaybg swayidle swaylock \
  pipewire wireplumber pipewire-alsa pipewire-jack-audio-connection-kit \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  tumbler ffmpegthumbnailer brightnessctl gvfs \
  qt5ct qt6ct \
  sddm sddm-wayland-generic

# Install Bazzite-DX applications
dnf5 install -y \
  gamescope-session-plus gamescope-session-steam \
  android-tools bcc bpftop bpftrace flatpak-builder ccache nicstat numactl \
  podman-machine podman-tui python3-ramalama qemu-kvm restic rclone \
  sysprof tiptop zsh ublue-setup-services

# Install VSCode
echo "--- DIAGNOSTICS START ---"
echo "Running as user: $(id)"
echo "Listing /:"
ls -ld /
echo "Listing /root (if it exists):"
ls -ld /root || echo "/root does not exist or cannot be listed."
echo "Filesystem disk space usage:"
df -h
echo "--- DIAGNOSTICS END ---"
rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
dnf5 install -y code

# Install Docker CE
sh -c 'echo -e "[docker-ce-stable]\nname=Docker CE Stable - \$basearch\nbaseurl=https://download.docker.com/linux/fedora/\$releasever/\$basearch/stable\nenabled=1\ngpgcheck=1\ngpgkey=https://download.docker.com/linux/fedora/gpg" > /etc/yum.repos.d/docker-ce.repo'
dnf5 install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker.service
systemctl enable containerd.service
mkdir -p /etc/modules-load.d && echo "iptable_nat" > /etc/modules-load.d/ip_tables.conf

# Remove conflicting desktop environments (defensive)
dnf5 remove -y gnome-shell plasma-desktop kde-plasma-desktop xfce4-session mate-desktop cinnamon-desktop || echo "No conflicting DEs found or removal failed, continuing."

# Enable essential services
systemctl enable sddm
# User services will be enabled via ublue-os/startingpoint or similar mechanism for user session
# e.g. systemctl --user enable pipewire pipewire-pulse wireplumber

# Create a basic Hyprland desktop entry for SDDM
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/hyprland.desktop <<EOF
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF

# Clean up
dnf5 clean all