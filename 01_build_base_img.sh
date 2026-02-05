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


### ========================
### BUILD CUSTOM IMAGES
### ========================
build_images() {
    log "📦" "Building custom Docker images..."

    docker pull debian:bullseye-slim
    docker build --no-cache -t "${APP_NAME}-asterisk"     -f src/asterisk_conf/Dockerfile      src/asterisk_conf
    log "✅" "(${APP_NAME}-asterisk) image built."

    docker pull python:3.11-slim
    docker build -t "${APP_NAME}-frontend"     -f src/flask_app/Dockerfile         src/flask_app
    log "✅" "(${APP_NAME}-frontend) image built."

    docker pull mariadb:10.6
    docker build -t "${APP_NAME}-mysql"        -f src/database/Dockerfile       src/database
    log "✅" "(${APP_NAME}-mysql) image built."
    
    log "✅" "Custom Docker images built."
}


### ========================
### RUN STEPS
### ========================
build_images

log "🎉" "All images built successfully!"