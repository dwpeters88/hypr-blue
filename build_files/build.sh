#!/bin/bash

set -ouex pipefail
set -x # Ensure all commands and their arguments are printed
export HOME=/root
echo "--- GPG SETUP START ---"
echo "Original HOME: $HOME"
RESOLVED_HOME_PATH="$(readlink -f "$HOME")"
if [ -z "$RESOLVED_HOME_PATH" ]; then
    echo "ERROR: Could not resolve real path for $HOME. Exiting."
    exit 1
fi
echo "Resolved HOME path: $RESOLVED_HOME_PATH"
REAL_GNUPG_DIR="$RESOLVED_HOME_PATH/.gnupg"

echo "Ensuring GPG directory exists at resolved path: $REAL_GNUPG_DIR"
# Create the parent directory first if it doesn't exist, then the .gnupg dir
# This is to handle cases where /var/roothome might not exist, though unlikely for a resolved path.
mkdir -vp "$(dirname "$REAL_GNUPG_DIR")"
mkdir -vp "$REAL_GNUPG_DIR"

if [ ! -d "$REAL_GNUPG_DIR" ]; then
  echo "ERROR: $REAL_GNUPG_DIR was NOT created."
  echo "Listing details:"
  echo "HOME: $HOME"
  ls -ld "$HOME" || echo "> $HOME not found or not listable"
  echo "RESOLVED_HOME_PATH: $RESOLVED_HOME_PATH"
  ls -ld "$RESOLVED_HOME_PATH" || echo "> $RESOLVED_HOME_PATH not found or not listable"
  echo "Parent of REAL_GNUPG_DIR: $(dirname "$REAL_GNUPG_DIR")"
  ls -ld "$(dirname "$REAL_GNUPG_DIR")" || echo "> Parent of $REAL_GNUPG_DIR not found or not listable"
  echo "REAL_GNUPG_DIR itself: $REAL_GNUPG_DIR"
  ls -ld "$REAL_GNUPG_DIR" || echo "> $REAL_GNUPG_DIR not found or not listable after mkdir attempt"
  exit 1
fi
chmod 700 "$REAL_GNUPG_DIR"
echo "GPG directory $REAL_GNUPG_DIR ensured and permissions set."
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

# Install Bazzite-DX applications (bcc, bpftrace, bpftop removed)
dnf5 install -y \
  gamescope-session-plus gamescope-session-steam \
  android-tools flatpak-builder ccache nicstat numactl \
  podman-machine podman-tui python3-ramalama qemu-kvm restic rclone \
  sysprof tiptop zsh ublue-setup-services

# Install Docker CE
echo "Starting Docker CE repository setup..."
sh -c 'echo -e "[docker-ce-stable]\nname=Docker CE Stable - \$basearch\nbaseurl=https://download.docker.com/linux/fedora/\$releasever/\$basearch/stable\nenabled=1\ngpgcheck=1\ngpgkey=https://download.docker.com/linux/fedora/gpg" > /etc/yum.repos.d/docker-ce.repo'
echo "Docker CE repository setup complete."

echo "Starting Docker CE packages installation..."
dnf5 install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "Docker CE package installation failed. Exit code: $EXIT_CODE"
  exit 1
fi
echo "Docker CE packages installation complete."

systemctl enable docker.service
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "Failed to enable docker.service. Exit code: $EXIT_CODE"
fi
systemctl enable containerd.service
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "Failed to enable containerd.service. Exit code: $EXIT_CODE"
fi

echo "Configuring iptable_nat kernel module..."
(mkdir -p /etc/modules-load.d && echo "iptable_nat" > /etc/modules-load.d/ip_tables.conf)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "Warning: Failed to configure iptable_nat kernel module. Exit code: $EXIT_CODE. This might cause Docker runtime issues."
fi
echo "iptable_nat kernel module configuration attempted."

# Remove conflicting desktop environments (defensive)
dnf5 remove -y gnome-shell plasma-desktop kde-plasma-desktop xfce4-session mate-desktop cinnamon-desktop || echo "No conflicting DEs found or removal failed, continuing."

# Enable essential services
systemctl enable sddm

# Create a basic Hyprland desktop entry for SDDM
echo "Creating .desktop file for Hyprland..."
HYPRLAND_DESKTOP_FILE_PATH="/usr/share/wayland-sessions/hyprland.desktop"
mkdir -p "$(dirname "$HYPRLAND_DESKTOP_FILE_PATH")"
echo "[Desktop Entry]" > "$HYPRLAND_DESKTOP_FILE_PATH"
echo "Name=Hyprland" >> "$HYPRLAND_DESKTOP_FILE_PATH"
echo "Comment=An intelligent dynamic tiling Wayland compositor" >> "$HYPRLAND_DESKTOP_FILE_PATH"
echo "Exec=Hyprland" >> "$HYPRLAND_DESKTOP_FILE_PATH"
echo "Type=Application" >> "$HYPRLAND_DESKTOP_FILE_PATH"
echo ".desktop file created at $HYPRLAND_DESKTOP_FILE_PATH"

# Clean up
dnf5 clean all
