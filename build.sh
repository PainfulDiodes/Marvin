#!/usr/bin/env bash

# Build Marvin firmware
# Usage: ./build.sh [target]
# Examples:
#   ./build.sh              # build all targets
#   ./build.sh beanzee      # build beanzee only
#
# Each target produces two builds:
#   marvin.bin     - combined firmware (Marvin + BBC BASIC)
#   marvin_minimal.bin - minimal firmware (Marvin monitor only)
#
# Requires: z88dk (z88dk-z80asm, z88dk-appmake)

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MARVIN_ASM="$REPO_DIR/asm"
RA8875_DIR="$REPO_DIR/ra8875-z80-repo"
BASIC_SRC="$REPO_DIR/BBCZ80-repo/src"
BBCZ80_DIR="$REPO_DIR/asm/BBCZ80"

CODE_ORG="0x0000"
DATA_ORG="0x8000"
OUTPUT_NAME="marvin"
MINIMAL_NAME="marvin_minimal"

BASIC_MODULES="EXEC EVAL ASMB MATH DATA"

# Object file name for a module path: keeps names unique across folders
obj_name() {
    echo "${1//\//_}"
}

# ---- Per-target module lists ----
# Used by both combined and minimal builds.
# Non-RA8875 module paths are relative to $MARVIN_ASM.

modules_for_target() {
    case $1 in
        beanzee)
            COMBINED_ENTRY="targets/beanzee/entry"
            MARVIN_MODULES="core/system targets/beanzee/console drivers/um245r core/monitor core/hex core/messages"
            RA8875_MODULES=""
            LCD_MODULES=""
            BASIC_MAIN="MAIN"
            MINIMAL_ENTRY="targets/beanzee/entry_minimal"
            MINIMAL_MODULES="core/system targets/beanzee/console drivers/um245r core/monitor core/hex core/messages"
            MINIMAL_RA8875_MODULES=""
            MINIMAL_LCD_MODULES=""
            ;;
        beanboard)
            COMBINED_ENTRY="targets/beanboard/entry"
            MARVIN_MODULES="core/system targets/beanboard/console core/console_select drivers/um245r drivers/hd44780 drivers/keymatrix core/monitor core/hex targets/beanboard/messages"
            RA8875_MODULES=""
            LCD_MODULES="1"
            BASIC_MAIN="MAIN_SM_DSP"
            MINIMAL_ENTRY="targets/beanboard/entry_minimal"
            MINIMAL_MODULES="core/system targets/beanboard/console core/console_select drivers/um245r drivers/hd44780 drivers/keymatrix core/monitor core/hex targets/beanboard/messages"
            MINIMAL_RA8875_MODULES=""
            MINIMAL_LCD_MODULES="1"
            ;;
        beandeck)
            COMBINED_ENTRY="targets/beandeck/entry"
            MARVIN_MODULES="core/system targets/beandeck/console core/console_select drivers/um245r drivers/keymatrix core/monitor core/hex core/messages"
            RA8875_MODULES="asm/ra8875 asm/console targets/beanboardspi"
            LCD_MODULES=""
            BASIC_MAIN="MAIN"
            MINIMAL_ENTRY="targets/beandeck/entry_minimal"
            MINIMAL_MODULES="core/system targets/beandeck/console core/console_select drivers/um245r drivers/keymatrix core/monitor core/hex core/messages"
            MINIMAL_RA8875_MODULES="asm/ra8875 asm/console targets/beanboardspi"
            MINIMAL_LCD_MODULES=""
            ;;
        *)
            echo "Error: unknown target '$1'"
            echo "Valid targets: beanzee, beanboard, beandeck"
            exit 1
            ;;
    esac
}

# ---- Build combined firmware (Marvin + BBC BASIC) ----

