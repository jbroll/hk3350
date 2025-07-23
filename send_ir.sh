#!/bin/sh

GPIOCHIP="gpiochip0"  # Change if different; check with gpioinfo
PIN=17                # Change if needed

BITS=32

# Timing constants in seconds (precomputed from microseconds)
HEADER_MARK=0.009039
HEADER_SPACE=0.004406
ONE_MARK=0.000639
ONE_SPACE=0.001601
ZERO_MARK=0.000639
ZERO_SPACE=0.000486
PTRAIL=0.000641

send_pair() {
  mark_sec=$1
  space_sec=$2

  gpioset $GPIOCHIP $PIN=1
  sleep $mark_sec
  gpioset $GPIOCHIP $PIN=0
  sleep $space_sec
}

send_code() {
  code=$1

  send_pair $HEADER_MARK $HEADER_SPACE

  i=0
  while [ $i -lt $BITS ]; do
    bit=$(( (code >> i) & 1 ))
    if [ "$bit" -eq 1 ]; then
      send_pair $ONE_MARK $ONE_SPACE
    else
      send_pair $ZERO_MARK $ZERO_SPACE
    fi
    i=$((i + 1))
  done

  send_pair $PTRAIL 0
}

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

if [ -z "$1" ]; then
  echo "Usage: $0 <command>"
  echo "Available commands: power off speaker1 speaker2 phono cd volup voldown mute sleep"
  exit 1
fi

hexcode=$(get_code "$1")
code=$((hexcode))

send_code $code
