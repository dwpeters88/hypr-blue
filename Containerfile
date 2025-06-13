ARG FEDORA_MAJOR_VERSION=42

FROM quay.io/fedora/fedora-bootc:${FEDORA_MAJOR_VERSION}

# Set proper labels for bootc
LABEL ostree.bootable="true"
LABEL com.coreos.ostree="true"
LABEL org.opencontainers.image.title="hypr-blue"
LABEL org.opencontainers.image.description="Custom Fedora 42 with Hyprland"

# Install dnf5 and utilities first
RUN rpm-ostree install \
    dnf5 \
    util-linux \
    dnf-plugins-core \
    && ostree container commit

# Since fedora-bootc is minimal, we don't need to remove desktop packages
# They're not installed in the first place

# Add RPM Fusion repositories
RUN dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    && ostree container commit

# Install base system packages
RUN rpm-ostree install \
    NetworkManager-wifi \
    NetworkManager-bluetooth \
    bluez \
    bluez-tools \
    systemd-boot \
    systemd-resolved \
    systemd-networkd \
    polkit \
    udisks2 \
    upower \
    pipewire \
    pipewire-pulseaudio \
    pipewire-alsa \
    wireplumber \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-hyprland \
    gvfs \
    gvfs-mtp \
    gvfs-gphoto2 \
    gvfs-smb \
    && ostree container commit

# Install Hyprland and related packages
RUN rpm-ostree install \
    hyprland \
    waybar \
    wofi \
    mako \
    swaylock \
    swayidle \
    kanshi \
    grim \
    slurp \
    wl-clipboard \
    xorg-x11-server-Xwayland \
    qt5-qtwayland \
    qt6-qtwayland \
    && ostree container commit

# Install terminal and basic utilities
RUN rpm-ostree install \
    kitty \
    foot \
    alacritty \
    zsh \
    fish \
    tmux \
    neovim \
    vim \
    git \
    curl \
    wget \
    htop \
    btop \
    fastfetch \
    && ostree container commit

# Install file managers and utilities
RUN rpm-ostree install \
    thunar \
    thunar-volman \
    thunar-archive-plugin \
    ranger \
    nnn \
    mc \
    && ostree container commit

# Install multimedia packages
RUN rpm-ostree install \
    mpv \
    ffmpeg \
    gstreamer1-plugins-base \
    gstreamer1-plugins-good \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-ugly-free \
    gstreamer1-plugin-libav \
    && ostree container commit

# Install development tools
RUN rpm-ostree install \
    gcc \
    gcc-c++ \
    make \
    cmake \
    meson \
    ninja-build \
    python3 \
    python3-pip \
    nodejs \
    npm \
    && ostree container commit

# Install fonts
RUN rpm-ostree install \
    google-noto-fonts-common \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    google-noto-emoji-fonts \
    google-noto-sans-mono-fonts \
    liberation-fonts \
    fontawesome-fonts \
    adobe-source-code-pro-fonts \
    fira-code-fonts \
    && ostree container commit

# Install additional applications
RUN rpm-ostree install \
    firefox \
    thunderbird \
    flatpak \
    && ostree container commit

# Install display manager (if you want one)
# For Hyprland, you might want to use SDDM or just use TTY login
RUN rpm-ostree install \
    sddm \
    && ostree container commit

# Enable essential services
RUN systemctl enable NetworkManager.service \
    && systemctl enable bluetooth.service \
    && systemctl enable sddm.service \
     && systemctl --global enable pipewire.socket \
    && systemctl --global enable wireplumber.service \
    && ostree container commit

# Set up default shell
RUN usermod -s /usr/bin/zsh root || true \
    && ostree container commit

# Copy configuration files from build context
COPY --from=ctx / /

# Final cleanup and commit
RUN dnf clean all \
    && ostree container commit

# Run bootc container lint as recommended
RUN bootc container lint
