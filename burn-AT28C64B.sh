#!/usr/bin/env bash

# Burn a binary to an AT28C64B (8k) EEPROM
# Usage: ./burn-AT28C64B.sh build/beandeck_minimal.bin

minipro -u -s -p AT28C64B -w $1
