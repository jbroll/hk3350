#!/bin/sh
#
# Squeezelite IR Volume Wrapper
# Intercepts Squeezelite volume commands and sends them to IR instead
#
# This wrapper script replaces the standard ALSA volume control with IR commands.
# It keeps ALSA at a fixed level and uses IR to control the amplifier directly.
#

CONFIG_FILE="/usr/local/etc/hk3350-ir-volume.conf"
DEFAULT_ALSA_VOLUME="80"  # Default fixed ALSA volume percentage (0-100)

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

ALSA_VOLUME="${ALSA_VOLUME:-$DEFAULT_ALSA_VOLUME}"
REMOTE_NAME="${REMOTE_NAME:-hk3350}"

# Volume control via IR
ir_volume() {
    ACTION="$1"
    case "$ACTION" in
        up)
            irsend SEND_ONCE "$REMOTE_NAME" vol-up
            ;;
        down)
            irsend SEND_ONCE "$REMOTE_NAME" vol-dn
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

# Main command handling
case "$1" in
    get)
        # Always return the fixed ALSA volume
        echo "$ALSA_VOLUME"
        ;;
    set)
        # Intercept volume set commands and convert to IR
        NEW_VOL="$2"
        CURRENT_VOL="$ALSA_VOLUME"

        if [ "$NEW_VOL" -gt "$CURRENT_VOL" ]; then
            # Volume increase
            ir_volume up
        elif [ "$NEW_VOL" -lt "$CURRENT_VOL" ]; then
            # Volume decrease
            ir_volume down
        fi
        # Always report success but don't change ALSA
        echo "$ALSA_VOLUME"
        ;;
    *)
        echo "Usage: $0 {get|set <volume>}"
        exit 1
        ;;
esac

exit 0
