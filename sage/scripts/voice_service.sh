#!/bin/bash
# SAGE Voice Assistant - Service Management Helper
# Quick commands for managing the voice assistant service

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="voice_assistant"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

cmd_status() {
    print_header "Service Status"
    sudo systemctl status $SERVICE_NAME.service --no-pager
}

cmd_start() {
    print_header "Starting Service"
    sudo systemctl start $SERVICE_NAME.service
    if [ $? -eq 0 ]; then
        print_success "Service started"
        sleep 2
        cmd_status
    else
        print_error "Failed to start service"
    fi
}

cmd_stop() {
    print_header "Stopping Service"
    sudo systemctl stop $SERVICE_NAME.service
    if [ $? -eq 0 ]; then
        print_success "Service stopped"
    else
        print_error "Failed to stop service"
    fi
}

cmd_restart() {
    print_header "Restarting Service"
    sudo systemctl restart $SERVICE_NAME.service
    if [ $? -eq 0 ]; then
        print_success "Service restarted"
        sleep 2
        cmd_status
    else
        print_error "Failed to restart service"
    fi
}

cmd_logs() {
    print_header "Service Logs (Ctrl+C to exit)"
    echo ""
    sudo journalctl -u $SERVICE_NAME -f
}

cmd_logs_recent() {
    print_header "Recent Logs (Last 50 lines)"
    echo ""
    sudo journalctl -u $SERVICE_NAME -n 50 --no-pager
}

cmd_enable() {
    print_header "Enabling Service (Auto-start on boot)"
    sudo systemctl enable $SERVICE_NAME.service
    if [ $? -eq 0 ]; then
        print_success "Service enabled"
    else
        print_error "Failed to enable service"
    fi
}

cmd_disable() {
    print_header "Disabling Service (No auto-start)"
    sudo systemctl disable $SERVICE_NAME.service
    if [ $? -eq 0 ]; then
        print_success "Service disabled"
    else
        print_error "Failed to disable service"
    fi
}

cmd_test() {
    print_header "Testing Voice Assistant Components"
    echo ""
    cd "$SCRIPT_DIR/.."
    python3 scripts/test_voice_components.py
}

cmd_monitor() {
    print_header "Monitoring Voice Assistant"
    echo ""
    print_info "Status file: /tmp/sage_voice_status.json"
    print_info "Press Ctrl+C to exit"
    echo ""
    
    while true; do
        clear
        echo -e "${BLUE}=== SAGE Voice Assistant Monitor ===${NC}"
        echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo ""
        
        if [ -f /tmp/sage_voice_status.json ]; then
            cat /tmp/sage_voice_status.json | python3 -m json.tool
        else
            print_warning "Status file not found (service not running?)"
        fi
        
        sleep 1
    done
}

cmd_config() {
    print_header "Voice Assistant Configuration"
    echo ""
    CONFIG_FILE="$SCRIPT_DIR/../config/voice_config.py"
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "Configuration file: $CONFIG_FILE"
        echo ""
        
        # Extract key settings
        print_info "Wake Word Settings:"
        grep -E "WAKE_WORD|PORCUPINE" "$CONFIG_FILE" | head -3
        echo ""
        
        print_info "Audio Settings:"
        grep -E "SAMPLE_RATE|SILENCE" "$CONFIG_FILE" | head -4
        echo ""
        
        print_info "Backend Settings:"
        grep -E "BACKEND_API" "$CONFIG_FILE" | head -3
        echo ""
        
        print_info "To edit: nano $CONFIG_FILE"
    else
        print_error "Configuration file not found"
    fi
}

cmd_audio_test() {
    print_header "Audio Device Test"
    echo ""
    
    print_info "Available input devices:"
    arecord -l
    echo ""
    
    print_info "PulseAudio info:"
    pactl info | grep -E "Server Name|Default Source"
    echo ""
    
    read -p "Record 5 seconds of test audio? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Recording... (speak now)"
        arecord -d 5 -f cd test_audio.wav
        
        print_info "Playing back..."
        aplay test_audio.wav
        
        print_success "Audio test complete"
        print_info "File saved: test_audio.wav"
    fi
}

cmd_help() {
    cat << EOF
SAGE Voice Assistant - Service Manager

Usage: $0 <command>

Commands:
  start          Start the voice assistant service
  stop           Stop the voice assistant service
  restart        Restart the voice assistant service
  status         Show service status
  
  logs           View live logs (tail -f)
  logs-recent    View recent logs (last 50 lines)
  
  enable         Enable auto-start on boot
  disable        Disable auto-start
  
  test           Run component tests
  monitor        Monitor status in real-time
  config         Show current configuration
  audio-test     Test microphone and speakers
  
  help           Show this help message

Examples:
  $0 start       # Start the service
  $0 logs        # Watch logs in real-time
  $0 test        # Test all components

EOF
}

# Main script logic
case "${1:-help}" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    logs-recent)
        cmd_logs_recent
        ;;
    enable)
        cmd_enable
        ;;
    disable)
        cmd_disable
        ;;
    test)
        cmd_test
        ;;
    monitor)
        cmd_monitor
        ;;
    config)
        cmd_config
        ;;
    audio-test)
        cmd_audio_test
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        cmd_help
        exit 1
        ;;
esac
