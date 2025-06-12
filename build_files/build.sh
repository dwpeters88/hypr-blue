#!/bin/bash

set -ouex pipefail
export HOME=/root

echo "--- Setting up DNF configuration ---"
echo "[main]" > /etc/dnf/dnf.conf
echo "max_parallel_downloads=5" >> /etc/dnf/dnf.conf
echo "fastestmirror=True" >> /etc/dnf/dnf.conf
echo "defaultyes=True" >> /etc/dnf/dnf.conf
echo "DNF configuration updated."

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

echo "--- Ensuring user 'dee' exists ---"
if ! id -u dee > /dev/null 2>&1; then
    useradd -m -s /bin/bash dee # -m creates home dir, -s sets shell
    echo "User 'dee' created."
else
    echo "User 'dee' already exists."
fi
# Ensure /home/dee/.config exists and has correct ownership if useradd didn't run or if dir was created by rsync as root
mkdir -p /home/dee/.config
# Initial chown for /home/dee, more specific chown for .config will follow after content copy
chown -R dee:dee /home/dee || echo "Warning: Failed to chown /home/dee. This might be okay if user 'dee' doesn't exist yet or if running in a rootless container context that handles this."

echo "--- Cloning Hyprland-Dots repository ---"
# git is installed as part of 'hyprland' group or other dev packages.
# If this fails, ensure git is explicitly installed earlier.
git clone --depth=1 https://github.com/JaKooLit/Hyprland-Dots.git /tmp/Hyprland-Dots
if [ ! -d /tmp/Hyprland-Dots/config ]; then
    echo "ERROR: Failed to clone Hyprland-Dots or config directory not found."
    exit 1
fi
echo "Hyprland-Dots cloned successfully."

echo "--- Copying dotfiles to /home/dee/.config ---"
# User 'dee' and /home/dee should exist from the block above.
# mkdir -p /home/dee/.config is already done during user creation.
rsync -av --exclude='.git' /tmp/Hyprland-Dots/config/ /home/dee/.config/
echo "Dotfiles copied to /home/dee/.config."

echo "--- Setting keyboard layout to za for user 'dee' ---"
if [ -f /home/dee/.config/hypr/UserConfigs/UserSettings.conf ]; then
    sed -i 's/kb_layout = us/kb_layout = za/g' /home/dee/.config/hypr/UserConfigs/UserSettings.conf
    echo "Keyboard layout set to za in /home/dee/.config."
else
    echo "WARNING: UserSettings.conf not found in /home/dee/.config, cannot set keyboard layout."
fi

echo "--- Setting up default wallpapers for user 'dee' ---"
# Wallpapers are globally available, just linking for user 'dee'
mkdir -p /usr/share/backgrounds/hyprland_community_wallpapers # This might be redundant if already created
rsync -av /tmp/Hyprland-Dots/wallpapers/ /usr/share/backgrounds/hyprland_community_wallpapers/

mkdir -p /home/dee/.config/hypr/wallpaper_effects
DEFAULT_WALLPAPER_NAME="catppuccin.png" # Choose a suitable default
if [ -f "/usr/share/backgrounds/hyprland_community_wallpapers/${DEFAULT_WALLPAPER_NAME}" ]; then
    ln -sf "/usr/share/backgrounds/hyprland_community_wallpapers/${DEFAULT_WALLPAPER_NAME}" "/home/dee/.config/hypr/wallpaper_effects/.wallpaper_current"
    echo "Default wallpaper linked to ${DEFAULT_WALLPAPER_NAME} for user 'dee'."
else
    # Fallback: try to link the first png found if catppuccin.png is not there
    FIRST_PNG=$(find /usr/share/backgrounds/hyprland_community_wallpapers -maxdepth 1 -type f -name "*.png" | head -n 1)
    if [ -n "$FIRST_PNG" ]; then
         ln -sf "$FIRST_PNG" "/home/dee/.config/hypr/wallpaper_effects/.wallpaper_current"
         echo "Default wallpaper linked to $(basename "$FIRST_PNG") for user 'dee'."
    else
        echo "WARNING: No default wallpaper found to link for user 'dee'."
    fi
fi
echo "Default wallpapers set up for user 'dee'."

echo "--- Making initial-boot.sh executable for user 'dee' ---"
if [ -f /home/dee/.config/hypr/initial-boot.sh ]; then
    chmod +x /home/dee/.config/hypr/initial-boot.sh
    echo "initial-boot.sh made executable in /home/dee/.config."
