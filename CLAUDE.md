# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LIRC configuration and PiCorePlayer extension for controlling Harman/Kardon HK3350/HK3390 receivers via infrared. Provides hardware volume control through IR while maintaining fixed ALSA output level.

**Primary documentation**: README.md contains complete setup, configuration, and troubleshooting information.

## Repository Structure

- `README.md` - Complete documentation (consolidated from all guides)
- `hk3350.conf` - LIRC configuration for HK3350 (primary, tested)
- `hk3390.conf` - LIRC configuration for HK3390 (reference)
- `hk3350.txt` - Raw hex codes
- `extension/` - TinyCore extension source
  - `usr/local/bin/ir_volume.sh` - Direct IR volume control
  - `usr/local/bin/lms-ir-volume-bridge.sh` - LMS→IR volume bridge
  - `usr/local/bin/hk3350-setup` - Installation script
  - `usr/local/bin/squeezelite-ir-wrapper.sh` - Volume wrapper (experimental)
  - `usr/local/etc/lirc/hk3350.conf` - LIRC config
  - `usr/local/etc/hk3350-ir-volume.conf` - Configuration file
- `build-extension.sh` - Build tcz package
- `hk3350-ir-volume.tcz.dep` - Extension dependencies
- `hk3350-ir-volume.tcz.info` - Extension metadata

## LIRC Configuration Format

LIRC conf files follow this structure:

```
begin remote
  name <remote_name>
  bits 32
  flags SPACE_ENC|CONST_LENGTH
  header <pulse> <space>
  one <pulse> <space>
  zero <pulse> <space>
  ptrail <pulse>
  gap <microseconds>

  begin codes
    <button_name> <hex_code>
  end codes
end remote
```

**Key timing parameters:**
- Header: Initial pulse/space pair that starts transmission
- One/Zero: Pulse/space pairs representing binary 1 and 0
- Gap: Time between repeated transmissions (in microseconds)

The HK3350 uses standard NEC-like IR protocol with 32-bit codes.

## Testing LIRC Configuration

After installing a conf file to `/etc/lirc/lircd.conf`:

```bash
# Restart LIRC daemon
sudo /usr/local/etc/init.d/lircd restart

# List available remotes
irsend LIST "" ""

# List codes for a remote
irsend LIST <remote_name> ""

# Send a test command
irsend SEND_ONCE <remote_name> <button_name>

# Example for HK3350
irsend SEND_ONCE hk3350 vol-up
```

## Common Button Mappings

HK3350 supports:
- Power control: `power`
- Input selection: `cd`, `radio`, `aux`, `video`, `tape1`
- Volume: `vol-up`, `vol-dn`
- Tuner: `tuning-`, `tuning+`, `am-fm`
- Presets: `1` through `0` (10 presets), `preset_scan`
- Tape monitor: `tapemon`

Additional codes available in `hk3350.txt` include CD transport controls (play, pause, stop, skip) and display/sleep/mute functions, though not all are included in the primary conf file.

## Hardware Setup

Typical wiring for Raspberry Pi GPIO to HK3350 remote input:
- GPIO pin configured for IR transmission (via LIRC)
- Direct wire to receiver's 3.5mm remote jack
- No additional IR LED needed (receiver accepts wired remote signal)

Refer to LIRC documentation and PiCorePlayer guides for GPIO pin configuration.

## PiCorePlayer Integration

The PLAN.md file contains step-by-step instructions for integrating with PiCorePlayer:
1. SSH access and LIRC installation via tce-load
2. Configuration deployment to `/etc/lirc/lircd.conf`
3. Volume control script creation at `/usr/local/bin/ir_volume.sh`
4. Jivelite configuration to call the volume script
5. Backup procedure to persist changes across reboots

Since PiCorePlayer runs from RAM, all changes must be explicitly backed up via the web GUI.

## Modifying Configurations

When adding new buttons or modifying codes:

1. Obtain hex codes from manufacturer documentation or IR capture
2. Add to the `begin codes` section using format: `<name> 0x<hex>`
3. Test with `irsend SEND_ONCE <remote> <name>`
4. Verify timing parameters if codes don't work (header, one, zero, gap values)

The hex codes follow NEC protocol encoding. If creating a new remote config, start with timing parameters from an existing working config (hk3350.conf or hk3390.conf) and adjust if needed.

## Building and Installing Extension

Build the extension:
```bash
./build-extension.sh  # Requires squashfs-tools
```

Install on PiCorePlayer - see README.md "Quick Start" section for complete instructions.

## Volume Control Architecture

```
Jivelite/LMS/Apps → LMS CLI → lms-ir-volume-bridge.sh → LIRC → HK3350
                                        ↓
                               ALSA fixed at 80%
```

Key points:
- Squeezelite configured with `-V ""` to disable software volume control
- ALSA output fixed at configured level (default 80%)
- LMS volume changes trigger IR commands only
- Prevents double adjustment (software + hardware)
- All configuration in `/usr/local/etc/hk3350-ir-volume.conf`

See README.md for complete configuration steps, troubleshooting, and technical details.
