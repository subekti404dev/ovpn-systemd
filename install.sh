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
HOME_DIR="$HOME/openvpn"
CONFIG_DIR="/etc/openvpn"
SERVICE_FILE="/etc/systemd/system/openvpn-client@.service"
UPDATE_DNS_SCRIPT="${CONFIG_DIR}/update-dns.sh"
RESTORE_DNS_SCRIPT="${CONFIG_DIR}/restore-dns.sh"
CLIENT_CONFIG="${HOME_DIR}/client.conf"
OVPN_CONFIG="${HOME_DIR}/client.ovpn"

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
touch "${OVPN_CONFIG}"
echo "Place your OpenVPN configuration file at ${OVPN_CONFIG}"

# Create the client configuration file
cat > "${CLIENT_CONFIG}" <<EOF
# OpenVPN configuration
OVPN_CONFIG="${OVPN_CONFIG}"

# DNS settings
DNS_SERVERS="8.8.8.8 8.8.4.4"
EOF

# Create the update DNS script
sudo bash -c "cat > ${UPDATE_DNS_SCRIPT}" <<EOF
#!/bin/bash

# Source the configuration file
. ${CLIENT_CONFIG}

# Backup the original resolv.conf if it doesn't exist
if [ ! -f /etc/resolv.conf.backup ]; then
    cp /etc/resolv.conf /etc/resolv.conf.backup
fi

# Update resolv.conf with the new DNS servers
echo -e "nameserver \$DNS_SERVERS" > /etc/resolv.conf
EOF

# Make the update DNS script executable
sudo chmod +x "${UPDATE_DNS_SCRIPT}"

# Create the restore DNS script
sudo bash -c "cat > ${RESTORE_DNS_SCRIPT}" <<EOF
#!/bin/bash

# Source the configuration file
. ${CLIENT_CONFIG}

# Restore the original resolv.conf if the backup exists
if [ -f /etc/resolv.conf.backup ]; then
    mv /etc/resolv.conf.backup /etc/resolv.conf
fi
EOF

# Make the restore DNS script executable
sudo chmod +x "${RESTORE_DNS_SCRIPT}"

# Create the systemd service file
sudo bash -c "cat > ${SERVICE_FILE}" <<EOF
[Unit]
Description=OpenVPN connection to %i
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
EnvironmentFile=${CLIENT_CONFIG}
ExecStart=/usr/sbin/openvpn --config \$OVPN_CONFIG
ExecStartPost=${UPDATE_DNS_SCRIPT}
ExecStopPost=${RESTORE_DNS_SCRIPT}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon
sudo systemctl daemon-reload

# Enable and start the OpenVPN service (replace 'client' with your actual config name if different)
sudo systemctl enable openvpn-client@client
sudo systemctl start openvpn-client@client

# Display status
sudo systemctl status openvpn-client@client
