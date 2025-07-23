#!/usr/bin/python
#
#import pigpio
import sys
import time
import re
from pathlib import Path

DEFAULT_CONF_PATH = Path.home() / ".config/lirc/Harman-Kardon_HK3390.lircd.conf"
DEFAULT_CONF_PATH = "./hk3390.conf"
GPIO_PIN = 18  # Change if needed

def parse_lirc_config(path):
    with open(path, 'r') as f:
        lines = f.readlines()

    ir_config = {
        'codes': {},
    }

    in_codes = False
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        if line.startswith('header'):
            ir_config['header'] = tuple(map(int, line.split()[1:]))
        elif line.startswith('one'):
            ir_config['one'] = tuple(map(int, line.split()[1:]))
        elif line.startswith('zero'):
            ir_config['zero'] = tuple(map(int, line.split()[1:]))
        elif line.startswith('ptrail'):
            ir_config['ptrail'] = int(line.split()[1])
        elif line.startswith('bits'):
            ir_config['bits'] = int(line.split()[1])
        elif line == 'begin codes':
            in_codes = True
        elif line == 'end codes':
            in_codes = False
        elif in_codes:
            m = re.match(r"(\S+)\s+0x([0-9A-Fa-f]+)", line)
            if m:
                name, hexcode = m.groups()
                ir_config['codes'][name.lower()] = int(hexcode, 16)

    return ir_config

def generate_waveform(pi, ir, code):
    waveform = []

    # Header
    waveform.append(pigpio.pulse(1 << GPIO_PIN, 0, ir['header'][0]))
    waveform.append(pigpio.pulse(0, 1 << GPIO_PIN, ir['header'][1]))

    # Bits LSB first
    for i in range(ir['bits']):
        bit = (code >> i) & 1
        mark, space = ir['one'] if bit else ir['zero']
        waveform.append(pigpio.pulse(1 << GPIO_PIN, 0, mark))
        waveform.append(pigpio.pulse(0, 1 << GPIO_PIN, space))

    # Trailer
    waveform.append(pigpio.pulse(1 << GPIO_PIN, 0, ir['ptrail']))

    return waveform

def send_command(command_name, config_path):
    ir = parse_lirc_config(config_path)

    command_name = command_name.lower()
    if command_name not in ir['codes']:
        print(f"Unknown command: '{command_name}'")
        print("Available commands:")
        for name in sorted(ir['codes']):
            print(f"  {name}")
        sys.exit(1)

    code = ir['codes'][command_name]

    pi = pigpio.pi()
    if not pi.connected:
        print("Error: could not connect to pigpio daemon.")
        sys.exit(1)

    pi.set_mode(GPIO_PIN, pigpio.OUTPUT)
    pi.wave_clear()

    pulses = generate_waveform(pi, ir, code)
    pi.wave_add_generic(pulses)
    wid = pi.wave_create()
    pi.wave_send_once(wid)

    while pi.wave_tx_busy():
        time.sleep(0.01)

    pi.wave_delete(wid)
    pi.stop()
    print(f"Sent: {command_name}")

if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description="Send IR command via GPIO using pigpio")
    parser.add_argument("command", help="Command name to send")
    parser.add_argument("--config", help="Path to LIRC config file", default=DEFAULT_CONF_PATH)
    args = parser.parse_args()

    send_command(args.command, args.config)
