# Build context for scripts
FROM scratch AS ctx
COPY build_files /

# Base Image - Bazzite with AMD x86_64 platform specification
FROM --platform=linux/amd64 ghcr.io/ublue-os/bazzite:stable

# CRITICAL: Add OSTree metadata labels for bootable image
LABEL ostree.bootable="true"
LABEL com.coreos.ostree="true"
LABEL org.opencontainers.image.title="hypr-blue"
LABEL org.opencontainers.image.description="Custom Fedora 42 Bazzite with JaKooLit Hyprland"

# Remove GNOME and KDE packages but keep SDDM
RUN rpm-ostree override remove \
    gnome-shell \
    gnome-shell-extension-* \
    gnome-session \
    gnome-session-wayland-session \
    gnome-session-xsession \
    gnome-settings-daemon \
    gnome-software \
    gnome-terminal \
    gnome-text-editor \
    gnome-console \
    gnome-calculator \
    gnome-calendar \
    gnome-characters \
    gnome-clocks \
    gnome-contacts \
    gnome-font-viewer \
    gnome-logs \
    gnome-maps \
    gnome-weather \
    gnome-disk-utility \
    gnome-system-monitor \
    gnome-control-center \
    gnome-tweaks \
    gdm \
    plasma-desktop \
    plasma-workspace \
    plasma-workspace-wayland \
    plasma-workspace-x11 \
    kde-settings \
    kde-settings-plasma \
    kwin \
    || true \
    && rpm-ostree cleanup -m \
    && ostree container commit

# Install SDDM and qt dependencies
RUN rpm-ostree install \
    sddm \
    qt5-qtbase \
    qt5-qtdeclarative \
    qt5-qtquickcontrols \
    qt5-qtquickcontrols2 \
    qt5-qtgraphicaleffects \
    qt5-qtsvg \
    qt5-qtmultimedia \
    && rpm-ostree cleanup -m \
    && ostree container commit

# Install Nvidia drivers and Hyprland packages (including JaKooLit's requirements)
RUN rpm-ostree install \
    akmod-nvidia \
    xorg-x11-drv-nvidia \
    xorg-x11-drv-nvidia-cuda \
    xorg-x11-drv-nvidia-cuda-libs \
    xorg-x11-drv-nvidia-libs \
    nvidia-vaapi-driver \
    libva-nvidia-driver \
    nvidia-container-toolkit \
    hyprland \
    hyprland-contrib \
    hyprpaper \
    hyprlock \
    hypridle \
    hyprpicker \
    xdg-desktop-portal-hyprland \
    waybar \
    waybar-mpris \
    kitty \
    wofi \
    mako \
    polkit-gnome \
    wl-clipboard \
    cliphist \
    grim \
    slurp \
    swappy \
    thunar \
    thunar-volman \
    thunar-archive-plugin \
    tumbler \
    gvfs \
    gvfs-mtp \
    gvfs-gphoto2 \
    gvfs-smb \
    gvfs-nfs \
    network-manager-applet \
    blueman \
    pavucontrol \
    brightnessctl \
    playerctl \
    pamixer \
    qt5-qtwayland \
    qt6-qtwayland \
    kvantum \
    qt5ct \
    qt6ct \
    fontawesome-fonts-all \
    google-noto-fonts-common \
    google-noto-emoji-fonts \
    google-noto-sans-cjk-fonts \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    mozilla-fira-mono-fonts \
    mozilla-fira-sans-fonts \
    jetbrains-mono-fonts-all \
    swaybg \
    swayidle \
    python3-pip \
    python3-gobject \
    python3-pywal \
    ImageMagick \
    parallel \
    jq \
    gjs \
    socat \
    rsync \
    unzip \
    gvfs-fuse \
    lxappearance \
    xfce4-settings \
    nwg-look \
    kvantum-qt5 \
    kvantum-themes \
    && rpm-ostree cleanup -m \
    && ostree container commit

# Install additional tools from JaKooLit's setup
RUN rpm-ostree install \
    python3-pip \
    python3-pillow \
    python3-pywayland \
    python3-screeninfo \
    eza \
    yad \
    fastfetch \
    btop \
    cava \
    mousepad \
    ranger \
    rofi-wayland \
    swaync \
    nwg-displays \
    nwg-dock-hyprland \
    nwg-drawer \
    nwg-menu \
    nwg-look \
    azote \
    hyprshot \
    wlogout \
    wlsunset \
    aylurs-gtk-shell \
    && rpm-ostree cleanup -m \
    && ostree container commit

