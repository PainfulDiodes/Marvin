# Burn EEPROM using David Griffiths minipro - for AT28C256 and AT28C64B devices
# usage: ./burn.sh [-m] [-8] target
# -m : burn minimal build (marvin monitor only, no BBC BASIC)
# -8 : use 8k EEPROM (AT28C64B) instead of 32k (AT28C256)

# set -x #echo on

minimal=false
device=AT28C256
while getopts "m8" opt; do
    case $opt in
        m) minimal=true ;;
        8) device=AT28C64B ;;
    esac
done
shift $((OPTIND - 1))

f=${1%.*} #extract base filename

if [ "$minimal" = true ]; then
    binary=build/${f}_minimal.bin
else
    binary=build/$f.bin
fi
echo "=== Binary: $binary"

# Pad binary to chip size with 0xFF before writing, so read-back comparison works
if [ "$device" = "AT28C64B" ]; then
    chipsize=8192
else
    chipsize=32768
fi
echo "=== Device: $device (${chipsize} bytes)"

padded=$(mktemp)
python3 -c "
data = open('$binary','rb').read()
padded = data.ljust($chipsize, b'\xff')
open('$padded','wb').write(padded)
print(f'=== Padded {len(data)} -> {len(padded)} bytes')
"

echo "=== Writing..."
minipro -u -s -p $device -w "$padded"

# Verify: read back and compare
echo "=== Reading back..."
tmpfile=$(mktemp)
minipro -p $device -r "$tmpfile"
echo "=== Comparing..."
if cmp -s "$padded" "$tmpfile"; then
    echo "=== Verify OK"
else
    echo "=== Verify FAILED"
    rm "$padded" "$tmpfile"
    exit 1
fi
rm "$padded" "$tmpfile"
