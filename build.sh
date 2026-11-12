#!/usr/bin/env bash

# Build one firmware image. Run from the repo root.
# Usage: ./build.sh <name>
#   e.g. ./build.sh beanzee
#        ./build.sh beanzee_minimal
#
# <name> is a .lst file in manifests/, giving the sources in link order.
# What goes into each target's firmware is in asm/targets/<target>/marvin.asm
# Writes build/<name>.bin, .hex and .ihx; working files go in build/tmp/<name>/
#
# Requires: z88dk (z88dk-z80asm, z88dk-appmake), and the submodules:
#   git submodule update --init

set -e

# The welcome message includes the version
echo "defm \"$(cat docs/VERSION.txt)\"" > asm/core/version.inc

# BBC BASIC sources are generated from the upstream sources
if [ ! -f BBCZ80-repo/src/MAIN.asm ]; then
    (cd BBCZ80-repo && ./convert.sh)
fi

z88dk-z80asm -b -l -m -I. -Ira8875-z80-repo -Obuild/tmp/$1 -o$1.bin @manifests/$1.lst
mv build/tmp/$1/$1.bin build/
xxd build/$1.bin > build/$1.hex
z88dk-appmake +hex --org 0x0000 -b build/$1.bin -o build/$1.ihx
