#!/bin/bash

set -ouex pipefail
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

<<<<<<< ours
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
=======
# Install Bazzite-DX applications (bcc, bpftrace, bpftop removed)
dnf5 install -y \
  gamescope-session-plus gamescope-session-steam \
  android-tools flatpak-builder ccache nicstat numactl \
  podman-machine podman-tui python3-ramalama qemu-kvm restic rclone \
  sysprof tiptop zsh ublue-setup-services

# Install Cursor AppImage
echo "--- Installing Cursor ---"
CURSOR_APPIMAGE_URL="https://download.cursor.sh/linux/latest/Cursor.AppImage" # !!! USER: VERIFY THIS URL !!!
CURSOR_INSTALL_DIR="/opt/Cursor"
CURSOR_APPIMAGE_NAME="Cursor.AppImage"
CURSOR_DESKTOP_FILE_PATH="/usr/share/applications/cursor.desktop"

mkdir -p "$CURSOR_INSTALL_DIR"
if command -v curl >/dev/null 2>&1; then
  curl -L "$CURSOR_APPIMAGE_URL" -o "$CURSOR_INSTALL_DIR/$CURSOR_APPIMAGE_NAME"
elif command -v wget >/dev/null 2>&1; then
  wget "$CURSOR_APPIMAGE_URL" -O "$CURSOR_INSTALL_DIR/$CURSOR_APPIMAGE_NAME"
else
  echo "ERROR: Neither curl nor wget is available to download Cursor. Please install one of them."
  # If this is critical, you might want to exit: exit 1
fi

if [ -f "$CURSOR_INSTALL_DIR/$CURSOR_APPIMAGE_NAME" ]; then
  chmod +x "$CURSOR_INSTALL_DIR/$CURSOR_APPIMAGE_NAME"
  echo "Cursor downloaded and made executable at $CURSOR_INSTALL_DIR/$CURSOR_APPIMAGE_NAME"

  # Create .desktop file for Cursor using echo commands
  echo "Creating .desktop file for Cursor..."
  echo "[Desktop Entry]" > "$CURSOR_DESKTOP_FILE_PATH"
  echo "Name=Cursor" >> "$CURSOR_DESKTOP_FILE_PATH"
  echo "Comment=AI First Code Editor" >> "$CURSOR_DESKTOP_FILE_PATH"
  echo "Exec=$CURSOR_INSTALL_DIR/$CURSOR_APPIMAGE_NAME --no-sandbox %U" >> "$CURSOR_DESKTOP_FILE_PATH"
  echo "Icon=cursor # Placeholder: User may need to download an icon and set the full path" >> "$CURSOR_DESKTOP_FILE_PATH"
  echo "Type=Application" >> "$CURSOR_DESKTOP_FILE_PATH"
  echo "Categories=Development;IDE;TextEditor;" >> "$CURSOR_DESKTOP_FILE_PATH"
  echo "StartupWMClass=Cursor" >> "$CURSOR_DESKTOP_FILE_PATH"
  echo "MimeType=text/plain;inode/directory;" >> "$CURSOR_DESKTOP_FILE_PATH"
  echo ".desktop file created at $CURSOR_DESKTOP_FILE_PATH"
else
  echo "ERROR: Cursor AppImage download failed from $CURSOR_APPIMAGE_URL. Please check the URL."
  # Consider exiting with an error if Cursor is essential: exit 1
fi
echo "--- Cursor Installation Attempted ---"

# Install Warp Terminal
echo "--- Installing Warp Terminal ---"
WARP_RPM_URL="https://app.warp.dev/get_warp?package=rpm"
WARP_RPM_LOCAL_PATH="/tmp/warp-terminal-latest.rpm"

if command -v curl >/dev/null 2>&1; then
  curl -L "$WARP_RPM_URL" -o "$WARP_RPM_LOCAL_PATH"
elif command -v wget >/dev/null 2>&1; then
  wget "$WARP_RPM_URL" -O "$WARP_RPM_LOCAL_PATH"
else
  echo "ERROR: Neither curl nor wget is available to download Warp Terminal. Please install one of them."
fi

if [ -f "$WARP_RPM_LOCAL_PATH" ]; then
  echo "Warp Terminal RPM downloaded to $WARP_RPM_LOCAL_PATH"
  dnf5 install -y "$WARP_RPM_LOCAL_PATH"
  rm -f "$WARP_RPM_LOCAL_PATH"
  echo "Warp Terminal installed and RPM cleaned up."
else
  echo "ERROR: Warp Terminal RPM download failed from $WARP_RPM_URL."
fi
echo "--- Warp Terminal Installation Attempted ---"
>>>>>>> theirs

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
<<<<<<< ours
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
=======

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
EOF
>>>>>>> theirs
