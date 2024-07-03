#!/bin/bash

# Detect the shell type
if [ -n "$BASH_VERSION" ]; then
    SHELL_RC=".bashrc"
elif [ -n "$ZSH_VERSION" ]; then
    SHELL_RC=".zshrc"
else
    echo "Unsupported shell. Please use Bash or Zsh."
    exit 1
fi

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

    # Remove aliases from shell rc file
    remove_aliases_from_rc
}

# Function to uninstall packages and cleanup for Arch Linux
uninstall_arch() {
    sudo systemctl stop openvpn-client@client
    sudo systemctl disable openvpn-client@client

    sudo pacman -Rs --noconfirm openvpn openresolv

    # Remove configuration and scripts
    sudo rm -rf "${CONFIG_DIR}"
    rm -rf "${HOME_DIR}"

    # Remove aliases from shell rc file
    remove_aliases_from_rc
}

# Function to remove aliases from shell rc file
remove_aliases_from_rc() {
    local alias_file="$HOME/$SHELL_RC"
    sed -i '/alias startvpn/d' "$alias_file"
    sed -i '/alias stopvpn/d' "$alias_file"
    sed -i '/alias statusvpn/d' "$alias_file"
    echo "Aliases 'startvpn', 'statusvpn' and 'stopvpn' removed from $SHELL_RC."
    echo "Run 'source $SHELL_RC' to apply the changes."
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
