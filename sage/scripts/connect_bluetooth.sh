#!/bin/bash
# Bluetooth Audio Device Management Script for SAGE Glass
# Usage: ./connect_bluetooth.sh <action> [MAC_ADDRESS]
# Actions: scan, pair, connect, disconnect, status

ACTION="$1"
MAC_ADDRESS="$2"

# Audio device class patterns (Major class 0x04 = Audio/Video)
AUDIO_DEVICE_CLASSES=(
    "0x240404"  # Headphones
    "0x240408"  # Hands-free device
    "0x24041C"  # Loudspeaker
    "0x240418"  # Headset
    "0x240420"  # Portable Audio
)

# Function to check if device is audio device
is_audio_device() {
    local device_class="$1"
    local services="$2"
    
    # Check device class
    for audio_class in "${AUDIO_DEVICE_CLASSES[@]}"; do
        if [[ "$device_class" == "$audio_class" ]]; then
            return 0
        fi
    done
    
    # Check if device class starts with 0x2404 (Audio/Video - Audio)
    if [[ "$device_class" =~ ^0x2404 ]]; then
        return 0
    fi
    
    # Check for A2DP or HFP in services
    if [[ "$services" == *"A2DP"* ]] || [[ "$services" == *"AudioSink"* ]] || [[ "$services" == *"Handsfree"* ]]; then
        return 0
    fi
    
    return 1
}

# Function to scan for Bluetooth devices
scan_devices() {
    echo "Scanning for ALL Bluetooth devices (no filtering)..." >&2
    
    # Enable Bluetooth adapter
    sudo bluetoothctl power on >/dev/null 2>&1
    sleep 1
    
    # Start scanning
    timeout 10 bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &
    SCAN_PID=$!
    sleep 10
    
    # Get list of devices
    devices_json="["
    first=true
    declare -A seen_macs  # Track seen MAC addresses to avoid duplicates
    
    while IFS= read -r line; do
        if [[ "$line" =~ Device\ ([0-9A-F:]+)\ (.+) ]]; then
            mac="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
            
            # Skip if we've already seen this MAC address
            if [[ -n "${seen_macs[$mac]}" ]]; then
                continue
            fi
            seen_macs[$mac]=1
            
            # Get device info
            device_info=$(bluetoothctl info "$mac" 2>/dev/null)
            
            # Try to get the actual name from device info
            actual_name=$(echo "$device_info" | grep "Name:" | sed 's/.*Name: //' | head -1)
            
            # Use actual name if found, otherwise use name from devices list
            if [ -n "$actual_name" ]; then
                name="$actual_name"
            fi
            
            # Skip devices with "RSSI is nil" as the name
            if [[ "$name" == "RSSI is nil" ]]; then
                continue
            fi
            
            # Extract device class
            device_class=$(echo "$device_info" | grep "Class:" | awk '{print $2}')
            if [ -z "$device_class" ]; then
                device_class="0x000000"
            fi
            
            # Check if paired
            paired=$(echo "$device_info" | grep "Paired: yes" >/dev/null && echo "true" || echo "false")
            
            # Check if connected
            connected=$(echo "$device_info" | grep "Connected: yes" >/dev/null && echo "true" || echo "false")
            
            # Get services/UUIDs
            services=$(echo "$device_info" | grep "UUID:")
            
            # Determine device type
            device_type="unknown"
            if is_audio_device "$device_class" "$services"; then
                device_type="audio"
            fi
            
            # Add to JSON array
            if [ "$first" = true ]; then
                first=false
            else
                devices_json+=","
            fi
            
            # Clean name (escape quotes)
            clean_name=$(echo "$name" | sed 's/"/\\"/g')
            
            # Minimal JSON: Name, Type, Paired, Connected (MAC kept for pairing functionality)
            devices_json+="{\"m\":\"$mac\",\"n\":\"$clean_name\",\"t\":\"$device_type\",\"p\":$paired,\"x\":$connected}"
        fi
    done < <(bluetoothctl devices 2>/dev/null | sort -u)
    
    devices_json+="]"
    
    # Stop scanning
    bluetoothctl scan off >/dev/null 2>&1
    
    # Output JSON
    echo "$devices_json"
}

# Function to pair with device
pair_device() {
    local mac="$1"
    
    if [ -z "$mac" ]; then
        echo "Error: MAC address required" >&2
        exit 1
    fi
    
    echo "Pairing with device: $mac" >&2
    
    # Power on Bluetooth
    sudo bluetoothctl power on >/dev/null 2>&1
    sleep 1
    
    # Remove device if already paired (fresh start)
    bluetoothctl remove "$mac" >/dev/null 2>&1
    sleep 1
    
    # Scan briefly to discover device
    timeout 5 bluetoothctl --timeout 5 scan on >/dev/null 2>&1 &
    sleep 5
    bluetoothctl scan off >/dev/null 2>&1
    
    # Pair with device
    echo "Attempting to pair..." >&2
    if bluetoothctl pair "$mac" 2>&1 | grep -q "Pairing successful\|already paired"; then
        echo "Pairing successful" >&2
        
        # Trust device for auto-reconnect
        bluetoothctl trust "$mac" >/dev/null 2>&1
        echo "Device trusted" >&2
        
        # Try to connect
        echo "Attempting to connect..." >&2
        if bluetoothctl connect "$mac" 2>&1 | grep -q "Connection successful\|already connected"; then
            echo "Connection successful" >&2
            
            # Set as default audio output
            setup_audio_output "$mac"
            
            exit 0
        else
            echo "Connected but audio setup may need manual configuration" >&2
            exit 0
        fi
    else
        echo "Pairing failed. Ensure device is in pairing mode." >&2
        exit 1
    fi
}

