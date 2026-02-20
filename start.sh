#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration Variables (Global Scope) ---
# General
NETWORK_NAME="asterisk-net"

# Database
DB_IMAGE_NAME="my-mariadb-app"
DB_CONTAINER_NAME="asterisk_db"
DB_VOLUME_NAME="asterisk_db_data"
RECORDINGS_VOLUME_NAME="asterisk_recordings"
DB_ROOT_PASSWORD="supersecretrootpassword"
DB_NAME="asterisk_db"
DB_USER="asterisk_user"
DB_PASSWORD="asterisk_password"

# Asterisk
ASTERISK_IMAGE_NAME="my-asterisk-app"
ASTERISK_CONTAINER_NAME="asterisk_server"

# Flask App
FLASK_IMAGE_NAME="my-flask-app"
FLASK_CONTAINER_NAME="flask_web_app"

# phpMyAdmin
PHPMYADMIN_IMAGE="phpmyadmin"
PHPMYADMIN_CONTAINER_NAME="phpmyadmin_service"
PHPMYADMIN_PORT="8081"

# --- Helper Functions ---
log() {
    # Usage: log "ICON" "MESSAGE"
    local icon="$1"
    local message="$2"
    echo -e "${icon} ${message}"
}

# Function to set up the Docker network
setup_network() {
    log "🌐" "Ensuring Docker network '${NETWORK_NAME}' exists..."
    if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
        log "➕" "Creating network '${NETWORK_NAME}'..."
        docker network create "${NETWORK_NAME}"
    else
        log "✅" "Network '${NETWORK_NAME}' already exists."
    fi
}

# Function to build all custom Docker images
build_images() {
    log "🔨" "Building all custom Docker images..."
    log "📦" "Building Database image (${DB_IMAGE_NAME})..."
    docker build -t ${DB_IMAGE_NAME} ./src/database

    log "📦" "Building Asterisk image (${ASTERISK_IMAGE_NAME})..."
    docker build --no-cache -t ${ASTERISK_IMAGE_NAME} ./src/asterisk_conf

    log "📦" "Building Flask App image (${FLASK_IMAGE_NAME})..."
    docker build -t ${FLASK_IMAGE_NAME} ./src/flask_app

    log "✅" "All custom images built successfully."
}

# Function to start the MariaDB database container
start_database() {
    log "🗄️" "Starting the Database container (${DB_CONTAINER_NAME})..."

    docker stop "${DB_CONTAINER_NAME}" &>/dev/null || log "ℹ️" "No existing container: ${DB_CONTAINER_NAME}"
    docker rm   "${DB_CONTAINER_NAME}" &>/dev/null || true

    docker run -d \
        --name ${DB_CONTAINER_NAME} \
        --network ${NETWORK_NAME} \
        -v ${DB_VOLUME_NAME}:/var/lib/mysql \
        -e MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD} \
        -e MYSQL_DATABASE=${DB_NAME} \
        -e MYSQL_USER=${DB_USER} \
        -e MYSQL_PASSWORD=${DB_PASSWORD} \
        --restart always \
        ${DB_IMAGE_NAME}

    log "⏳" "Waiting for the database to be ready..."
    for i in {1..30}; do
        if docker exec ${DB_CONTAINER_NAME} mysqladmin ping -u${DB_USER} -p${DB_PASSWORD} --silent >/dev/null 2>&1; then
            log "✅" "Database is ready!"
            break
        fi
        sleep 2
    done
}

# Function to start the Asterisk container
start_asterisk() {
    log "📞" "Starting the Asterisk container (${ASTERISK_CONTAINER_NAME})..."

    # Try to detect external IP (Public or LAN)
    local EXTERNAL_IP=""

    # Try getting public IP from a service with short timeout
    if command -v curl >/dev/null 2>&1; then
        EXTERNAL_IP=$(curl -s --max-time 2 https://api.ipify.org || true)
    fi

    # If failed, get local IP
    if [ -z "$EXTERNAL_IP" ]; then
        EXTERNAL_IP=$(hostname -I | awk '{print $1}')
    fi

    log "ℹ️" "Detected External/Local IP: $EXTERNAL_IP"

    docker stop "${ASTERISK_CONTAINER_NAME}" &>/dev/null || log "ℹ️" "No existing container: ${ASTERISK_CONTAINER_NAME}"
    docker rm   "${ASTERISK_CONTAINER_NAME}" &>/dev/null || true

    docker run -d \
        --name ${ASTERISK_CONTAINER_NAME} \
        --network ${NETWORK_NAME} \
        -v ${RECORDINGS_VOLUME_NAME}:/var/spool/asterisk/monitor \
        -e ASTERISK_EXTERNAL_IP="$EXTERNAL_IP" \
        -p 5038:5038 \
        -p 5060:5060/udp \
        -p 8088:8088 \
        -p 8089:8089 \
        -p 10000-10100:10000-10100/udp \
        --restart always \
        ${ASTERISK_IMAGE_NAME}
}

# Function to start the Flask web application container
start_flask_app() {
    log "🖥️" "Starting the Flask App container (${FLASK_CONTAINER_NAME})..."

    docker stop "${FLASK_CONTAINER_NAME}" &>/dev/null || log "ℹ️" "No existing container: ${FLASK_CONTAINER_NAME}"
    docker rm   "${FLASK_CONTAINER_NAME}" &>/dev/null || true

    docker run -d \
        --name ${FLASK_CONTAINER_NAME} \
        --network ${NETWORK_NAME} \
        -v ${RECORDINGS_VOLUME_NAME}:/recordings:ro \
        -p 5000:5000 \
        -e DB_HOST=${DB_CONTAINER_NAME} \
        -e DB_NAME=${DB_NAME} \
        -e DB_USER=${DB_USER} \
        -e DB_PASSWORD=${DB_PASSWORD} \
        --restart always \
        ${FLASK_IMAGE_NAME}
}

# Function to start the phpMyAdmin container
start_phpmyadmin() {
    log "🗂️" "Starting the phpMyAdmin container (${PHPMYADMIN_CONTAINER_NAME})..."

    docker stop "${PHPMYADMIN_CONTAINER_NAME}" &>/dev/null || log "ℹ️" "No existing container: ${PHPMYADMIN_CONTAINER_NAME}"
    docker rm   "${PHPMYADMIN_CONTAINER_NAME}" &>/dev/null || true

    docker run -d \
        --name ${PHPMYADMIN_CONTAINER_NAME} \
        --network ${NETWORK_NAME} \
        -p ${PHPMYADMIN_PORT}:80 \
        -e PMA_HOST=${DB_CONTAINER_NAME} \
        -e MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD} \
        --restart always \
        ${PHPMYADMIN_IMAGE}
}

# Function to print a final summary of services
print_summary() {
    echo ""
    echo "--------------------------------------------------------"
    log "🚀" "All services have been started!"
    echo "--------------------------------------------------------"
    log "🌐" "Flask App:      http://localhost:5000"
    log "🗄️" "phpMyAdmin:     http://localhost:${PHPMYADMIN_PORT}"
    echo "--------------------------------------------------------"
    echo ""
    log "📋" "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
}

# --- Main Execution Logic ---
main() {
    setup_network
    build_images        # Build all images first
    start_database      # Then start containers from the built images
    start_asterisk
    start_flask_app
    start_phpmyadmin
    print_summary
}

# Run the main function
main