# Clone and install JaKooLit's Hyprland-Dots and SDDM theme
RUN git clone --depth=1 https://github.com/JaKooLit/Hyprland-Dots /tmp/Hyprland-Dots && \
    git clone --depth=1 https://github.com/JaKooLit/Wallpaper-Bank /tmp/Wallpaper-Bank && \
    git clone --depth=1 https://github.com/JaKooLit/simple-sddm-2 /tmp/simple-sddm-2 && \
    cd /tmp/Hyprland-Dots && \
    mkdir -p /usr/etc/skel/.config && \
    mkdir -p /usr/etc/skel/.local/share && \
    mkdir -p /usr/etc/skel/Pictures/wallpapers && \
    cp -r config/* /usr/etc/skel/.config/ && \
    cp -r wallpapers/* /usr/etc/skel/Pictures/wallpapers/ && \
    # Copy additional wallpapers from Wallpaper-Bank
    cp -r /tmp/Wallpaper-Bank/wallpapers/* /usr/etc/skel/Pictures/wallpapers/ && \
    # Set up fonts
    mkdir -p /usr/share/fonts/JaKooLit && \
    cp -r assets/fonts/* /usr/share/fonts/JaKooLit/ && \
    fc-cache -f -v && \
    # Install SDDM theme
    mkdir -p /usr/share/sddm/themes && \
    cp -r /tmp/simple-sddm-2 /usr/share/sddm/themes/simple-sddm-2 && \
    # Clean up
    rm -rf /tmp/Hyprland-Dots /tmp/Wallpaper-Bank /tmp/simple-sddm-2 && \
    ostree container commit

# Configure SDDM
RUN mkdir -p /usr/etc/sddm.conf.d && \
    cat > /usr/etc/sddm.conf.d/default.conf << 'EOF'
[Theme]
Current=simple-sddm-2
CursorTheme=Bibata-Modern-Ice
Font="Noto Sans,10,-1,5,50,0,0,0,0,0"

[General]
HaltCommand=/usr/bin/systemctl poweroff
Numlock=on
RebootCommand=/usr/bin/systemctl reboot

[Users]
DefaultPath=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HideShells=
HideUsers=
RememberLastSession=true
RememberLastUser=true

[Wayland]
EnableHiDPI=true
SessionCommand=/usr/share/sddm/scripts/wayland-session
SessionDir=/usr/share/wayland-sessions
SessionLogFile=.local/share/sddm/wayland-session.log

[X11]
EnableHiDPI=true
MinimumVT=1
ServerPath=/usr/bin/X
SessionCommand=/usr/share/sddm/scripts/Xsession
SessionDir=/usr/share/xsessions
SessionLogFile=.local/share/sddm/xorg-session.log
UserAuthFile=.Xauthority
XauthPath=/usr/bin/xauth
XephyrPath=/usr/bin/Xephyr
EOF

# Create SDDM theme configuration
RUN mkdir -p /usr/share/sddm/themes/simple-sddm-2 && \
    cat > /usr/share/sddm/themes/simple-sddm-2/theme.conf << 'EOF'
[General]
background=/usr/share/backgrounds/sddm/sddm-wallpaper.jpg
displayFont="Noto Sans"
EOF

# Copy a wallpaper for SDDM background
RUN mkdir -p /usr/share/backgrounds/sddm && \
    echo "SDDM wallpaper will be set during user setup" > /usr/share/backgrounds/sddm/README

# Create Hyprland desktop entry
RUN mkdir -p /usr/share/wayland-sessions && \
    cat > /usr/share/wayland-sessions/hyprland.desktop << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Dynamic tiling Wayland compositor with JaKooLit config
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;
Categories=System;
EOF

# Set Nvidia environment variables for Wayland
RUN mkdir -p /usr/etc/environment.d && \
    cat > /usr/etc/environment.d/nvidia-hyprland.conf << 'EOF'
LIBVA_DRIVER_NAME=nvidia
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
__GL_GSYNC_ALLOWED=1
__GL_VRR_ALLOWED=1
WLR_DRM_NO_ATOMIC=1
WLR_RENDERER=vulkan
NIXOS_OZONE_WL=1
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
QT_AUTO_SCREEN_SCALE_FACTOR=1
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_DESKTOP=Hyprland
XDG_SESSION_TYPE=wayland
EOF

# Configure Hyprland for 1440p resolution
RUN mkdir -p /usr/etc/skel/.config/hypr && \
    cat > /usr/etc/skel/.config/hypr/monitors.conf << 'EOF'
# Monitor configuration for 1440p
# Adjust the monitor name (DP-1, HDMI-A-1, etc.) based on your setup
monitor=,2560x1440@144,0x0,1

# Example configurations:
# monitor=DP-1,2560x1440@144,0x0,1
# monitor=HDMI-A-1,2560x1440@60,0x0,1
# monitor=,preferred,auto,1  # Fallback
EOF

# Add custom Hyprland settings for JaKooLit config
RUN cat >> /usr/etc/skel/.config/hypr/userprefs.conf << 'EOF'
# User preferences for 1440p display
general {
    gaps_in = 3
    gaps_out = 8
    border_size = 2
}

decoration {
    rounding = 10
    blur {
        enabled = true
        size = 6
        passes = 3
        new_optimizations = true
        ignore_opacity = true
        xray = true
    }
}

# Nvidia specific settings
env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
env = WLR_RENDERER,vulkan

# Font rendering for 1440p
env = GDK_SCALE,1
env = XCURSOR_SIZE,24
EOF

# Create initial wallpaper setup script
RUN cat > /usr/etc/skel/.config/hypr/scripts/wallpaper-init.sh << 'EOF'
#!/bin/bash
# Initialize wallpaper for first run
if [ ! -f ~/.cache/.wallpaper_current ]; then
    WALLPAPER=$(find ~/Pictures/wallpapers -type f \( -name "*.jpg" -o -name "*.png" \) | shuf -n 1)
    ln -sf "$WALLPAPER" ~/.cache/.wallpaper_current
    # Also set SDDM wallpaper if we have sudo access
    if command -v sudo &> /dev/null; then
        sudo cp "$WALLPAPER" /usr/share/backgrounds/sddm/sddm-wallpaper.jpg 2>/dev/null || true
    fi
fi
EOF && \
    chmod +x /usr/etc/skel/.config/hypr/scripts/wallpaper-init.sh

# Create first-run setup script
RUN mkdir -p /usr/etc/skel/.config/autostart-scripts && \
    cat > /usr/etc/skel/.config/autostart-scripts/first-run.sh << 'EOF'
#!/bin/bash
# First run setup
if [ ! -f ~/.config/.first-run-done ]; then
    # Initialize wallpaper
    ~/.config/hypr/scripts/wallpaper-init.sh
    
    # Set SDDM to remember last session
    echo "[Last]" > ~/.config/sddm/state.conf
    echo "Session=hyprland" >> ~/.config/sddm/state.conf
    
    # Mark first run as done
    touch ~/.config/.first-run-done
fi
EOF && \
    chmod +x /usr/etc/skel/.config/autostart-scripts/first-run.sh

# Install pywal and dependencies for theming
RUN pip3 install pywal pywayland wallust && \
    ostree container commit

# Enable required services
RUN systemctl enable sddm.service && \
    systemctl enable polkit.service && \
    systemctl enable NetworkManager.service && \
    systemctl enable bluetooth.service || true

# Final cleanup and permissions
RUN mkdir -p /var/roothome && \
    mkdir -p /var/opt && \
    mkdir -p /var/lib/alternatives && \
    chmod -R 755 /usr/etc/skel/.config && \
    ostree container commit
LABEL com.coreos.ostree="true"
LABEL org.opencontainers.image.title="hypr-blue"
LABEL org.opencontainers.image.description="Custom Fedora 42 Bazzite with Hyprland"
LABEL io.buildah.version="1.35.0"

# Set proper OSTree variables
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-42}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-bazzite}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-dwpeters88}"
ARG IMAGE_NAME="${IMAGE_NAME:-hypr-blue}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"

# Run build script with proper mounts
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=tmpfs,dst=/var/tmp \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && \
    # CRITICAL: Properly commit the OSTree container
    ostree container commit && \
    # Clean up to reduce image size
    mkdir -p /var/tmp && \
    chmod 1777 /var/tmp && \
    rm -rf /tmp/* /var/tmp/* && \
    # Final OSTree finalization
    mkdir -p /var/roothome && \
    mkdir -p /var/opt && \
    mkdir -p /var/lib/alternatives && \
    ostree container commit
