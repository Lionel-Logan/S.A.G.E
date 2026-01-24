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
    
    # CRITICAL: Force disconnect any ghost connections first
    echo "Clearing any existing connections..." >&2
    bluetoothctl disconnect "$mac" >/dev/null 2>&1
    sleep 2
    
    # Remove device if already paired (fresh start)
    bluetoothctl remove "$mac" >/dev/null 2>&1
    sleep 1
    
    # Pairing using bluetoothctl with scan on (device must be discovered while pairing)
    echo "Attempting to pair..." >&2
    
    # Key insight: scan must remain ON during pairing
    # Use here-document to send commands with delays
    {
        echo "scan on"
        sleep 15
        echo "pair $mac"
        sleep 10
        echo "trust $mac"
        sleep 2
        echo "connect $mac"
        sleep 3
        echo "scan off"
        sleep 1
        echo "exit"
    } | sudo bluetoothctl 2>&1 | tee /tmp/bt_pair_$$.log >&2
    
    # Check if pairing was successful by examining the log
    if grep -q "Pairing successful\|Bonded: yes" /tmp/bt_pair_$$.log; then
        echo "Pairing successful" >&2
        
        # CRITICAL: Verify device is both paired AND connected
        device_info=$(sudo bluetoothctl info "$mac" 2>&1)
        
        is_paired=$(echo "$device_info" | grep -q "Paired: yes" && echo "yes" || echo "no")
        is_connected=$(echo "$device_info" | grep -q "Connected: yes" && echo "yes" || echo "no")
        
        if [ "$is_paired" = "yes" ]; then
            echo "Device trusted and paired" >&2
            
            # If not connected, force connect now
            if [ "$is_connected" = "no" ]; then
                echo "Device paired but not connected, connecting now..." >&2
                sleep 2
                bluetoothctl connect "$mac" >&2
                sleep 3
                
                # Verify connection
                if sudo bluetoothctl info "$mac" 2>&1 | grep -q "Connected: yes"; then
                    echo "Device connected successfully" >&2
                    setup_audio_output "$mac"
                    rm -f /tmp/bt_pair_$$.log
                    exit 0
                else
                    echo "Warning: Device paired but connection failed" >&2
                fi
            else
                echo "Device connected successfully" >&2
                setup_audio_output "$mac"
                rm -f /tmp/bt_pair_$$.log
                exit 0
            fi
        fi
    fi
    
    echo "Pairing failed. Please ensure:" >&2
    echo "  1. Device is in pairing mode (LED flashing)" >&2
    echo "  2. Device is close to the Pi" >&2
    echo "  3. Device is not connected to another device" >&2
    rm -f /tmp/bt_pair_$$.log
    exit 1
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

# Function to disconnect from device and forget it
disconnect_device() {
    local mac="$1"
    
    if [ -z "$mac" ]; then
        echo "Error: MAC address required" >&2
        exit 1
    fi
    
    echo "Disconnecting and removing device: $mac" >&2
    
    # Step 1: Force disconnect (critical - must happen first)
    echo "Step 1: Disconnecting..." >&2
    bluetoothctl disconnect "$mac" 2>&1 >&2
    sleep 3  # Wait for disconnect to complete
    
    # Step 2: Untrust the device
    echo "Step 2: Untrusting..." >&2
    bluetoothctl untrust "$mac" 2>&1 >&2
    sleep 1
    
    # Step 3: Remove (unpair/forget) the device
    echo "Step 3: Removing..." >&2
    if bluetoothctl remove "$mac" 2>&1 | grep -q "Device has been removed\|not available"; then
        echo "Device disconnected and forgotten successfully" >&2
        
        # Reset to default audio output
        reset_audio_output
        
        # Verify device is actually gone
        if bluetoothctl info "$mac" 2>&1 | grep -q "Device $mac not available"; then
            echo "Verified: Device fully removed" >&2
            exit 0
        else
            echo "Warning: Device may still be in system" >&2
            exit 0
        fi
    else
        echo "Failed to remove device" >&2
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
    # AVOID calling bluetoothctl info on connected devices as it can disrupt A2DP connections
    connected_device=""
    device_name=""

    # Use pactl to check for active Bluetooth audio sinks (less intrusive)
    if command -v pactl >/dev/null 2>&1; then
        # Check if PulseAudio has active Bluetooth sinks
        bt_sink=$(pactl list short sinks | grep -i "bluez" | head -1)
        if [ -n "$bt_sink" ]; then
            # Extract MAC address from sink name (format: bluez_sink.MAC_ADDRESS.a2dp_sink)
            sink_name=$(echo "$bt_sink" | awk '{print $2}')
            if [[ "$sink_name" =~ bluez_sink\.([0-9A-F:]+)\. ]]; then
                connected_device="${BASH_REMATCH[1]}"
                # Get device name from bluetoothctl devices (safe, doesn't disrupt connection)
                device_name=$(bluetoothctl devices | grep "$connected_device" | sed 's/.*Device.* //')
                if [ -z "$device_name" ]; then
                    device_name="Bluetooth Audio Device"
                fi
            fi
        fi
    fi

    # Fallback: If no PulseAudio info, use minimal bluetoothctl check
    if [ -z "$connected_device" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ Device\ ([0-9A-F:]+)\ (.+) ]]; then
                mac="${BASH_REMATCH[1]}"
                name="${BASH_REMATCH[2]}"

                # Use a very quick check - just see if device exists in connected state
                # Avoid full bluetoothctl info which disrupts connections
                if bluetoothctl devices Connected 2>/dev/null | grep -q "$mac"; then
                    # Quick class check without full info
                    device_class=$(bluetoothctl info "$mac" 2>/dev/null | grep "Class:" | awk '{print $2}' | head -1)
                    if [ -n "$device_class" ] && is_audio_device "$device_class" ""; then
                        connected_device="$mac"
                        device_name="$name"
                        break
                    fi
                fi
            fi
        done < <(bluetoothctl devices 2>/dev/null)
    fi
    
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
