#!/bin/sh
#
# LMS IR Volume Bridge
# Monitors LMS/Squeezelite volume changes and sends IR commands to HK3350
#
# This script monitors LMS for volume changes and translates them to IR commands.
# ALSA volume remains fixed; only the amplifier hardware volume changes via IR.
#

CONFIG_FILE="/usr/local/etc/hk3350-ir-volume.conf"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

# Command line arguments override config file
LMS_HOST="${1:-${LMS_HOST:-localhost}}"
LMS_PORT="${2:-${LMS_PORT:-9090}}"
PLAYER_MAC="${3}"

REMOTE_NAME="${REMOTE_NAME:-hk3350}"
VOLUME_STEP="${VOLUME_STEP:-3}"
ALSA_VOLUME="${ALSA_VOLUME:-80}"

# Volume state tracking
LAST_VOLUME=""

if [ -z "$PLAYER_MAC" ]; then
    echo "Usage: $0 [lms_host] [lms_port] <player_mac>"
    echo "Example: $0 localhost 9090 00:11:22:33:44:55"
    echo ""
    echo "This script monitors LMS volume changes and sends IR commands to HK3350"
    exit 1
fi

# Check if required tools are available
if ! command -v nc >/dev/null 2>&1; then
    echo "ERROR: netcat (nc) is required but not installed"
    exit 1
fi

if ! command -v irsend >/dev/null 2>&1; then
    echo "ERROR: LIRC irsend is required but not installed"
    exit 1
fi

echo "LMS IR Volume Bridge starting..."
echo "Monitoring player: $PLAYER_MAC on $LMS_HOST:$LMS_PORT"
echo "ALSA fixed volume: $ALSA_VOLUME%"
echo "IR volume step: $VOLUME_STEP%"
echo "Press Ctrl+C to stop"
echo ""

# Set ALSA volume to fixed level on startup
if command -v amixer >/dev/null 2>&1; then
    amixer -q sset PCM "${ALSA_VOLUME}%" 2>/dev/null || true
    echo "ALSA volume set to ${ALSA_VOLUME}%"
fi

# Subscribe to LMS events
while true; do
    # Query current volume from LMS
    QUERY="$PLAYER_MAC mixer volume ?"
    RESPONSE=$(echo "$QUERY" | nc -w 1 "$LMS_HOST" "$LMS_PORT" 2>/dev/null)

    if [ -n "$RESPONSE" ]; then
        # Extract volume from response
        CURRENT_VOLUME=$(echo "$RESPONSE" | grep -oP 'mixer volume \K[0-9]+' | head -1)

        if [ -n "$CURRENT_VOLUME" ] && [ "$CURRENT_VOLUME" != "$LAST_VOLUME" ]; then
            echo "Volume changed: $LAST_VOLUME -> $CURRENT_VOLUME"

            if [ -n "$LAST_VOLUME" ]; then
                # Calculate volume difference
                DIFF=$((CURRENT_VOLUME - LAST_VOLUME))

                if [ $DIFF -gt 0 ]; then
                    # Volume increased
                    STEPS=$(( (DIFF + VOLUME_STEP - 1) / VOLUME_STEP ))
                    echo "Sending $STEPS volume up commands"
                    for i in $(seq 1 $STEPS); do
                        irsend SEND_ONCE "$REMOTE_NAME" vol-up
                        sleep 0.1
                    done
                elif [ $DIFF -lt 0 ]; then
                    # Volume decreased
                    STEPS=$(( (-DIFF + VOLUME_STEP - 1) / VOLUME_STEP ))
                    echo "Sending $STEPS volume down commands"
                    for i in $(seq 1 $STEPS); do
                        irsend SEND_ONCE "$REMOTE_NAME" vol-dn
                        sleep 0.1
                    done
                fi
            fi

            LAST_VOLUME="$CURRENT_VOLUME"
        fi
    fi

    # Poll interval
    sleep 0.5
done
