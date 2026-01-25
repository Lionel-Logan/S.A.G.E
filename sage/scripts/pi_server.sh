#!/bin/bash
# Control script for SAGE Pi Server

SERVICE_NAME="sage-pi-server"

case "$1" in
    start)
        echo "🚀 Starting SAGE Pi Server..."
        sudo systemctl start "$SERVICE_NAME"
        sleep 1
        sudo systemctl status "$SERVICE_NAME" --no-pager
        ;;
    stop)
        echo "🛑 Stopping SAGE Pi Server..."
        sudo systemctl stop "$SERVICE_NAME"
        ;;
    restart)
        echo "🔄 Restarting SAGE Pi Server..."
        sudo systemctl restart "$SERVICE_NAME"
        sleep 1
        sudo systemctl status "$SERVICE_NAME" --no-pager
        ;;
    status)
        sudo systemctl status "$SERVICE_NAME" --no-pager
        ;;
    logs)
        sudo journalctl -u "$SERVICE_NAME" -f
        ;;
    test)
        echo "🧪 Testing Pi Server connectivity..."
        echo ""
        echo "Testing /ping endpoint:"
        curl -s http://localhost:8001/ping | python3 -m json.tool
        echo ""
        echo "Testing /health endpoint:"
        curl -s http://localhost:8001/health | python3 -m json.tool
        ;;
    *)
        echo "SAGE Pi Server Control Script"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|test}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the server"
        echo "  stop    - Stop the server"
        echo "  restart - Restart the server"
        echo "  status  - Show service status"
        echo "  logs    - Follow service logs (Ctrl+C to exit)"
        echo "  test    - Test server endpoints"
        exit 1
        ;;
esac
