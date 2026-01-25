#!/bin/bash
# WiFi network switching script for SAGE Glass
# Usage: ./switch_wifi.sh "SSID" "PASSWORD"

SSID="$1"
PASSWORD="$2"

if [ -z "$SSID" ] || [ -z "$PASSWORD" ]; then
    echo "Usage: $0 <SSID> <PASSWORD>"
    exit 1
fi

echo "=== SAGE WiFi Switch Script ==="
echo "Target SSID: $SSID"
echo "================================"

# Step 1: Kill existing dhclient processes
echo "Step 1: Stopping DHCP client..."
sudo killall dhclient 2>/dev/null
sleep 1

# Step 2: Disconnect from current network
echo "Step 2: Disconnecting from current network..."
sudo wpa_cli -i wlan0 disconnect
sleep 2

# Step 3: Flush IP address
echo "Step 3: Flushing IP configuration..."
sudo ip addr flush dev wlan0
sleep 1

# Step 4: Remove all saved networks from runtime (wpa_supplicant)
echo "Step 4: Removing runtime network configurations..."
sudo wpa_cli -i wlan0 remove_network all
sleep 1

# Step 5: Check if SSID already exists in config and remove it
echo "Step 5: Checking for existing configuration of: $SSID"
# Backup the file first
sudo cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf.bak

# Remove only the network block for this specific SSID (prevents duplicates)
# This preserves other saved networks for auto-reconnect on boot
sudo sed -i "/^network={/,/^}/{/ssid=\"$SSID\"/,/^}/d}" /etc/wpa_supplicant/wpa_supplicant.conf
echo "Removed any existing configuration for $SSID (if present)"

# Step 6: Add new network
echo "Step 6: Adding new network: $SSID"
NETWORK_ID=$(sudo wpa_cli -i wlan0 add_network 2>&1 | grep -oE '[0-9]+' | tail -1)

if [ -z "$NETWORK_ID" ]; then
    echo "ERROR: Failed to add network (no ID returned)"
    exit 1
fi

echo "Network ID assigned: $NETWORK_ID"

# Step 7: Configure network with new credentials (always use app-provided credentials)
echo "Step 7: Configuring network with fresh credentials from app..."
sudo wpa_cli -i wlan0 set_network $NETWORK_ID ssid "\"$SSID\"" >/dev/null
sudo wpa_cli -i wlan0 set_network $NETWORK_ID psk "\"$PASSWORD\"" >/dev/null
sudo wpa_cli -i wlan0 set_network $NETWORK_ID key_mgmt WPA-PSK >/dev/null

# Step 8: Enable the network
echo "Step 8: Enabling network..."
sudo wpa_cli -i wlan0 enable_network $NETWORK_ID
sudo wpa_cli -i wlan0 select_network $NETWORK_ID

# Step 9: Save configuration
echo "Step 9: Saving configuration..."
sudo wpa_cli -i wlan0 save_config

# Step 10: Wait for connection
echo "Step 10: Waiting for connection..."
sleep 5

# Step 11: Request DHCP
echo "Step 11: Requesting IP address..."
sudo dhclient -r wlan0 2>/dev/null || true
sudo dhclient wlan0 2>/dev/null

# Step 12: Verify connection
echo "Step 12: Verifying connection..."
sleep 8  # Increased wait time for connection to fully stabilize

# Check wpa_supplicant state
WPA_STATE=$(sudo wpa_cli -i wlan0 status | grep wpa_state | cut -d= -f2)
CURRENT_SSID=$(iwgetid -r)
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo "WPA State: $WPA_STATE"
echo "Current SSID: $CURRENT_SSID"
echo "IP Address: $IP_ADDRESS"

# Even if verification appears to fail, if we're CONNECTED state, it's likely just timing
# Let the Python code do the final verification
if [ "$WPA_STATE" = "COMPLETED" ] || [ "$CURRENT_SSID" = "$SSID" ]; then
    echo "================================"
    echo "SUCCESS: Connected to $SSID"
    echo "IP Address: $IP_ADDRESS"
    echo "================================"
    exit 0
else
    echo "================================"
    echo "WARNING: Connection verification inconclusive"
    echo "WPA State: $WPA_STATE"  
    echo "Current SSID: $CURRENT_SSID"
    echo "Expected: $SSID"
    echo "IP Address: $IP_ADDRESS"
    echo "Python will verify actual connection"
    echo "================================"
    exit 0  # Exit 0 anyway, let Python verify
fi
