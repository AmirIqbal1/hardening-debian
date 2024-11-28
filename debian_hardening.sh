#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

echo "Starting Debian 12 hardening process..."

# Update and upgrade system packages
echo "Updating and upgrading system..."
apt update && apt upgrade -y

# Install necessary security tools
echo "Installing essential security tools..."
apt install -y ufw fail2ban clamav unattended-upgrades auditd

# Enable automatic updates
echo "Configuring unattended upgrades..."
dpkg-reconfigure -plow unattended-upgrades

# Configure UFW (Uncomplicated Firewall)
echo "Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# Harden SSH configuration
echo "Hardening SSH..."
sed -i.bak -e 's/^#\(PermitRootLogin\) .*/\1 no/' \
           -e 's/^#\(PasswordAuthentication\) .*/\1 no/' \
           -e 's/^#\(X11Forwarding\) .*/\1 no/' \
           -e 's/^#\(MaxAuthTries\) .*/\1 3/' \
           /etc/ssh/sshd_config
systemctl restart sshd

# Set password policies
echo "Setting password policies..."
cat <<EOT > /etc/security/pwquality.conf
minlen = 12
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
EOT
echo "auth required pam_tally2.so deny=5 unlock_time=900" >> /etc/pam.d/common-auth

# Enable auditing
echo "Enabling auditd..."
systemctl enable auditd
systemctl start auditd

# Configure Fail2Ban
echo "Configuring Fail2Ban..."
cat <<EOT > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
EOT
systemctl restart fail2ban

# Disable unnecessary services
echo "Disabling unnecessary services..."
systemctl disable avahi-daemon
systemctl disable cups
systemctl disable bluetooth

# Scan for malware
echo "Scanning for malware with ClamAV..."
freshclam
clamscan -r / --bell -i

# Restrict kernel parameters
echo "Restricting kernel parameters..."
cat <<EOT > /etc/sysctl.d/99-hardening.conf
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 0
kernel.randomize_va_space = 2
EOT
sysctl -p /etc/sysctl.d/99-hardening.conf

# Protect home directories
echo "Protecting home directories..."
chmod 750 /home/*

# Set up AppArmor
echo "Enabling AppArmor..."
apt install -y apparmor apparmor-profiles apparmor-utils
systemctl enable apparmor
systemctl start apparmor

echo "Debian 12 hardening complete."
