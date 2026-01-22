#!/bin/bash
# SAGE BLE Service Installation Script

set -e

echo "========================================="
echo "SAGE BLE Service Installation"
echo "========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo)"
    exit 1
fi

# Install dependencies
echo ""
echo "Installing dependencies..."
apt-get update
apt-get install -y \
    python3 \
    python3-pip \
    python3-dbus \
    python3-gi \
    bluetooth \
    bluez \
    network-manager

# Install Python packages
echo ""
echo "Installing Python packages..."
pip3 install --upgrade dbus-python pygobject

# Stop bluetooth service
echo ""
echo "Configuring Bluetooth..."
systemctl stop bluetooth

# Enable experimental features for BLE
if ! grep -q "ExperimentalFeatures = true" /etc/bluetooth/main.conf; then
    echo "ExperimentalFeatures = true" >> /etc/bluetooth/main.conf
fi

# Restart bluetooth
systemctl start bluetooth
systemctl enable bluetooth

# Make BLE script executable
chmod +x /home/sage/sage/ble_gatt_server.py

# Create systemd service
echo ""
echo "Creating systemd service..."
cat > /etc/systemd/system/sage-ble.service << EOF
[Unit]
Description=SAGE Glass BLE GATT Server
After=bluetooth.service
Requires=bluetooth.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /home/sage/sage/ble_gatt_server.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable and start service
echo ""
echo "Starting SAGE BLE service..."
systemctl enable sage-ble.service
systemctl start sage-ble.service

# Wait a moment
sleep 2

# Check status
echo ""
echo "========================================="
echo "Service Status:"
echo "========================================="
systemctl status sage-ble.service --no-pager

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""
echo "Service name: sage-ble.service"
echo ""
echo "Useful commands:"
echo "  sudo systemctl status sage-ble    # Check status"
echo "  sudo systemctl restart sage-ble   # Restart service"
echo "  sudo systemctl stop sage-ble      # Stop service"
echo "  sudo journalctl -u sage-ble -f    # View logs"
echo ""
echo "The Pi is now advertising as 'SAGE Glass X1'"
echo "Service UUID: 12345678-1234-5678-1234-56789abcdef0"
echo ""