build_target() {
    local target=$1
    local OUTDIR="$REPO_DIR/build/tmp/$target"
    local IMAGE="$REPO_DIR/build/$target"

    modules_for_target "$target"

    echo "Building Marvin ($target)"
    echo "==========================="

    mkdir -p "$OUTDIR"
    rm -f "$OUTDIR"/*.o "$OUTDIR"/*.lis

    # ---- Boot module ----

    echo ""
    echo "Assembling boot module..."
    echo "  $COMBINED_ENTRY.asm"
    z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/$(obj_name $COMBINED_ENTRY).o" "$MARVIN_ASM/$COMBINED_ENTRY.asm"

    # ---- Marvin modules ----

    RA8875_FLAG=""
    [ -n "$RA8875_MODULES" ] && RA8875_FLAG="-DHAS_RA8875"
    LCD_FLAG=""
    [ -n "$LCD_MODULES" ] && LCD_FLAG="-DHAS_LCD"

    echo ""
    echo "Assembling Marvin modules..."
    for module in $MARVIN_MODULES; do
        local obj=$(obj_name "$module")
        echo "  $module.asm"
        z88dk-z80asm -l -m -DINCLUDE_BASIC $RA8875_FLAG $LCD_FLAG -I"$REPO_DIR" -I"$RA8875_DIR" \
            -o"$OUTDIR/$obj.o" "$MARVIN_ASM/$module.asm"
    done

    if [ -n "$RA8875_MODULES" ]; then
        echo ""
        echo "Assembling RA8875 modules..."
        for module in $RA8875_MODULES; do
            local obj=$(obj_name "$module")
            echo "  $module.asm"
            z88dk-z80asm -l -m -I"$RA8875_DIR" \
                -o"$OUTDIR/$obj.o" "$RA8875_DIR/$module.asm"
        done
    fi

    # ---- BBC BASIC core modules ----

    echo ""
    echo "Assembling BBC BASIC modules..."
    echo "  $BASIC_MAIN.asm"
    z88dk-z80asm -l -m -o"$OUTDIR/$BASIC_MAIN.o" "$BASIC_SRC/$BASIC_MAIN.asm"
    for module in $BASIC_MODULES; do
        EXTRA_FLAGS=""
        if [ "$module" = "DATA" ]; then
            EXTRA_FLAGS="-DDATA_ORG=$DATA_ORG"
        fi
        echo "  $module.asm"
        z88dk-z80asm -l -m $EXTRA_FLAGS -o"$OUTDIR/$module.o" "$BASIC_SRC/$module.asm"
    done

    echo "  HOOK.asm"
    z88dk-z80asm -l -m -o"$OUTDIR/HOOK.o" "$BBCZ80_DIR/HOOK.asm"

    echo "  MOS.asm"
    z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/MOS.o" "$BBCZ80_DIR/MOS.asm"

    # ---- Shared BBC BASIC entry point ----

    echo ""
    echo "Assembling BBC BASIC entry point..."
    echo "  ENTRY.asm"
    z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/ENTRY.o" "$BBCZ80_DIR/ENTRY.asm"

    # ---- Link ----
    # Boot module must be first (contains ORG 0x0000 and jump table)

    ALL_OBJS="$OUTDIR/$(obj_name $COMBINED_ENTRY).o $OUTDIR/ENTRY.o"
    for module in $MARVIN_MODULES; do
        ALL_OBJS="$ALL_OBJS $OUTDIR/$(obj_name $module).o"
    done
    for module in $RA8875_MODULES; do
        ALL_OBJS="$ALL_OBJS $OUTDIR/$(obj_name $module).o"
    done
    ALL_OBJS="$ALL_OBJS $OUTDIR/$BASIC_MAIN.o"
    for module in $BASIC_MODULES; do
        ALL_OBJS="$ALL_OBJS $OUTDIR/$module.o"
    done
    ALL_OBJS="$ALL_OBJS $OUTDIR/HOOK.o"
    ALL_OBJS="$ALL_OBJS $OUTDIR/MOS.o"

    echo ""
    echo "Linking all modules at $CODE_ORG..."
    z88dk-z80asm -b -m \
        -o"$OUTDIR/$OUTPUT_NAME.bin" \
        -r$CODE_ORG \
        $ALL_OBJS

    # Remove DATA section binary - it lives in RAM, not ROM
    rm -f "$OUTDIR/${OUTPUT_NAME}_data.bin"

    mv "$OUTDIR/$OUTPUT_NAME.bin" "$IMAGE.bin"
    BIN_SIZE=$(wc -c < "$IMAGE.bin" | tr -d ' ')

    xxd "$IMAGE.bin" > "$IMAGE.hex"
    z88dk-appmake +hex --org $CODE_ORG \
        -b "$IMAGE.bin" \
        -o "$IMAGE.ihx"

    echo ""
    echo "Build complete:"
    echo "  ROM image:   build/$target.bin ($BIN_SIZE bytes at $CODE_ORG)"
    echo "  Hex dump:    build/$target.hex"
    echo "  Intel HEX:   build/$target.ihx"
    echo "  Map file:    build/tmp/$target/$OUTPUT_NAME.map"
    echo ""
    echo "Memory layout:"
    echo "  ROM: $CODE_ORG - code ($BIN_SIZE bytes)"
    echo "  RAM: $DATA_ORG - data segment (initialised at runtime)"
}

# ---- Build minimal firmware (Marvin monitor only, no BBC BASIC) ----

build_minimal() {
    local target=$1
    local OUTDIR="$REPO_DIR/build/tmp/$target"
    local IMAGE="$REPO_DIR/build/${target}_minimal"

    modules_for_target "$target"

    echo "Building Marvin minimal ($target)"
    echo "==========================="

    mkdir -p "$OUTDIR"

    # ---- Entry module ----

    echo ""
    echo "Assembling entry module..."
    echo "  $MINIMAL_ENTRY.asm"
    z88dk-z80asm -l -m -DMARVINORG=$CODE_ORG -I"$REPO_DIR" \
        -o"$OUTDIR/$(obj_name $MINIMAL_ENTRY).o" "$MARVIN_ASM/$MINIMAL_ENTRY.asm"

    # ---- Marvin and driver modules ----

    RA8875_FLAG=""
    [ -n "$MINIMAL_RA8875_MODULES" ] && RA8875_FLAG="-DHAS_RA8875"
    LCD_FLAG=""
    [ -n "$MINIMAL_LCD_MODULES" ] && LCD_FLAG="-DHAS_LCD"

    echo ""
    echo "Assembling modules..."
    for module in $MINIMAL_MODULES; do
        local obj=$(obj_name "$module")
        echo "  $module.asm"
        z88dk-z80asm -l -m $RA8875_FLAG $LCD_FLAG -I"$REPO_DIR" -I"$RA8875_DIR" -o"$OUTDIR/$obj.o" "$MARVIN_ASM/$module.asm"
    done

    if [ -n "$MINIMAL_RA8875_MODULES" ]; then
        echo ""
        echo "Assembling RA8875 modules..."
        for module in $MINIMAL_RA8875_MODULES; do
            local obj=$(obj_name "$module")
            echo "  $module.asm"
            z88dk-z80asm -l -m -I"$RA8875_DIR" \
                -o"$OUTDIR/$obj.o" "$RA8875_DIR/$module.asm"
        done
    fi

    # ---- Link ----
    # Entry module must be first (contains ORG and jump table)
    # Link order: entry, MINIMAL_MODULES, MINIMAL_RA8875_MODULES

    ALL_OBJS="$OUTDIR/$(obj_name $MINIMAL_ENTRY).o"
    for module in $MINIMAL_MODULES; do
        local obj=$(obj_name "$module")
        ALL_OBJS="$ALL_OBJS $OUTDIR/$obj.o"
    done
    for module in $MINIMAL_RA8875_MODULES; do
        ALL_OBJS="$ALL_OBJS $OUTDIR/$(obj_name $module).o"
    done
    echo ""
    echo "Linking minimal modules at $CODE_ORG..."
    z88dk-z80asm -b -m \
        -o"$OUTDIR/$MINIMAL_NAME.bin" \
        -r$CODE_ORG \
        $ALL_OBJS

    mv "$OUTDIR/$MINIMAL_NAME.bin" "$IMAGE.bin"
    BIN_SIZE=$(wc -c < "$IMAGE.bin" | tr -d ' ')

    xxd "$IMAGE.bin" > "$IMAGE.hex"
    z88dk-appmake +hex --org $CODE_ORG \
        -b "$IMAGE.bin" \
        -o "$IMAGE.ihx"

    echo ""
    echo "Minimal build complete:"
    echo "  ROM image:   build/${target}_minimal.bin ($BIN_SIZE bytes at $CODE_ORG)"
    echo "  Hex dump:    build/${target}_minimal.hex"
    echo "  Intel HEX:   build/${target}_minimal.ihx"
    echo "  Map file:    build/tmp/$target/$MINIMAL_NAME.map"
}

# ---- Main ----

# Check submodules are initialised
if [ ! -f "$REPO_DIR/BBCZ80-repo/build.sh" ]; then
    echo "Error: BBCZ80 submodule not initialised."
    echo "Run: git submodule update --init"
    exit 1
fi

if [ ! -f "$RA8875_DIR/asm/ra8875.asm" ]; then
    echo "Error: ra8875 submodule not initialised."
    echo "Run: git submodule update --init"
    exit 1
fi

# Convert BBC BASIC sources if not already done
if [ ! -f "$BASIC_SRC/MAIN.asm" ]; then
    echo "=== Converting BBC BASIC sources ==="
    cd "$REPO_DIR/BBCZ80-repo"
    ./convert.sh
    cd "$REPO_DIR"
    echo ""
fi

if [ $# -gt 0 ]; then
    build_target "$1"
    echo ""
    build_minimal "$1"
else
    for target in beanzee beanboard beandeck; do
        build_target "$target"
        echo ""
        build_minimal "$target"
        echo ""
    done
fi
