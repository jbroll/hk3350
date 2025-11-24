# HK3350 IR Volume Control for PiCorePlayer

LIRC configuration and PiCorePlayer extension for controlling Harman/Kardon HK3350/HK3390 receivers via infrared. Enables hardware volume control through IR while maintaining fixed ALSA output level.

## Hardware Requirements

- Raspberry Pi with LIRC-configured GPIO
- IR output wired to HK3350 3.5mm remote input jack
- PiCorePlayer with Squeezelite and LMS

**Wiring:**
```
Pi GPIO (3.3V output)
          |
          |---[470-1000Ω]--- Tip (3.5mm plug) ---> HK3350 Remote In
          |
    Pi GND --------------------- Sleeve (3.5mm plug) ---> HK3350 Ground
```
Current-limiting resistor (470-1000Ω) protects GPIO. LIRC handles timing via GPIO.

## Repository Contents

```
hk3350.conf                      # LIRC remote configuration (HK3350)
hk3390.conf                      # LIRC remote configuration (HK3390, reference)
hk3350.txt                       # Raw hex codes

extension/                          # TinyCore extension source
├── usr/local/bin/
│   ├── ir_volume.sh               # Direct IR volume control
│   ├── lms-ir-volume-bridge.sh    # LMS→IR volume bridge
│   ├── hk3350-power-manager.sh    # Automatic power management
│   ├── hk3350-power-feedback.sh   # Power state tracking
│   └── hk3350-setup               # Installation script
└── usr/local/etc/
    ├── lirc/hk3350.conf           # LIRC config
    └── hk3350-ir-volume.conf      # Configuration

build-extension.sh               # Build tcz package
hk3350-ir-volume.tcz.dep        # Extension dependencies
hk3350-ir-volume.tcz.info       # Extension metadata
```

## Quick Start

### Build Extension

```bash
./build-extension.sh
```

Requires `squashfs-tools`. Creates `hk3350-ir-volume.tcz`.

### Install on PiCorePlayer

```bash
# Copy to PiCorePlayer
scp hk3350-ir-volume.tcz* tc@<pcp-ip>:/tmp/

# SSH to PiCorePlayer
ssh tc@<pcp-ip>

# Install
sudo cp /tmp/hk3350-ir-volume.tcz* /mnt/mmcblk0p2/tce/optional/
tce-load -i hk3350-ir-volume
hk3350-setup
```

### Configure Fixed ALSA Volume

**1. Disable Squeezelite software volume**

In PiCorePlayer web GUI → Squeezelite Settings:
```
Output Settings: -V ""
```

**2. Configure fixed ALSA level**

Edit `/usr/local/etc/hk3350-ir-volume.conf`:
```bash
ALSA_VOLUME=80          # Fixed ALSA output level (0-100)
VOLUME_STEP=3           # IR command step size
REMOTE_NAME=hk3350
LMS_HOST=localhost
LMS_PORT=9090
POWER_OFF_TIMEOUT=300   # Idle seconds before power off (0=disabled)
POWER_ON_DELAY=2        # Seconds to wait after power on
```

**3. Start volume bridge**

```bash
# Get player MAC address
PLAYER_MAC=$(ifconfig eth0 | grep -o 'HWaddr [0-9A-Fa-f:]*' | awk '{print $2}')

# Start bridge
/usr/local/bin/lms-ir-volume-bridge.sh localhost 9090 $PLAYER_MAC
```

**4. Auto-start on boot**

Create `/home/tc/start-volume-bridge.sh`:
```bash
#!/bin/sh
sleep 10
PLAYER_MAC=$(ifconfig eth0 | grep -o 'HWaddr [0-9A-Fa-f:]*' | awk '{print $2}')
amixer -q sset PCM 80% 2>/dev/null || true
/usr/local/bin/lms-ir-volume-bridge.sh localhost 9090 "$PLAYER_MAC" >> /var/log/ir-volume-bridge.log 2>&1 &
```

Add to `/opt/bootlocal.sh`:
```bash
echo '/home/tc/start-volume-bridge.sh &' | sudo tee -a /opt/bootlocal.sh
```

**5. Backup via PiCorePlayer web GUI**

### Optional: Enable Power Management

Powers amplifier off after idle timeout, on when playback starts.

Create `/home/tc/start-power-manager.sh`:
```bash
#!/bin/sh
sleep 15
PLAYER_MAC=$(ifconfig eth0 | grep -o 'HWaddr [0-9A-Fa-f:]*' | awk '{print $2}')
/usr/local/bin/hk3350-power-manager.sh localhost 9090 "$PLAYER_MAC" >> /var/log/ir-power-manager.log 2>&1 &
```

Add to `/opt/bootlocal.sh`:
```bash
echo '/home/tc/start-power-manager.sh &' | sudo tee -a /opt/bootlocal.sh
```

**Power state management:**
```bash
# Check current state
hk3350-power-feedback.sh status

# Manually correct if desynchronized
hk3350-power-feedback.sh set on   # Amp is on
hk3350-power-feedback.sh set off  # Amp is off

# Reset state (force power-on on next playback)
hk3350-power-feedback.sh reset
```

## Architecture

```
Jivelite/LMS/Apps → LMS CLI → lms-ir-volume-bridge.sh → LIRC → HK3350
                          ↓            ↓
                    Power Manager  ALSA fixed at 80%
                      (optional)
```

