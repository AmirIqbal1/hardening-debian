# Debian Hardening Script

This script is designed to harden Debian-based (tested on 12) systems by applying various security best practices.

### Key Features of This Script:

* Updates the system and ensures it's running the latest packages.
* Configures ufw to manage firewall rules.
* Hardens SSH by disabling root login and password authentication.
* Enforces strong password policies and limits authentication attempts.
* Installs and configures security tools like fail2ban and clamav.
* Disables unused services to reduce attack surface.
* Configures kernel parameters for additional security.
* Sets up automatic updates for critical patches.

## Caution
This script makes significant changes to your system's configuration. Make sure to review the script and test it in a non-production environment before using it on production systems.

## How to Use the Script

1. Clone the script ```git clone https://github.com/AmirIqbal1/hardening-debian```.
2. Make it executable: ```chmod +x debian_hardening.sh ```
3. Run the script with root privileges: ```sudo ./debian_hardening.sh ```
