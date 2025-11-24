# PiCorePlayer IR Volume Control Integration Plan
Using LIRC + Jivelite to Control an External Amplifier

------------------------------------------------------------
1. Enable SSH
------------------------------------------------------------
- Open PiCorePlayer Web GUI → Tweaks → SSH
- Enable SSH
- Connect using:
  ssh tc@<PiCorePlayer-IP>
  password: piCore

------------------------------------------------------------
2. Install LIRC
------------------------------------------------------------
Method A (Web GUI):
  - Go to Extensions / Plugins
  - Enable LIRC or Infrared support
  - Install, then click Backup

Method B (SSH):
  tce-load -wi lirc

After installation, the folder /etc/lirc should exist.

------------------------------------------------------------
3. Install Your Remote Config
------------------------------------------------------------
Create directory if needed:
  sudo mkdir -p /etc/lirc

Copy your remote file:
  sudo cp hk3350.conf /etc/lirc/lircd.conf

Restart LIRC:
  sudo /usr/local/etc/init.d/lircd restart

------------------------------------------------------------
4. Test LIRC IR Sending
------------------------------------------------------------
List remotes:
  irsend LIST "" ""

Send test command:
  irsend SEND_ONCE HARMAN_KARDON KEY_VOLUMEUP
Replace HARMAN_KARDON with your remote name.

------------------------------------------------------------
5. Create the IR Volume Script
------------------------------------------------------------
Create file /usr/local/bin/ir_volume.sh with this content:

  #!/bin/sh
  case "$1" in
    up)
      irsend SEND_ONCE HARMAN_KARDON KEY_VOLUMEUP
      ;;
    down)
      irsend SEND_ONCE HARMAN_KARDON KEY_VOLUMEDOWN
      ;;
    mute)
      irsend SEND_ONCE HARMAN_KARDON KEY_MUTE
      ;;
    *)
      echo "Usage: ir_volume.sh {up|down|mute}"
      ;;
  esac

Make executable:
  chmod +x /usr/local/bin/ir_volume.sh

------------------------------------------------------------
6. Configure Jivelite to Use the Script
------------------------------------------------------------
Jivelite settings are stored under:
  /mnt/mmcblk0p2/tce/etc/jivelite/
or
  /mnt/mmcblk0p2/settings/

Look for a volume command setting and replace it with:
  /usr/local/bin/ir_volume.sh %VOLUME_DIRECTION%

Where %VOLUME_DIRECTION% becomes "up" or "down".
Exact syntax may vary by Jivelite version.

------------------------------------------------------------
7. Make Changes Persistent
------------------------------------------------------------
PiCorePlayer runs from RAM, so changes are lost unless saved.

In the Web GUI:
  Main Menu → Backup → Backup Settings Now

This saves:
  - /etc/lirc
  - the IR script
  - Jivelite configuration

------------------------------------------------------------
8. End Result
------------------------------------------------------------
- Jivelite volume buttons send IR to the amplifier
- Software ALSA volume is bypassed
- Amplifier hardware controls actual volume level
- All settings survive reboot
