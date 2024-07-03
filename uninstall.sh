#!/bin/bash

# Detect the distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Cannot detect the Linux distribution."
    exit 1
fi

# Define variables
CONFIG_DIR="/etc/openvpn"
HOME_DIR="$HOME/openvpn"
SERVICE_FILE="/etc/systemd/system/openvpn-client@.service"

# Function to uninstall packages and cleanup for Debian-based systems
uninstall_debian() {
    sudo systemctl stop openvpn-client@client
    sudo systemctl disable openvpn-client@client

    sudo apt purge -y openvpn resolvconf
    sudo apt autoremove -y

    # Remove configuration and scripts
    sudo rm -rf "${CONFIG_DIR}"
    rm -rf "${HOME_DIR}"
}

# Function to uninstall packages and cleanup for Arch Linux
uninstall_arch() {
    sudo systemctl stop openvpn-client@client
    sudo systemctl disable openvpn-client@client

    sudo pacman -Rs --noconfirm openvpn openresolv

    # Remove configuration and scripts
    sudo rm -rf "${CONFIG_DIR}"
    rm -rf "${HOME_DIR}"
}

# Uninstall based on the distribution
case $DISTRO in
    debian|ubuntu)
        uninstall_debian
        ;;
    arch)
        uninstall_arch
        ;;
    *)
        echo "Unsupported distribution: $DISTRO"
        exit 1
        ;;
esac

# Reload systemd daemon
sudo systemctl daemon-reload

echo "OpenVPN and associated files have been uninstalled."
