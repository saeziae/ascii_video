#/bin/bash
INPUT="$1"
OUTPUT="$2"
JP2A_OPT=()
# check ffmpeg and jp2a
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg could not be found. Please install it."
    exit 1
fi
if ! command -v jp2a &> /dev/null; then
    echo "jp2a could not be found. Please install it."
    exit 1
fi
function help {
    echo "Usage: ascii_video.sh <input_video_file> <output_file> [-f<fps>] [jp2a options]"
    echo "Example: ascii_video.sh input.mp4 output.sh -f10 --width=80 --height=24 --color-depth=8"
    exit 0
}
for i in "$@"; do
    case $i in
        -h|--help)
            help
        ;;
        -f*)
            FPS="${i#-f}"
            shift
        ;;
        --*)
            JP2A_OPT+=("$i")
            shift
        ;;
    esac
done

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ] || [ -z "$FPS" ] || [ -z "$JP2A_OPT" ]; then
    help
fi

tmp=$(mktemp -d)
mkdir -p ${tmp}/{jpg,txt}
trap "rm -rf ${tmp}" EXIT
ffmpeg -i "$INPUT" -vf fps=$FPS ${tmp}/jpg/out%05d.jpg
cat > "${OUTPUT}" <<'EOF'
#!/bin/bash
cleanup() {
    tput cnorm
}
trap cleanup EXIT
tput civis
tail -n +9 "${BASH_SOURCE[0]}" | gunzip -c | bash
exit 0
EOF

TMPSH=${tmp}/tmp.sh
INTERVAL=$((1000 / FPS))
INTERVAL=$(awk "BEGIN {print $INTERVAL/1000}") # float

for i in ${tmp}/jpg/*.jpg; do
    echo 'printf "\e[H"' >>"${TMPSH}"
    echo "cat <<EOF" >>"${TMPSH}"
    jp2a ${JP2A_OPT[@]} "$i" >>"${TMPSH}"
    echo "EOF" >>"${TMPSH}"
    echo "sleep $INTERVAL" >>"${TMPSH}"
done
gzip -c "${TMPSH}" >> "${OUTPUT}"
