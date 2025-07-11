# Stage 1: Base Bazzite with Nix and Hyprland environment
FROM ghcr.io/ublue-os/bazzite-nvidia:latest AS builder

USER root

# Install prerequisites for Nix and other tools
RUN rpm-ostree install -y curl git wget util-linux-user shadow-utils && \
    rpm-ostree cleanup -m && \
    systemd-tmpfiles --create --remove

# Install Nix (multi-user installation)
# This creates /etc/profile.d/nix.sh for system-wide sourcing.
RUN curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes && \
    mkdir -p /etc/profile.d && \
    echo 'if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; fi' > /etc/profile.d/nix.sh

# Source Nix environment for subsequent RUN commands
ENV PATH /nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/per-user/root/profile/bin:$PATH
SHELL ["/bin/bash", "-c"]

# Initialize Nix channels
RUN . /etc/profile.d/nix.sh && \
    echo "Nix path: $PATH" && \
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs && \
    nix-channel --update && \
    echo "Nix setup complete."

# Install Hyprland and JaKooLit's dependencies via Nix.
# For comments on packages, see previous versions or external documentation.
RUN . /etc/profile.d/nix.sh && \
    nix-env -iA \
    nixpkgs.hyprland \
    nixpkgs.ags \
    nixpkgs.fastfetch \
    nixpkgs.rofi-wayland \
    nixpkgs.waybar \
    nixpkgs.kitty \
    nixpkgs.swaynotificationcenter \
    nixpkgs.cava \
    nixpkgs.qt5ct \
    nixpkgs.qt6ct \
    nixpkgs.swappy \
    nixpkgs.wallust \
    nixpkgs.wlogout \
    nixpkgs.imagemagick \
    nixpkgs.playerctl \
    nixpkgs.brightnessctl \
    nixpkgs.pamixer \
    nixpkgs.grim \
    nixpkgs.slurp \
    nixpkgs.wl-clipboard \
    nixpkgs.jq \
    nixpkgs.libnotify \
    nixpkgs.bc \
    nixpkgs.nerdfonts.JetBrainsMono \
    nixpkgs.font-awesome \
    nixpkgs.material-design-icons

# Stage 2: Final image with dotfiles and user setup
FROM ghcr.io/ublue-os/bazzite-nvidia:latest

USER root

# Remove KDE Plasma Desktop Environment
RUN rpm-ostree override remove \
    plasma-desktop \
    plasma-workspace \
    kde-spectacle \
    dolphin \
    konsole \
    kate \
    gwenview \
    okular \
    khelpcenter \
    plasma-discover \
    plasma-pa \
    powerdevil \
    kdialog \
    kgamma5 \
    kpipewire \
    kscreen \
    ksshaskpass \
    ksystemats \
    kwallet-pam \
    kwayland-integration \
    kwincommon \
    libkworkspace5 \
    plasma-browser-integration \
    plasma-integration \
    plasma-nm \
    plasma-sdk \
    plasma-systemmonitor \
    plasma-vault \
    plasma-welcome \
    plasma-workspace-wallpapers \
    sddm-kcm \
    systemsettings \
    kactivities-kf5 \
    kactivitymanagerd \
    bluedevil \
    breeze \
    drkonqi \
    flatpak-kcm \
    kde-cli-tools \
    kde-gtk-config \
    kdeplasma-addons \
    khotkeys \
    kinfocenter \
    kmenuedit \
    ksystemlog \
    kwrited \
    oxygen-sounds \
    plasma-firewall \
    polkit-kde \
    xdg-desktop-portal-kde && \
    rpm-ostree cleanup -m

COPY --from=builder /nix /nix
COPY --from=builder /etc/profile.d/nix.sh /etc/profile.d/nix.sh

ARG SKEL_DIR=/etc/skel
RUN mkdir -p ${SKEL_DIR}/.config ${SKEL_DIR}/Pictures/wallpapers

# Fetch JaKooLit's dotfiles, apply them, and configure
RUN curl -L -o /tmp/Hyprland-Dots.tar.gz https://github.com/JaKooLit/Hyprland-Dots/archive/refs/heads/main.tar.gz && \
    mkdir -p /tmp/Hyprland-Dots && \
    tar -xzf /tmp/Hyprland-Dots.tar.gz -C /tmp/Hyprland-Dots --strip-components=1 && \
    cp -r /tmp/Hyprland-Dots/config/* ${SKEL_DIR}/.config/ && \
    sed -i \
        -e 's/^#env = LIBVA_DRIVER_NAME,nvidia/env = LIBVA_DRIVER_NAME,nvidia/' \
        -e 's/^#env = __GLX_VENDOR_LIBRARY_NAME,nvidia/env = __GLX_VENDOR_LIBRARY_NAME,nvidia/' \
        -e 's/^#env = NVD_BACKEND,direct/env = NVD_BACKEND,direct/' \
        ${SKEL_DIR}/.config/hypr/UserConfigs/ENVariables.conf && \
    sed -i \
        -e 's/kb_layout = .*/kb_layout = us/' \
        -e 's/no_hardware_cursors = .*/no_hardware_cursors = 1/' \
        ${SKEL_DIR}/.config/hypr/UserConfigs/UserSettings.conf && \
    cp -r /tmp/Hyprland-Dots/wallpapers/* ${SKEL_DIR}/Pictures/wallpapers/ && \
    find ${SKEL_DIR}/.config/hypr/scripts/ -type f -exec chmod +x {} \; && \
    find ${SKEL_DIR}/.config/hypr/UserScripts/ -type f -exec chmod +x {} \; && \
    (chmod +x ${SKEL_DIR}/.config/hypr/initial-boot.sh || true) && \
    echo "wallust run ${SKEL_DIR}/Pictures/wallpapers/JaKooLit-Hyprland-Dark.png" > ${SKEL_DIR}/.config/hypr/scripts/init_wallust.sh && \
    chmod +x ${SKEL_DIR}/.config/hypr/scripts/init_wallust.sh && \
    echo -e "\n# Initialize Wallust with default wallpaper\nexec-once = bash ${SKEL_DIR}/.config/hypr/scripts/init_wallust.sh" >> ${SKEL_DIR}/.config/hypr/hyprland.conf && \
    rm -rf /tmp/Hyprland-Dots /tmp/Hyprland-Dots.tar.gz

# Create Hyprland Wayland session file
RUN mkdir -p /usr/share/wayland-sessions && \
    echo -e "[Desktop Entry]\nName=Hyprland (Nix)\nComment=Hyprland via Nix\nExec=/nix/var/nix/profiles/default/bin/Hyprland\nType=Application" > /usr/share/wayland-sessions/hyprland-nix.desktop

# Ensure user shells source Nix environment
RUN echo 'if [ -e /etc/profile.d/nix.sh ]; then . /etc/profile.d/nix.sh; fi' >> ${SKEL_DIR}/.bashrc
RUN echo 'if [ -e /etc/profile.d/nix.sh ]; then . /etc/profile.d/nix.sh; fi' >> ${SKEL_DIR}/.zshrc || true

# Define image metadata
# Moved comments above LABEL instructions
# Name of the image
LABEL name="bazzite-dx-nvidia"
# Version of this custom build
LABEL version="0.1"
# Description of the image
LABEL description="Bazzite DX Nvidia base image without KDE/GNOME, with Hyprland installed via Nix."
