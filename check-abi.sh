#!/usr/bin/env bash
# check-abi.sh - Verify Marvin ABI trampoline functions in built binaries
#
# Run after ./build.sh to verify the ABI contract is intact.
# Checks that each trampoline entry has a JP instruction (0xC3) at its
# fixed ROM address, with a valid target in ROM (0x0001-0x7FFF).
#
# Exit 0 = all pass, exit 1 = one or more failures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ABI entries: "SYMBOL ADDRESS" — must match abi/marvin.inc
ABI_ENTRIES=(
    "MARVIN_WARMSTART                        0x0040"
    "MARVIN_PUTCHAR                          0x0043"
    "MARVIN_PUTCHAR_HEX                      0x0046"
    "MARVIN_PUTS                             0x0049"
    "MARVIN_GETCHAR                          0x004C"
    "MARVIN_READCHAR                         0x004F"
    "MARVIN_USB_PUTCHAR                      0x0052"
    "MARVIN_USB_PUTS                         0x0055"
    "MARVIN_USB_READCHAR                     0x0058"
    "MARVIN_LCD_INIT                         0x005B"
    "MARVIN_LCD_PUTCHAR                      0x005E"
    "MARVIN_LCD_PUTS                         0x0061"
    "MARVIN_KEY_READCHAR                     0x0064"
    "MARVIN_KEY_MODIFIERS                    0x0067"
    "MARVIN_RA8875_INIT                      0x006A"
    "MARVIN_RA8875_PUTCHAR                   0x006D"
    "MARVIN_RA8875_PUTS                      0x0070"
    "MARVIN_RA8875_CONSOLE_INIT              0x0073"
    "MARVIN_RA8875_CONSOLE_PUTCHAR           0x0076"
    "MARVIN_RA8875_CONSOLE_CURSOR_X          0x0079"
    "MARVIN_RA8875_CONSOLE_CURSOR_Y          0x007C"
    "MARVIN_RA8875_CONSOLE_SET_CURSOR_COLOUR 0x007F"
    "MARVIN_RA8875_CONSOLE_SET_BG_COLOUR     0x0082"
    "MARVIN_RA8875_CONSOLE_CURSOR_HIDE       0x0085"
    "MARVIN_RA8875_CONSOLE_CURSOR_SHOW       0x0088"
)

TOTAL_PASS=0
TOTAL_FAIL=0

check_binary() {
    local label="$1"
    local binary="$2"

    if [[ ! -f "$binary" ]]; then
        echo "  SKIP  $label (not found)"
        return
    fi

    local errors=0
    for entry in "${ABI_ENTRIES[@]}"; do
        local symbol addr_hex addr bytes opcode target_lo target_hi target
        symbol=$(awk '{print $1}' <<< "$entry")
        addr_hex=$(awk '{print $2}' <<< "$entry")
        addr=$(( addr_hex ))

        # Read 3 bytes at the ABI address: opcode + 16-bit target (little-endian)
        bytes=$(xxd -s "$addr" -l 3 -p "$binary")

        opcode=$(( 16#${bytes:0:2} ))
        target_lo=$(( 16#${bytes:2:2} ))
        target_hi=$(( 16#${bytes:4:2} ))
        target=$(( (target_hi << 8) | target_lo ))

        if [[ $opcode -ne 0xC3 ]]; then
            printf "  FAIL  %-44s @ %s: expected JP (0xC3), got 0x%s\n" \
                "$symbol" "$addr_hex" "${bytes:0:2}"
            (( errors++ )) || true
        elif [[ $target -eq 0 || $target -ge 0x8000 ]]; then
            printf "  FAIL  %-44s @ %s: JP target 0x%04X outside ROM\n" \
                "$symbol" "$addr_hex" "$target"
            (( errors++ )) || true
        fi
    done

    if [[ $errors -eq 0 ]]; then
        echo "  PASS  $label"
        (( TOTAL_PASS++ )) || true
    else
        echo "  FAIL  $label ($errors error(s))"
        (( TOTAL_FAIL++ )) || true
    fi
}

echo "Marvin ABI check"
echo "================"
echo ""

for target in beanzee beanboard beandeck; do
    check_binary "$target (combined)" "$SCRIPT_DIR/build/$target.bin"
    check_binary "$target (minimal)"  "$SCRIPT_DIR/build/${target}_minimal.bin"
done

echo ""
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"

[[ $TOTAL_FAIL -eq 0 ]]