**Volume control:** LMS volume changes trigger IR commands. ALSA remains fixed, preventing double adjustment.

**Power management:** Monitors playback state. Powers on when play starts, off after idle timeout. State tracked in `/tmp/hk3350-power-state`.

## Testing

```bash
# Test LIRC
irsend LIST "" ""
irsend SEND_ONCE hk3350 vol-up
irsend SEND_ONCE hk3350 power

# Test volume script
ir_volume.sh up
ir_volume.sh down
ir_volume.sh power

# Verify ALSA level
amixer sget PCM

# Check volume bridge
ps aux | grep lms-ir-volume-bridge
tail -f /var/log/ir-volume-bridge.log

# Check power manager
ps aux | grep hk3350-power-manager
tail -f /var/log/ir-power-manager.log
hk3350-power-feedback.sh status
```

## LIRC Configuration

Standard NEC protocol, 32-bit codes. Timing parameters:
```
header: 9000 4500
one:    560 1600
zero:   560 560
gap:    108000
```

Available commands in `hk3350.conf`:
- `power` - Power toggle (0x10E03FC)
- `vol-up`, `vol-dn` - Volume control (0x10EE31C, 0x10E13EC)
- `cd`, `radio`, `aux`, `video`, `tape1` - Input selection
- `tuning-`, `tuning+`, `am-fm` - Tuner control
- `1`-`0` - Presets
- `preset_scan`, `tapemon` - Additional functions

Additional codes available in `hk3350.txt` (mute, display, sleep, CD transport).

## Configuration Options

**ALSA_VOLUME** (default: 80)
- Fixed ALSA output level percentage
- Lower: More headroom, potentially lower SNR
- Higher: Better SNR, less headroom, clipping risk
- Recommended: 80-90

**VOLUME_STEP** (default: 3)
- Percentage change per IR command
- Lower: Finer control, more IR commands sent
- Higher: Coarser control, fewer IR commands
- Recommended: 3-5

**POWER_OFF_TIMEOUT** (default: 300)
- Seconds idle before automatic power off
- Set to 0 to disable power management
- Idle = stopped or paused, not playing
- Recommended: 300-600 (5-10 minutes)

**POWER_ON_DELAY** (default: 2)
- Seconds to wait after power on command
- Allows amplifier to warm up before audio
- Increase if amplifier takes longer to power on

## Troubleshooting

**ALSA volume changes when using Jivelite**
- Verify Squeezelite has `-V ""` parameter: `ps aux | grep squeezelite`

**Volume bridge not sending IR commands**
- Check bridge running: `ps aux | grep lms-ir-volume-bridge`
- Check logs: `tail -f /var/log/ir-volume-bridge.log`
- Verify player MAC: `echo "players 0 9" | nc localhost 9090`

**IR commands not controlling amplifier**
- Test LIRC: `irsend SEND_ONCE hk3350 vol-up`
- Check LIRC daemon: `ps aux | grep lircd`
- Verify configuration: `cat /etc/lirc/lircd.conf`

**Changes lost after reboot**
- PiCorePlayer runs from RAM
- Always backup via web GUI after changes

**Power state desynchronized**
- Amplifier manually powered on/off (state tracker doesn't know)
- State file lost on reboot (stored in `/tmp/`)
- Fix: `hk3350-power-feedback.sh set on` or `set off`
- Or: `hk3350-power-feedback.sh reset` (forces power-on next playback)
- Note: Software-only tracking, no hardware feedback available

**Amplifier doesn't power on/off**
- Check power manager running: `ps aux | grep hk3350-power-manager`
- Check logs: `tail -f /var/log/ir-power-manager.log`
- Verify power IR code: `irsend SEND_ONCE hk3350 power`
- Check timeout setting in config file

## Direct Usage (Without Volume Bridge)

For manual IR control or integration with other systems:

```bash
# Direct volume control
ir_volume.sh up|down|mute|power

# Direct LIRC commands
irsend SEND_ONCE hk3350 vol-up
irsend SEND_ONCE hk3350 power
```

## Technical Details

**TCZ Extension Structure**
- SquashFS filesystem with `-b 4k -no-xattrs`
- Loop-mounted to `/tmp/tcloop/hk3350-ir-volume/`
- Files symlinked to `/usr/local/*`
- Depends on `lirc.tcz`

**Volume Bridge Operation**
- Polls LMS CLI every 0.5s for volume changes
- Calculates delta from last known value
- Sends appropriate number of IR commands
- Sets ALSA to fixed level on startup
- 0.5-1s latency between UI change and IR command

**Power Manager Operation**
- Polls LMS CLI every 5s for playback mode
- States: `play`, `pause`, `stop`
- Powers on when transitioning to `play`
- Starts idle timer when transitioning to `pause`/`stop`
- Powers off after `POWER_OFF_TIMEOUT` seconds idle
- State tracked in `/tmp/hk3350-power-state`

**Power State Tracking**
- Software-only tracking (no hardware feedback)
- Toggle command requires state tracking
- Desynchronizes if amplifier manually powered on/off
- State file in `/tmp/` (lost on reboot)
- Manual correction: `hk3350-power-feedback.sh set on|off|reset`

**Squeezelite Configuration**
- `-V ""` disables ALSA mixer volume control
- Squeezelite outputs at fixed gain
- LMS volume changes intercepted by bridge
- Alternative: `-a ALSA_VOLUME` to set fixed output level directly

## License

Configuration files are public domain. Scripts are provided as-is.
