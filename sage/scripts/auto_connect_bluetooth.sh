#!/bin/bash
# Auto-reconnect Bluetooth headset and set as default audio output

JBL_MAC="28:6F:40:63:C5:D2"
MAX_RETRIES=5
RETRY_DELAY=3

echo "Checking Bluetooth headset connection..."

for i in $(seq 1 $MAX_RETRIES); do
    # Check if already connected
    if bluetoothctl info "$JBL_MAC" | grep -q "Connected: yes"; then
        echo "JBL headset already connected"
        break
    fi
    
    echo "Attempt $i/$MAX_RETRIES: Connecting to JBL..."
    bluetoothctl connect "$JBL_MAC"
    sleep $RETRY_DELAY
done

# Wait for PulseAudio to detect the device
sleep 2

# Set A2DP profile for high-quality audio
CARD_NAME="bluez_card.${JBL_MAC//:/_}"
if pactl list cards short | grep -q "$CARD_NAME"; then
    echo "Setting A2DP profile..."
    pactl set-card-profile "$CARD_NAME" a2dp-sink
    sleep 1
    
    # Set as default sink
    SINK_NAME="bluez_output.${JBL_MAC//:/_}.1"
    if pactl list sinks short | grep -q "$SINK_NAME"; then
        echo "Setting JBL as default audio output..."
        pactl set-default-sink "$SINK_NAME"
        echo "✓ JBL headset configured as default output"
    else
        echo "✗ JBL sink not found"
    fi
else
    echo "✗ JBL Bluetooth card not found"
fi
