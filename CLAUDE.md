# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LIRC (Linux Infrared Remote Control) configuration files for Harman/Kardon receivers, specifically the HK3350 and HK3390 models. These configurations enable IR control via Raspberry Pi GPIO or other LIRC-compatible hardware.

The primary use case documented is integration with PiCorePlayer to send IR commands to an external amplifier, bypassing software volume control in favor of hardware amplifier volume control.

## Repository Structure

- `hk3350.conf` - LIRC configuration for HK3350 receiver (primary, tested configuration)
- `hk3350.txt` - Raw hex codes for HK3350 in simplified format
- `hk3390.conf` - LIRC configuration for HK3390 receiver (reference)
- `PLAN.md` - Detailed integration guide for PiCorePlayer + Jivelite + LIRC setup
- `EXTENSION.md` - Documentation for the PiCorePlayer extension package
- `extension/` - TinyCore extension directory structure
- `build-extension.sh` - Script to build the tcz package
- `hk3350-ir-volume.tcz.dep` - Extension dependency file
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

## Building the PiCorePlayer Extension

The repository includes a complete TinyCore extension package for easy installation:

```bash
# Build the extension (requires squashfs-tools)
./build-extension.sh
```

This creates `hk3350-ir-volume.tcz` containing:
- `/usr/local/bin/ir_volume.sh` - Volume control script
- `/usr/local/bin/hk3350-setup` - Automated setup script
- `/usr/local/etc/lirc/hk3350.conf` - LIRC configuration
- `/usr/local/share/doc/hk3350-ir-volume/README` - Documentation

### Extension Installation

Quick install on PiCorePlayer:

```bash
# Copy to PiCorePlayer
scp hk3350-ir-volume.tcz* tc@<picoreplayer-ip>:/tmp/

# SSH to PiCorePlayer
ssh tc@<picoreplayer-ip>

# Install
sudo cp /tmp/hk3350-ir-volume.tcz* /mnt/mmcblk0p2/tce/optional/
tce-load -i hk3350-ir-volume
hk3350-setup

# Backup via web GUI
```

See EXTENSION.md for complete installation instructions and troubleshooting.

### Extension Architecture

TinyCore extensions (tcz) are squashfs filesystems:
- Built with `mksquashfs` using `-b 4k -no-xattrs` flags
- Loop-mounted to `/tmp/tcloop/<name>/` at runtime
- Files symlinked to system paths (typically under `/usr/local/`)
- Dependencies listed in `.tcz.dep` (one per line)
- Metadata in `.tcz.info` for extension managers

The extension automatically depends on `lirc.tcz` and will pull it in if not installed.
