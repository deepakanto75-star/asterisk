#!/bin/bash
set -e

if [ -n "$ASTERISK_EXTERNAL_IP" ]; then
    echo "Configuring Asterisk with External IP: $ASTERISK_EXTERNAL_IP"

    CONF_FILE="/etc/asterisk/pjsip.conf"

    # Check if file exists
    if [ -f "$CONF_FILE" ]; then
        # Check if [transport-wss] exists
        if grep -q "\[transport-wss\]" "$CONF_FILE"; then
            # Remove existing entries to avoid duplicates
            sed -i '/external_media_address/d' "$CONF_FILE"
            sed -i '/external_signaling_address/d' "$CONF_FILE"
            # We also remove local_net lines that might conflict or duplicate,
            # although explicit local_net config might be desirable for some users.
            # For this fix, we enforce local_net=127.0.0.1/32 to force NAT behavior.
            sed -i '/local_net/d' "$CONF_FILE"

            # Insert new entries after [transport-wss]
            # We use sed to append lines after the match.
            sed -i "/\[transport-wss\]/a external_media_address=$ASTERISK_EXTERNAL_IP\\nexternal_signaling_address=$ASTERISK_EXTERNAL_IP\\nlocal_net=127.0.0.1/32" "$CONF_FILE"

            echo "Updated $CONF_FILE with external address configuration."
        else
            echo "Warning: [transport-wss] not found in $CONF_FILE"
        fi
    fi
fi

exec "$@"
