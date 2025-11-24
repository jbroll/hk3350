#!/bin/sh
#
# IR Volume Control Script for HK3350
# Sends infrared commands to Harman/Kardon HK3350 amplifier via LIRC
#

REMOTE_NAME="hk3350"

case "$1" in
  up)
    irsend SEND_ONCE "$REMOTE_NAME" vol-up
    ;;
  down)
    irsend SEND_ONCE "$REMOTE_NAME" vol-dn
    ;;
  mute)
    # Note: mute code not in default hk3350.conf but available as 0x10E837C
    # You may need to add it to lircd.conf
    irsend SEND_ONCE "$REMOTE_NAME" mute 2>/dev/null || echo "Mute command not configured"
    ;;
  power)
    irsend SEND_ONCE "$REMOTE_NAME" power
    ;;
  *)
    echo "Usage: ir_volume.sh {up|down|mute|power}"
    exit 1
    ;;
esac

exit 0
