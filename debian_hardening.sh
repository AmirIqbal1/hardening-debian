#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

echo "Starting Debian 12 hardening process..."

# Lets log this badboy 
LOGFILE="/var/log/debian_hardening.log"
exec > >(tee -a $LOGFILE) 2>&1

# Update and upgrade system packages
echo "Updating and upgrading system..."
apt update && apt upgrade -y || { echo "Failed to update/upgrade packages"; exit 1; }

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

# Function to safely update SSH config
update_ssh_config() {
    local option="$1"
    local value="$2"
    local config_file="/etc/ssh/sshd_config"

    # Backup configuration file
    if [ ! -f "$config_file.bak" ]; then
        cp "$config_file" "$config_file.bak"
        echo "Backup of sshd_config created at $config_file.bak"
    fi

    # Update the config
    if grep -q "^#\?\s*$option" "$config_file"; then
        sed -i -e "s/^#\?\s*\($option\).*/\1 $value/" "$config_file"
        echo "$option set to $value in $config_file"
    else
        echo "$option $value" >> "$config_file"
        echo "$option added with value $value"
    fi
}

# Apply SSH hardening configurations
update_ssh_config "PermitRootLogin" "no"
update_ssh_config "PasswordAuthentication" "no"
update_ssh_config "X11Forwarding" "no"
update_ssh_config "MaxAuthTries" "3"

# Restart SSH service to apply changes
systemctl restart sshd

# Backing up password policies
echo "Backing up password policies"
if [ -f /etc/security/pwquality.conf ]; then
    cp /etc/security/pwquality.conf /etc/security/pwquality.conf.bak
    echo "Backup created at /etc/security/pwquality.conf.bak"
fi

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
echo "Installing and configuring Fail2Ban..."

cat <<EOT > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOT

systemctl enable fail2ban --now

# Stop services before disabling
systemctl stop avahi-daemon && systemctl disable avahi-daemon
systemctl stop cups && systemctl disable cups

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
sysctl -p /etc/sysctl.d/99-hardening.conf || { echo "Sysctl configuration failed"; exit 1; }

# Protect home directories
echo "Protecting home directories..."
chmod 750 /home/*

# Set up AppArmor
echo "Enabling AppArmor..."
apt install -y apparmor apparmor-profiles apparmor-utils
systemctl enable apparmor
systemctl start apparmor

echo "Hardening complete. Logs available at $LOGFILE."
