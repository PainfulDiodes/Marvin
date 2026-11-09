#!/usr/bin/env bash

# Burn a binary to an AT28C256 (32k) EEPROM
# Usage: ./burn-AT28C256.sh build/beandeck.bin

minipro -u -s -p AT28C256 -w $1
