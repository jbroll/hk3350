#!/bin/sh
#
# HK3350 Power Manager
# Monitors LMS player state and controls amplifier power
#
# Handles power on/off based on playback state with timeout
# Tracks power state to handle toggle-only IR command
#

CONFIG_FILE="/usr/local/etc/hk3350-ir-volume.conf"
STATE_FILE="/tmp/hk3350-power-state"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

LMS_HOST="${1:-${LMS_HOST:-localhost}}"
LMS_PORT="${2:-${LMS_PORT:-9090}}"
PLAYER_MAC="${3}"

REMOTE_NAME="${REMOTE_NAME:-hk3350}"
POWER_OFF_TIMEOUT="${POWER_OFF_TIMEOUT:-300}"  # Seconds idle before power off (default: 5 min)
POWER_ON_DELAY="${POWER_ON_DELAY:-2}"          # Seconds to wait after power on

# Power state tracking
# States: "on", "off", "unknown"
get_power_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "unknown"
    fi
}

set_power_state() {
    echo "$1" > "$STATE_FILE"
}

send_power_toggle() {
    irsend SEND_ONCE "$REMOTE_NAME" power
    sleep 0.5
}

power_on() {
    CURRENT_STATE=$(get_power_state)

    if [ "$CURRENT_STATE" = "on" ]; then
        echo "Amplifier already on"
        return 0
    fi

    echo "Sending power ON command"
    send_power_toggle
    set_power_state "on"

    # Wait for amplifier to power up
    sleep "$POWER_ON_DELAY"
}

power_off() {
    CURRENT_STATE=$(get_power_state)

    if [ "$CURRENT_STATE" = "off" ]; then
        echo "Amplifier already off"
        return 0
    fi

    echo "Sending power OFF command"
    send_power_toggle
    set_power_state "off"
}

# Check if required tools are available
if [ -z "$PLAYER_MAC" ]; then
    echo "Usage: $0 [lms_host] [lms_port] <player_mac>"
    echo "Example: $0 localhost 9090 00:11:22:33:44:55"
    echo ""
    echo "Monitors player state and controls amplifier power:"
    echo "  - Powers on when playback starts"
    echo "  - Powers off after ${POWER_OFF_TIMEOUT}s idle"
    exit 1
fi

if ! command -v nc >/dev/null 2>&1; then
    echo "ERROR: netcat (nc) required but not installed"
    exit 1
fi

if ! command -v irsend >/dev/null 2>&1; then
    echo "ERROR: LIRC irsend required but not installed"
    exit 1
fi

echo "HK3350 Power Manager starting..."
echo "Monitoring player: $PLAYER_MAC on $LMS_HOST:$LMS_PORT"
echo "Power off timeout: ${POWER_OFF_TIMEOUT}s"
echo "Current power state: $(get_power_state)"
echo ""

LAST_MODE=""
IDLE_START=""

while true; do
    # Query player mode from LMS
    QUERY="$PLAYER_MAC mode ?"
    RESPONSE=$(echo "$QUERY" | nc -w 1 "$LMS_HOST" "$LMS_PORT" 2>/dev/null)

    if [ -n "$RESPONSE" ]; then
        # Extract mode from response (play, pause, stop)
        CURRENT_MODE=$(echo "$RESPONSE" | grep -oP 'mode \K[a-z]+' | head -1)

        if [ -n "$CURRENT_MODE" ]; then
            case "$CURRENT_MODE" in
                play)
                    if [ "$LAST_MODE" != "play" ]; then
                        echo "Playback started"
                        power_on
                        IDLE_START=""
                    fi
                    ;;

                pause|stop)
                    if [ "$LAST_MODE" = "play" ]; then
                        echo "Playback stopped/paused, starting idle timer"
                        IDLE_START=$(date +%s)
                    elif [ -n "$IDLE_START" ]; then
                        # Check if timeout exceeded
                        NOW=$(date +%s)
                        IDLE_TIME=$((NOW - IDLE_START))

                        if [ $IDLE_TIME -ge $POWER_OFF_TIMEOUT ]; then
                            echo "Idle timeout reached (${IDLE_TIME}s), powering off"
                            power_off
                            IDLE_START=""
                        fi
                    fi
                    ;;
            esac

            LAST_MODE="$CURRENT_MODE"
        fi
    fi

    sleep 5
done
