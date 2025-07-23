#!/bin/sh

# Path to the new C binary (adjust if needed)
SEND_IR_CMD="./send_ir"

get_code() {
  case "$1" in
    power) echo 0x616E02FD ;;
    off) echo 0x616E827D ;;
    speaker1) echo 0x616E42BD ;;
    speaker2) echo 0x616EC23D ;;
    phono) echo 0x616E22DD ;;
    cd) echo 0x616E12ED ;;
    volup|volumeup) echo 0x616E2AD5 ;;
    voldown|volumedown) echo 0x616ECA35 ;;
    mute) echo 0x616E5AA5 ;;
    sleep) echo 0x616EDA25 ;;
    *) echo "Unknown command: $1" >&2; exit 1 ;;
  esac
}

if [ $# -eq 0 ]; then
  echo "Usage: $0 <command1> [<command2> ...]"
  echo "Available commands: power off speaker1 speaker2 phono cd volup voldown mute sleep"
  exit 1
fi

# Build argument list of hex codes
codes=""
for cmd in "$@"; do
  hex=$(get_code "$cmd") || exit 1
  codes="$codes $hex"
done

# Call the new C program with all hex codes at once
$SEND_IR_CMD $codes