# Function to connect to already paired device
connect_device() {
    local mac="$1"
    
    if [ -z "$mac" ]; then
        echo "Error: MAC address required" >&2
        exit 1
    fi
    
    echo "Connecting to device: $mac" >&2
    
    # Power on Bluetooth
    sudo bluetoothctl power on >/dev/null 2>&1
    sleep 1
    
    # Connect
    if bluetoothctl connect "$mac" 2>&1 | grep -q "Connection successful\|already connected"; then
        echo "Connection successful" >&2
        
        # Set as default audio output
        setup_audio_output "$mac"
        
        exit 0
    else
        echo "Connection failed" >&2
        exit 1
    fi
}

# Function to disconnect from device
disconnect_device() {
    local mac="$1"
    
    if [ -z "$mac" ]; then
        echo "Error: MAC address required" >&2
        exit 1
    fi
    
    echo "Disconnecting from device: $mac" >&2
    
    if bluetoothctl disconnect "$mac" 2>&1 | grep -q "Successful"; then
        echo "Disconnected successfully" >&2
        
        # Reset to default audio output
        reset_audio_output
        
        exit 0
    else
        echo "Disconnection failed" >&2
        exit 1
    fi
}

# Function to setup audio output via PulseAudio
setup_audio_output() {
    local mac="$1"
    
    echo "Setting up audio output for $mac..." >&2
    
    # Check if PulseAudio is running
    if ! pgrep -x "pulseaudio" > /dev/null; then
        echo "Starting PulseAudio..." >&2
        pulseaudio --start 2>&1 >&2
        sleep 2
    fi
    
    # Wait for Bluetooth audio sink to appear
    sleep 3
    
    # Get PulseAudio sink for Bluetooth device
    # Convert MAC to PulseAudio format (replace : with _)
    pa_mac=$(echo "$mac" | tr ':' '_')
    
    # Find the Bluetooth sink
    bt_sink=$(pactl list short sinks | grep -i "bluez.*$pa_mac" | awk '{print $2}' | head -1)
    
    if [ -z "$bt_sink" ]; then
        # Try alternative format
        bt_sink=$(pactl list short sinks | grep -i "bluez" | grep -i "headset\|a2dp" | awk '{print $2}' | head -1)
    fi
    
    if [ -n "$bt_sink" ]; then
        echo "Found Bluetooth sink: $bt_sink" >&2
        pactl set-default-sink "$bt_sink" 2>&1 >&2
        echo "Audio output configured successfully" >&2
    else
        echo "Warning: Could not find Bluetooth audio sink. Audio routing may need manual configuration." >&2
    fi
}

# Function to reset audio output to default
reset_audio_output() {
    echo "Resetting audio output to default..." >&2
    
    # Get first non-Bluetooth sink
    default_sink=$(pactl list short sinks | grep -v "bluez" | awk '{print $2}' | head -1)
    
    if [ -n "$default_sink" ]; then
        pactl set-default-sink "$default_sink" 2>&1 >&2
        echo "Audio output reset to: $default_sink" >&2
    fi
}

# Function to get current status
get_status() {
    # Check for connected Bluetooth audio devices
    connected_device=""
    device_name=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ Device\ ([0-9A-F:]+)\ (.+) ]]; then
            mac="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
            
            # Check if connected
            if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
                # Check if it's an audio device
                device_info=$(bluetoothctl info "$mac" 2>/dev/null)
                device_class=$(echo "$device_info" | grep "Class:" | awk '{print $2}')
                services=$(echo "$device_info" | grep "UUID:")
                
                if is_audio_device "$device_class" "$services"; then
                    connected_device="$mac"
                    device_name="$name"
                    break
                fi
            fi
        fi
    done < <(bluetoothctl devices 2>/dev/null)
    
    if [ -n "$connected_device" ]; then
        echo "{\"status\":\"connected\",\"device\":\"$connected_device\",\"name\":\"$device_name\",\"connected\":true}"
    else
        echo "{\"status\":\"idle\",\"device\":null,\"name\":null,\"connected\":false}"
    fi
}

# Main action handler
case "$ACTION" in
    scan)
        scan_devices
        ;;
    pair)
        pair_device "$MAC_ADDRESS"
        ;;
    connect)
        connect_device "$MAC_ADDRESS"
        ;;
    disconnect)
        disconnect_device "$MAC_ADDRESS"
        ;;
    status)
        get_status
        ;;
    *)
        echo "Usage: $0 <scan|pair|connect|disconnect|status> [MAC_ADDRESS]" >&2
        exit 1
        ;;
esac
