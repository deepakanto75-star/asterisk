#!/bin/bash
set -e

# Mock the entrypoint script logic
ASTERISK_EXTERNAL_IP="1.2.3.4"
CONF_FILE="/tmp/etc/asterisk/pjsip.conf"

echo "Running entrypoint logic with IP: $ASTERISK_EXTERNAL_IP"

if [ -n "$ASTERISK_EXTERNAL_IP" ]; then
    echo "Configuring Asterisk with External IP: $ASTERISK_EXTERNAL_IP"

    # Check if file exists
    if [ -f "$CONF_FILE" ]; then
        # Check if [transport-wss] exists
        if grep -q "\[transport-wss\]" "$CONF_FILE"; then
            # Remove existing entries to avoid duplicates
            sed -i '/external_media_address/d' "$CONF_FILE"
            sed -i '/external_signaling_address/d' "$CONF_FILE"
            sed -i '/local_net/d' "$CONF_FILE"

            # Insert new entries after [transport-wss]
            sed -i "/\[transport-wss\]/a external_media_address=$ASTERISK_EXTERNAL_IP\\nexternal_signaling_address=$ASTERISK_EXTERNAL_IP\\nlocal_net=127.0.0.1/32" "$CONF_FILE"

            echo "Updated $CONF_FILE with external address configuration."
        else
            echo "Warning: [transport-wss] not found in $CONF_FILE"
        fi
    fi
fi
