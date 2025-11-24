# HK3350 IR Volume Control Extension for PiCorePlayer

This document describes how to build and install the HK3350 IR volume control extension for PiCorePlayer.

## Overview

The `hk3350-ir-volume.tcz` extension packages the LIRC configuration and volume control scripts into an installable TinyCore extension. This allows PiCorePlayer to control your HK3350 amplifier's hardware volume via infrared instead of using software ALSA volume control.

## Building the Extension

### Prerequisites

Install squashfs-tools on your build machine:

```bash
# Debian/Ubuntu
sudo apt-get install squashfs-tools

# Fedora
sudo dnf install squashfs-tools

# Arch
sudo pacman -S squashfs-tools
```

### Build Process

Run the build script:

```bash
./build-extension.sh
```

This will create:
- `hk3350-ir-volume.tcz` - The extension package
- `hk3350-ir-volume.tcz.md5.txt` - MD5 checksum

The extension includes:
- `/usr/local/bin/ir_volume.sh` - Volume control script
- `/usr/local/bin/hk3350-setup` - Setup and configuration script
- `/usr/local/etc/lirc/hk3350.conf` - LIRC remote configuration
- `/usr/local/share/doc/hk3350-ir-volume/README` - Documentation

## Installation on PiCorePlayer

### Method 1: Manual Installation

1. **Copy the extension to PiCorePlayer:**
   ```bash
   scp hk3350-ir-volume.tcz* tc@<picoreplayer-ip>:/tmp/
   ```

2. **SSH into PiCorePlayer:**
   ```bash
   ssh tc@<picoreplayer-ip>
   # Default password: piCore
   ```

3. **Install LIRC if not already installed:**
   ```bash
   tce-load -wi lirc
   ```

4. **Copy extension to the optional directory:**
   ```bash
   sudo cp /tmp/hk3350-ir-volume.tcz* /mnt/mmcblk0p2/tce/optional/
   ```

5. **Add to onboot.lst (optional, for automatic loading):**
   ```bash
   echo "hk3350-ir-volume.tcz" | sudo tee -a /mnt/mmcblk0p2/tce/onboot.lst
   ```

6. **Load the extension:**
   ```bash
   tce-load -i hk3350-ir-volume
   ```

7. **Run the setup script:**
   ```bash
   hk3350-setup
   ```

8. **Backup your configuration:**
   - Open PiCorePlayer web GUI
   - Go to Main Menu → Backup → Backup Settings Now

### Method 2: Via PiCorePlayer Web GUI

1. Copy `hk3350-ir-volume.tcz` to a USB drive

2. In PiCorePlayer web GUI:
   - Go to Extensions / Plugins
   - Upload the extension from USB
   - Enable it for onboot

3. SSH into PiCorePlayer and run:
   ```bash
   hk3350-setup
   ```

4. Backup via web GUI

## Testing

After installation, test the configuration:

```bash
# List available remotes
irsend LIST "" ""

# Send test commands
irsend SEND_ONCE hk3350 vol-up
irsend SEND_ONCE hk3350 vol-dn

# Test volume control script
ir_volume.sh up
ir_volume.sh down
ir_volume.sh power
```

## Jivelite Integration

To integrate with Jivelite for hardware volume control:

1. Locate Jivelite settings (usually in `/mnt/mmcblk0p2/tce/etc/jivelite/`)

2. Configure Jivelite to use `/usr/local/bin/ir_volume.sh` for volume control

3. The exact configuration method depends on your Jivelite version

4. Backup your configuration after changes

## Hardware Requirements

This extension requires:
- Raspberry Pi with GPIO configured for IR transmission
- LIRC properly configured to use the GPIO pin
- IR output wired to HK3350's 3.5mm remote input jack

Refer to PLAN.md for detailed hardware setup instructions.

## Available IR Commands

The hk3350.conf includes these commands:
- `power` - Power toggle
- `vol-up`, `vol-dn` - Volume control
- `cd`, `radio`, `aux`, `video`, `tape1` - Input selection
- `tuning-`, `tuning+`, `am-fm` - Tuner control
- `1` through `0` - Preset buttons
- `preset_scan`, `tapemon` - Additional functions

## Troubleshooting

### LIRC not working
- Verify LIRC is installed: `which irsend`
- Check LIRC daemon is running: `ps aux | grep lircd`
- Review LIRC configuration: `cat /etc/lirc/lircd.conf`

### IR commands not controlling amplifier
- Verify hardware connections
- Check GPIO pin configuration in LIRC
- Test with direct irsend commands
- Ensure amplifier is powered on and in range

### Changes lost after reboot
- Remember that PiCorePlayer runs from RAM
- Always backup after making changes via web GUI
- Extension should be in onboot.lst for automatic loading

## Dependencies

The extension automatically depends on:
- `lirc.tcz` - LIRC infrared remote control

This is specified in `hk3350-ir-volume.tcz.dep` and will be installed automatically.

## Uninstallation

To remove the extension:

1. Remove from onboot.lst:
   ```bash
   sudo sed -i '/hk3350-ir-volume.tcz/d' /mnt/mmcblk0p2/tce/onboot.lst
   ```

2. Restore previous LIRC configuration if you backed it up:
   ```bash
   sudo cp /etc/lirc/lircd.conf.backup.* /etc/lirc/lircd.conf
   sudo /usr/local/etc/init.d/lircd restart
   ```

3. Backup your configuration

4. Reboot to complete removal

## License

This extension uses the same license as the HK3350-remote repository.

## Support

For issues and questions, visit: https://github.com/[your-repo]/HK3350-remote
