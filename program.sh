#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
YELLOW='\033[1;33m'

# Define directories
MQTT_DIR="mqtt"
SERVER_DIR="server"
CLIENT_DIR="client"

echo -e "${YELLOW}Weather Station Control Script${NC}"

# Function to stop processes listening on specific ports
function stop_ports() {
    echo "Attempting to free up required ports..."
    for PORT in "$@"; do
        echo "- Checking port $PORT..."
        PROCESSES=$(lsof -ti:$PORT)
        if [ ! -z "$PROCESSES" ]; then
            echo "  > Found processes on port $PORT. Stopping them..."
            echo $PROCESSES | xargs kill -9
            echo -e "  > Port $PORT has been ${GREEN}freed${NC}."
        else
            echo -e "  > No processes found on port $PORT. It's already ${GREEN}available${NC}."
        fi
    done
}

# Function to install Node.js dependencies
function install_dependencies() {
    echo "Installing Node.js dependencies..."
    echo "- Server dependencies..."
    (cd $SERVER_DIR && npm install) && echo -e "  > Server dependencies ${GREEN}installed successfully${NC}." || echo -e "  > ${RED}Failed to install server dependencies${NC}."

    echo "- Client dependencies..."
    (cd $CLIENT_DIR && npm install) && echo -e "  > Client dependencies ${GREEN}installed successfully${NC}." || echo -e "  > ${RED}Failed to install client dependencies${NC}."
}

# Function to start the application components
function start_app() {
    echo "Starting application components..."
    stop_ports 3000 5173

    echo "- Starting MQTT broker..."
    (cd $MQTT_DIR && docker-compose up -d) && echo -e "  > MQTT broker ${GREEN}started${NC}." || echo -e "  > ${RED}Failed to start MQTT broker${NC}."

    echo "- Starting Node.js server..."
    (
        cd $SERVER_DIR && nohup node server.js >server.log 2>&1 &
        echo $! >"$SERVER_DIR/server.PID"
    ) && echo -e "  > Node.js server ${GREEN}started${NC}." || echo -e "  > ${RED}Failed to start Node.js server${NC}."

    echo "- Starting Vite server..."
    (
        cd $CLIENT_DIR && nohup npm run dev >client.log 2>&1 &
        echo $! >"$CLIENT_DIR/vite.PID"
    ) && echo -e "  > Vite server ${GREEN}started${NC} at http://localhost:5173/." || echo -e "  > ${RED}Failed to start Vite server${NC}."

    echo -e "All components ${GREEN}started successfully${NC}."
}

# Function to stop the application components
function stop_app() {
    echo "Stopping application components..."

    echo "- Stopping MQTT broker..."
    (cd $MQTT_DIR && docker-compose down) && echo -e "  > MQTT broker ${GREEN}stopped${NC}." || echo -e "  > ${RED}Failed to stop MQTT broker${NC}."

    stop_servers_and_clear_logs
    stop_ports 3000 5173

    echo -e "All components ${GREEN}stopped successfully${NC}."
}

function stop_servers_and_clear_logs() {
    if [ -f "$SERVER_DIR/server.PID" ]; then
        echo "- Stopping Node.js server..."
        kill -9 $(cat "$SERVER_DIR/server.PID") && echo -e "  > Node.js server ${GREEN}stopped${NC}." || echo -e "  > ${RED}Failed to stop Node.js server${NC}."
        rm "$SERVER_DIR/server.PID"
    else
        echo "- No Node.js server PID file found. Skipping."
    fi

    if [ -f "$CLIENT_DIR/vite.PID" ]; then
        echo "- Stopping Vite server..."
        kill -9 $(cat "$CLIENT_DIR/vite.PID") && echo -e "  > Vite server ${GREEN}stopped${NC}." || echo -e "  > ${RED}Failed to stop Vite server${NC}."
        rm "$CLIENT_DIR/vite.PID"
    else
        echo "- No Vite server PID file found. Skipping."
    fi

    echo "- Clearing server logs..."
    >"$SERVER_DIR/server.log"
    >"$CLIENT_DIR/client.log"
    echo -e "  > Server logs ${GREEN}cleared${NC}."
}

# Function to show the status of the Mosquitto MQTT broker
function status_app() {
    echo "Checking application status..."
    docker ps -a | grep mosquitto && echo -e "MQTT broker is ${GREEN}running${NC}." || echo -e "MQTT broker is ${RED}not running${NC}."
}

# Function to show logs of the Mosquitto MQTT broker
function log_app() {
    echo "Fetching application logs..."
    docker logs mosquitto
}

case "$1" in
install)
    install_dependencies
    ;;
start)
    start_app
    ;;
stop)
    stop_app
    ;;
status)
    status_app
    ;;
logs)
    log_app
    ;;
*)
    echo -e "${RED}Invalid command. Usage: $0 {install|start|stop|status|logs}${NC}"
    exit 1
    ;;
esac
