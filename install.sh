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

# Function to install packages and setup for Debian-based systems
install_debian() {
    sudo apt update
    sudo apt install -y openvpn resolvconf
}

# Function to install packages and setup for Arch Linux
install_arch() {
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm openvpn openresolv
}

# Function to add alias to shell rc file
add_alias_to_rc() {
    local alias_file="$HOME/$SHELL_RC"
    echo "alias startvpn='sudo systemctl start openvpn-client@client'" >> "$alias_file"
    echo "alias stopvpn='sudo systemctl stop openvpn-client@client'" >> "$alias_file"
    echo "alias statusvpn='sudo systemctl is-active openvpn-client@client'" >> "$alias_file"
    echo "Aliases 'startvpn', 'statusvpn' and 'stopvpn' added to $SHELL_RC."
    echo "Run 'source $SHELL_RC' to apply the changes."
}

# Install necessary packages based on the distribution
case $DISTRO in
    debian|ubuntu)
        install_debian
        ;;
    arch)
        install_arch
        ;;
    *)
        echo "Unsupported distribution: $DISTRO"
        exit 1
        ;;
esac

# Create the home directory for openvpn files
mkdir -p "${HOME_DIR}"

# Create the openvpn config directory if it doesn't exist
sudo mkdir -p "${CONFIG_DIR}"

# Create OpenVPN configuration file placeholder (replace with actual .ovpn content)
touch "${HOME_DIR}/client.ovpn"
echo "Place your OpenVPN configuration file at ${HOME_DIR}/client.ovpn"

# Create the client configuration file
cat > "${HOME_DIR}/client.conf" <<EOF
# OpenVPN configuration
OVPN_CONFIG="${HOME_DIR}/client.ovpn"

# DNS settings
DNS_SERVERS="8.8.8.8 8.8.4.4"
EOF

# Create the update DNS script
sudo bash -c "cat > ${CONFIG_DIR}/update-dns.sh" <<EOF
#!/bin/bash

# Source the configuration file
. ${HOME_DIR}/client.conf

# Backup the original resolv.conf if it doesn't exist
if [ ! -f /etc/resolv.conf.backup ]; then
    cp /etc/resolv.conf /etc/resolv.conf.backup
fi

# Update resolv.conf with the new DNS servers
echo -e "nameserver \$DNS_SERVERS" > /etc/resolv.conf
EOF

# Make the update DNS script executable
sudo chmod +x "${CONFIG_DIR}/update-dns.sh"

# Create the restore DNS script
sudo bash -c "cat > ${CONFIG_DIR}/restore-dns.sh" <<EOF
#!/bin/bash

# Source the configuration file
. ${HOME_DIR}/client.conf

# Restore the original resolv.conf if the backup exists
if [ -f /etc/resolv.conf.backup ]; then
    mv /etc/resolv.conf.backup /etc/resolv.conf
fi
EOF

# Make the restore DNS script executable
sudo chmod +x "${CONFIG_DIR}/restore-dns.sh"

# Create the systemd service file
sudo bash -c "cat > ${SERVICE_FILE}" <<EOF
[Unit]
Description=OpenVPN connection to %i
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
EnvironmentFile=${HOME_DIR}/client.conf
ExecStart=/usr/sbin/openvpn --config \$OVPN_CONFIG
ExecStartPost=${CONFIG_DIR}/update-dns.sh
ExecStopPost=${CONFIG_DIR}/restore-dns.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon
sudo systemctl daemon-reload

# Enable and start the OpenVPN service (replace 'client' with your actual config name if different)
# sudo systemctl enable openvpn-client@client
# sudo systemctl start openvpn-client@client

# Add aliases to shell rc file if it exists
if [ -f "$HOME/$SHELL_RC" ]; then
    add_alias_to_rc
fi

# Display status
# sudo systemctl status openvpn-client@client
