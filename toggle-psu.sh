#!/bin/bash
set -euo pipefail
# Dependencies: "gpio" utility (included with raspbian/octopi)

# These are the wiringPi-style header pin numbers, not true gpio pins.
RAMPS_PIN=4
PSU_PIN=5
KLIPPER_SERIAL=/tmp/printer

# Setup pins as outputs (if they aren't already)
for pin in $PSU_PIN $RAMPS_PIN; do
    # gpio mode "$pin" output
    gpio export "$pin" out
done

# Note: PSU needs to be first on, last off
if [[ $# == 1 && $1 == "on" ]]; then
    gpio write $PSU_PIN 1
    sleep 1
    gpio write $RAMPS_PIN 1
    echo firmware_restart > /tmp
    sleep 3
elif [[ $# == 1 && $1 == "off" ]]; then
    gpio write $RAMPS_PIN 0
    sleep 1
    gpio write $PSU_PIN 0
else
    echo "Invalid arguments: expected either 'on' or 'off'"
    exit 1
fi
