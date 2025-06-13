#!/bin/bash

# Create necessary directories
mkdir -p /usr/etc/skel/.config/hypr/scripts
mkdir -p /usr/etc/skel/.config/autostart-scripts
mkdir -p /usr/share/backgrounds/sddm
mkdir -p /usr/share/sddm/themes
mkdir -p /usr/share/wayland-sessions
mkdir -p /usr/etc/environment.d
mkdir -p /usr/etc/sddm.conf.d

# Set up system configuration
echo "Setting up system configuration..."

# Create necessary system directories
mkdir -p /var/roothome
mkdir -p /var/opt
mkdir -p /var/lib/alternatives

# Set permissions
chmod -R 755 /usr/etc/skel/.config

# Enable required services
systemctl enable sddm.service
systemctl enable polkit.service
systemctl enable NetworkManager.service
systemctl enable bluetooth.service || true

# Clean up
rm -rf /tmp/*

echo "Build script completed successfully" 