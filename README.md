# HK3350 IR Command CLI

This is a Python CLI tool for sending IR commands to a Harman Kardon HK3350 receiver using a Raspberry Pi GPIO pin and `pigpio`. It reads standard LIRC `.conf` files and transmits baseband IR codes via a GPIO-connected cable (e.g., to the "Remote In" 3.5mm jack).

## Features

- Sends commands by name (e.g., `power`, `vol+`, `cd`)
- Lists all available commands
- Reads standard LIRC config files
- Uses `pigpio` for precise timing

## Requirements

- Raspberry Pi with GPIO access
- `pigpio` daemon (`sudo pigpiod`)
- Python 3
- LIRC config file for HK3390 (compatible with HK3350)

## Installation

```bash
pip install pigpio
