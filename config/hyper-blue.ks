# Kickstart file for hypr-blue installation
# Use graphical install
graphical

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# System language
lang en_US.UTF-8

# OSTree setup - CRITICAL for fixing the deployment error
ostreesetup --nogpg --osname=hypr-blue --remote=hypr-blue --url=https://ghcr.io/dwpeters88/hypr-blue --ref=ostree/1/1/0

# Network information
network --bootproto=dhcp --device=link --activate

# Root password
rootpw --lock

# SELinux configuration - Set to permissive during install
selinux --permissive

# System timezone
timezone America/New_York --utc

# Bootloader configuration with proper kernel args
bootloader --append="rhgb quiet enforcing=0 ibt=off"

# Partition clearing and automatic partitioning
clearpart --all --initlabel
autopart --type=btrfs --encrypted

# Reboot after installation
reboot

%pre
# Pre-installation script
echo "Starting hypr-blue installation..."
# Ensure proper directories exist
mkdir -p /mnt/sysimage/ostree/repo
%end

%post --nochroot
# Post-installation script (runs in installer environment)
# Fix SELinux contexts
chroot /mnt/sysimage restorecon -Rv /usr || true
chroot /mnt/sysimage restorecon -Rv /etc || true

# Ensure OSTree remote is properly configured
cat > /mnt/sysimage/etc/ostree/remotes.d/hypr-blue.conf << EOF
[remote "hypr-blue"]
url=https://ghcr.io/dwpeters88/hypr-blue
gpg-verify=false
EOF
%end

%post
# Post-installation script (runs in installed system)
# Enable required services
systemctl enable sddm.service || systemctl enable gdm.service || true
systemctl enable NetworkManager.service

# Create user (modify as needed)
useradd -m -G wheel -s /bin/bash liveuser
echo "liveuser:password" | chpasswd

# Set Hyprland as default session
mkdir -p /var/lib/AccountsService/users
cat > /var/lib/AccountsService/users/liveuser << EOF
[User]
Session=hyprland
XSession=hyprland
Icon=/home/liveuser/.face
SystemAccount=false
EOF

# Final SELinux relabel
touch /.autorelabel
%end