#!/bin/bash
# Test script for IP detection logic

log() { echo "$1 $2"; }

# Try to detect external IP (Public or LAN)
EXTERNAL_IP=""

# Try getting public IP from a service with short timeout
if command -v curl >/dev/null 2>&1; then
    EXTERNAL_IP=$(curl -s --max-time 2 https://api.ipify.org || true)
fi

# If failed, get local IP
if [ -z "$EXTERNAL_IP" ]; then
    EXTERNAL_IP=$(hostname -I | awk '{print $1}')
fi

echo "Detected IP: $EXTERNAL_IP"