else
    echo "WARNING: initial-boot.sh not found in /home/dee/.config."
fi

echo "--- Setting ownership for /home/dee/.config ---"
chown -R dee:dee /home/dee/.config || echo "Warning: Failed to chown /home/dee/.config. This might be okay if user 'dee' doesn't exist or if running in a rootless container context that handles this."
echo "Ownership set for /home/dee/.config."

# Install RPM Fusion free and nonfree repositories
dnf5 install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Enable Bazzite and uBlue COPRs
dnf5 copr enable -y bazzite-org/bazzite
dnf5 copr enable -y ublue-os/packages
dnf5 copr enable -y solopasha/hyprland
dnf5 copr enable -y erikreider/SwayNotificationCenter
dnf5 copr enable -y errornointernet/packages
dnf5 copr enable -y tofik/nwg-shell

# Restrict packages from certain COPRs
echo "--- Applying package restrictions to COPR repos ---"
# Ensure the COPR repo files exist before attempting to append.
# The dnf5 copr enable command should have created them.

COPR_REPO_ERRORNOINTERNET="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:errornointernet:packages.repo"
COPR_REPO_TOFIK_NWGSHELL="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:tofik:nwg-shell.repo"

if [ -f "$COPR_REPO_ERRORNOINTERNET" ]; then
    echo "includepkgs=wallust" >> "$COPR_REPO_ERRORNOINTERNET"
    echo "Restricted errornointernet/packages to wallust."
else
    echo "WARNING: $COPR_REPO_ERRORNOINTERNET not found. Cannot apply package restriction."
fi

if [ -f "$COPR_REPO_TOFIK_NWGSHELL" ]; then
    echo "includepkgs=nwg-displays" >> "$COPR_REPO_TOFIK_NWGSHELL"
    echo "Restricted tofik/nwg-shell to nwg-displays."
else
    echo "WARNING: $COPR_REPO_TOFIK_NWGSHELL not found. Cannot apply package restriction."
fi
echo "Package restrictions applied."

# Install Hyprland and essential desktop components
dnf5 update -y
dnf5 install -y \
  hyprland waybar wofi kitty swaybg swayidle swaylock \
  SwayNotificationCenter swappy swww \
  pipewire wireplumber pipewire-alsa pipewire-jack-audio-connection-kit \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  tumbler ffmpegthumbnailer brightnessctl gvfs gvfs-mtp \
  qt5ct qt6ct qt6-qtsvg kvantum \
  sddm sddm-wayland-generic \
  akmod-nvidia xorg-x11-drv-nvidia-cuda libva libva-nvidia-driver \
  bc cava cliphist fastfetch gnome-system-monitor hyprpolkitagent ImageMagick \
  inxi loupe mpv mpv-mpris network-manager-applet nwg-displays nwg-look \
  nvtop pamixer pavucontrol playerctl python3-pip python3-pyquery \
  python3-requests qalculate-gtk rofi-wayland unzip wallust wlogout yad

# Install Bazzite-DX applications
dnf5 install -y \
  gamescope-session-plus gamescope-session-steam \
  android-tools bcc bpftop bpftrace flatpak-builder ccache nicstat numactl \
  jq rsync \
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

echo "--- Configuring kernel arguments for Nvidia ---"
rpm-ostree kargs --append=rd.driver.blacklist=nouveau --append=modprobe.blacklist=nouveau --append=nvidia-drm.modeset=1 --append=nvidia_drm.fbdev=1
echo "Nvidia kernel arguments configured."

echo "--- Cloning Wallpaper-Bank repository ---"
# Ensure git is installed
git clone --depth=1 https://github.com/JaKooLit/Wallpaper-Bank.git /usr/share/backgrounds/JaKooLit-Wallpaper-Bank
if [ ! -d /usr/share/backgrounds/JaKooLit-Wallpaper-Bank ]; then
    echo "WARNING: Failed to clone Wallpaper-Bank."
    # For wallpapers, a warning is acceptable. The build can continue.
else
    echo "Wallpaper-Bank cloned successfully to /usr/share/backgrounds/JaKooLit-Wallpaper-Bank."
fi

echo "--- Cleaning up Hyprland-Dots temporary clone ---"
rm -rf /tmp/Hyprland-Dots
echo "Temporary clone removed."

# Clean up
dnf5 clean all
