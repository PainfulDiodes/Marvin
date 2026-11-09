#!/usr/bin/env bash

# Clean all target build outputs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for target in beanzee beanboard beandeck; do
    outdir="$SCRIPT_DIR/build/$target"
    if [ -d "$outdir" ]; then
        echo "Cleaning $target"
        rm -rf "$outdir"
    fi
done

# Clean assembler listing files and generated includes
rm -f "$SCRIPT_DIR"/asm/core/*.lis "$SCRIPT_DIR"/asm/bdfs/*.lis "$SCRIPT_DIR"/asm/targets/*/*.lis
rm -f "$SCRIPT_DIR"/asm/core/version.inc
rm -f "$SCRIPT_DIR"/asm/drivers/*.lis
rm -f "$SCRIPT_DIR"/asm/BBCZ80/*.lis
