#!/bin/sh
#
# HK3350 Power State Tracking
# Software-only state tracking for toggle-based power control
#

STATE_FILE="/tmp/hk3350-power-state"

get_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "unknown"
    fi
}

set_state() {
    echo "$1" > "$STATE_FILE"
    echo "Power state set to: $1"
}

case "$1" in
    get)
        get_state
        ;;

    set)
        if [ "$2" = "on" ] || [ "$2" = "off" ] || [ "$2" = "unknown" ]; then
            set_state "$2"
        else
            echo "Usage: $0 set {on|off|unknown}"
            exit 1
        fi
        ;;

    status)
        STATE=$(get_state)
        echo "Tracked power state: $STATE"
        echo ""
        echo "Note: State tracking is software-only."
        echo "If amplifier was manually powered on/off, state may be incorrect."
        echo "Use '$0 set on' or '$0 set off' to correct."
        ;;

    reset)
        set_state "unknown"
        echo "Power state reset. Next playback will power on amplifier."
        ;;

    *)
        echo "HK3350 Power State Tracking"
        echo ""
        echo "Usage: $0 {get|set|status|reset}"
        echo ""
        echo "Commands:"
        echo "  get         - Get current tracked power state"
        echo "  set <state> - Set power state (on|off|unknown)"
        echo "  status      - Show current state"
        echo "  reset       - Reset state to unknown"
        echo ""
        echo "State tracking is software-only."
        echo "If amp is manually powered on/off, use 'set' to update state."
        exit 1
        ;;
esac
