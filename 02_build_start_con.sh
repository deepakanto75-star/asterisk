#!/bin/bash
set -euo pipefail

### ========================
### CONFIG & LOG FUNCTION
### ========================
log() {
    local status="$1"  # ✅ ❌ ⚠️ 📦 etc.
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ $status ] $message"
}

require() {
    command -v "$1" >/dev/null 2>&1 || {
        log "❌" "Missing dependency: $1"
        exit 1
    }
}

### ========================
### USAGE CHECK
### ========================
if [ "$#" -ne 1 ]; then
    log "❌" "Usage: $0 {local|dev|uat|prod}"
    exit 1
fi

BUILD_ENV="$1"
case "$BUILD_ENV" in
    local|dev|uat|prod) ;;
    *)
        log "❌" "Invalid environment: $BUILD_ENV. Use local, dev, uat, prod."
        exit 1
        ;;
esac

### ========================
### DEPENDENCIES
### ========================
require jq
require docker
require dos2unix

### ========================
### LOAD CONFIG
### ========================
CONFIG_FILE="config.json"
APP_PREFIX=$(jq -r '."app-prefix"' "$CONFIG_FILE")
APP_NAME=$(jq -r '."app-name"' "$CONFIG_FILE")
APP_SUFFIX=$(jq -r '."app-suffix"' "$CONFIG_FILE")
APP_FOLDER=$(jq -r '."app-folder"' "$CONFIG_FILE")
APP_DOMAIN_NAME=$(jq -r '."app-domain-name"' "$CONFIG_FILE")

[ -z "$APP_PREFIX" ] && log "❌" "APP_PREFIX not set in config.json" && exit 1
[ -z "$APP_NAME" ] && log "❌" "APP_NAME not set in config.json" && exit 1

# --- ADDED: Define Docker network name ---
DOCKER_NETWORK="${APP_NAME}-network"

### ========================
### ENVIRONMENT SETUP
### ========================
case "$BUILD_ENV" in
    local)
        ENV_FILE="envs/env_01.${BUILD_ENV}"
        PERSISTENCE_VOLUME="$(pwd)/${BUILD_ENV}"
        ;;
    dev)
        ENV_FILE="envs/env_02.${BUILD_ENV}"
        PERSISTENCE_VOLUME="/mnt/nfs/k8s_${BUILD_ENV}.${APP_DOMAIN_NAME}/${APP_NAME}"
        ;;
    uat)
        ENV_FILE="envs/env_03.${BUILD_ENV}"
        PERSISTENCE_VOLUME="/mnt/nfs/k8s_${BUILD_ENV}.${APP_DOMAIN_NAME}/${APP_NAME}"
        ;;
    prod)
        ENV_FILE="envs/env_04.${BUILD_ENV}"
        PERSISTENCE_VOLUME="/mnt/nfs/k8s_${BUILD_ENV}.${APP_DOMAIN_NAME}/${APP_NAME}"
        ;;
esac

[ ! -f "$ENV_FILE" ] && log "❌" "Environment file $ENV_FILE not found!" && exit 1

set -o allexport
source "$ENV_FILE"
set +o allexport
dos2unix "$ENV_FILE"
log "✅" "Loaded environment variables from $ENV_FILE"


create_network() {
    if ! docker network inspect "${DOCKER_NETWORK}" >/dev/null 2>&1; then
        log "📦" "Creating Docker network '${DOCKER_NETWORK}'..."
        docker network create "${DOCKER_NETWORK}"
        log "✅" "Network created."
    else
        log "✅" "Docker network '${DOCKER_NETWORK}' already exists."
    fi
}


# Function to start the MariaDB database container
start_database() {
    echo "--> Starting the Database container (${APP_NAME}-mysql)..."

    docker stop "${APP_NAME}-mysql" &>/dev/null || log "✅" "No existing (${APP_NAME}-mysql) container"
    docker rm   "${APP_NAME}-mysql" &>/dev/null || true

    docker run -d \
        --name ${APP_NAME}-mysql \
        --network ${DOCKER_NETWORK} \
        -v "${PERSISTENCE_VOLUME}:/var/lib/mysql" \
        -e MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD} \
        -e MYSQL_DATABASE=${DB_NAME} \
        -e MYSQL_USER=${DB_USER} \
        -e MYSQL_PASSWORD=${DB_PASSWORD} \
        --restart always \
        ${APP_NAME}-mysql

    echo "--> Waiting for the database to initialize (15 seconds)..."
    sleep 15
}


# Function to start the Asterisk container
start_asterisk() {
    echo "--> Starting the Asterisk container (${APP_NAME}-asterisk)..."

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

    echo "Detected External/Local IP: $EXTERNAL_IP"

    docker stop "${APP_NAME}-asterisk" &>/dev/null || log "✅" "No existing  (${APP_NAME}-asterisk) container"
    docker rm   "${APP_NAME}-asterisk" &>/dev/null || true

    docker run -d \
        --name ${APP_NAME}-asterisk \
        --network ${DOCKER_NETWORK} \
        -e ASTERISK_EXTERNAL_IP="$EXTERNAL_IP" \
        -p 5038:5038 \
        -p 5060:5060/udp \
        -p 5061:5061/tcp \
        -p 8088:8088 \
        -p 8089:8089 \
        -p 10000-10020:10000-10020/udp \
        -v "$PERSISTENCE_VOLUME/20250829/asterisk_conf:/etc/asterisk" \
        -v "$PERSISTENCE_VOLUME/20250829/asterisk_lib:/var/lib/asterisk" \
        -v "$PERSISTENCE_VOLUME/20250829/asterisk_spool:/var/spool/asterisk" \
        -v "$PERSISTENCE_VOLUME/20250829/asterisk_log:/var/log/asterisk" \
        -v "$PERSISTENCE_VOLUME/20250829/asterisk_recordings:/var/spool/asterisk/monitor" \
        --restart always \
        ${APP_NAME}-asterisk


}


# Function to start the Flask web application container
start_flask_app() {
    echo "--> Starting the Flask App container (${APP_NAME}-frontend)..."
   
    docker stop "${APP_NAME}-frontend" &>/dev/null || log "✅" "No existing (${APP_NAME}-frontend container"
    docker rm   "${APP_NAME}-frontend" &>/dev/null || true

    docker run -d \
    --name ${APP_NAME}-frontend \
    --network ${DOCKER_NETWORK} \
    -p 5000:5000 \
    -e DB_HOST=${APP_NAME}-mysql \
    -e DB_NAME=${DB_NAME} \
    -e DB_USER=${DB_USER} \
    -e DB_PASSWORD=${DB_PASSWORD} \
    -v "${PERSISTENCE_VOLUME}/flask_app_data:/app/data" \
    -v "${PERSISTENCE_VOLUME}/flask_app_logs:/app/logs" \
    --restart always \
    ${APP_NAME}-frontend

}

### ========================
### RUN STEPS
### ========================
create_network
start_database
start_asterisk
start_flask_app

log "🎉" "All containers started successfully!"


