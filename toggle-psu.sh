#!/bin/bash
set -euo pipefail
# Dependencies: "gpio" utility (included with raspbian/octopi)

# These are the wiringPi-style header pin numbers, not true gpio pins.
FAN_PIN=2
PSU_PIN=4

# Setup pins as outputs (if they aren't already)
for pin in $PSU_PIN $FAN_PIN; do
    gpio export "$pin" out
    gpio mode "$pin" output
done

# Note: PSU needs to be first on, last off
if [[ $# == 1 && $1 == "on" ]]; then
    gpio write $PSU_PIN 1
    gpio write $FAN_PIN 1
elif [[ $# == 1 && $1 == "off" ]]; then
    gpio write $FAN_PIN 0
    gpio write $PSU_PIN 0
else
    echo "Invalid arguments: expected either 'on' or 'off'"
    exit 1
fi
