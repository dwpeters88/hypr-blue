#!/bin/bash

set -ouex pipefail

# Install RPM Fusion free and nonfree repositories and enable them
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
dnf5 config-manager --add-repo https://packages.microsoft.com/yumrepos/vscode
rpm --import https://packages.microsoft.com/keys/microsoft.asc
dnf5 install -y code

# Install Docker CE
dnf5 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
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
