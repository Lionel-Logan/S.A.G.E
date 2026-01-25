#!/bin/bash
# Install SAGE Pi Server as a systemd service

set -e

echo "=================================="
echo "SAGE Pi Server - Service Installer"
echo "=================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Error: Please run as root (use sudo)"
    exit 1
fi

# Configuration
SERVICE_NAME="sage-pi-server"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAGE_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "📁 SAGE Directory: $SAGE_DIR"
echo "📋 Service Name: $SERVICE_NAME"
echo ""

# Create log directory
echo "📂 Creating log directory..."
mkdir -p /var/log/sage
chown sage:sage /var/log/sage
chmod 755 /var/log/sage

# Copy service file
echo "📋 Installing systemd service..."
cp "${SCRIPT_DIR}/pi_server.service" "$SERVICE_FILE"

# Reload systemd
echo "🔄 Reloading systemd daemon..."
systemctl daemon-reload

# Enable service
echo "✅ Enabling service to start on boot..."
systemctl enable "$SERVICE_NAME"

# Start service
echo "🚀 Starting service..."
systemctl start "$SERVICE_NAME"

# Check status
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo ""
    echo "✅ SUCCESS! SAGE Pi Server is running"
    echo ""
    echo "Useful commands:"
    echo "  sudo systemctl status $SERVICE_NAME   # Check status"
    echo "  sudo systemctl stop $SERVICE_NAME     # Stop service"
    echo "  sudo systemctl restart $SERVICE_NAME  # Restart service"
    echo "  sudo journalctl -u $SERVICE_NAME -f   # View logs"
    echo ""
    echo "Test the server:"
    echo "  curl http://localhost:8001/ping"
    echo ""
else
    echo ""
    echo "❌ ERROR: Service failed to start"
    echo "Check logs with: sudo journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi
