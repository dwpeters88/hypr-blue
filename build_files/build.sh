#!/usr/bin/env bash

set -ouex pipefail

# Get Fedora version
RELEASE="$(rpm -E %fedora)"

# Install Hyprland and dependencies
rpm-ostree install \
    hyprland \
    hyprland-contrib \
    hyprpaper \
    hyprpicker \
    hypridle \
    hyprlock \
    xdg-desktop-portal-hyprland \
    waybar \
    wofi \
    mako \
    kitty \
    qt5-qtwayland \
    qt6-qtwayland \
    polkit-gnome \
    network-manager-applet \
    pavucontrol \
    brightnessctl \
    playerctl \
    wl-clipboard \
    grim \
    slurp \
    swappy \
    thunar \
    thunar-archive-plugin \
    file-roller \
    blueman \
    otf-font-awesome \
    ttf-jetbrains-mono \
    ttf-jetbrains-mono-nerd \
    ttf-ubuntu-font-family \
    mozilla-fira-sans-fonts \
    mozilla-fira-mono-fonts \
    google-noto-emoji-fonts \
    google-noto-emoji-color-fonts

# Configure SELinux contexts for OSTree
semanage fcontext -a -t container_file_t '/usr/share/hypr(/.*)?'
restorecon -R /usr/share/hypr || true

# Fix permissions
chmod 755 /usr/bin/*

# Create necessary directories
mkdir -p /usr/share/wayland-sessions
mkdir -p /usr/share/xsessions
mkdir -p /usr/etc/skel/.config

# Copy Hyprland session file if not exists
if [ ! -f /usr/share/wayland-sessions/hyprland.desktop ]; then
    cat > /usr/share/wayland-sessions/hyprland.desktop << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An independent, highly customizable, dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
EOF
fi

# Enable required services
systemctl enable polkit.service || true

# Clean up
rm -rf /tmp/* /var/tmp/*

echo "Build completed successfully"