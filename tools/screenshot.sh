#!/usr/bin/env bash
# Скриншот экрана виртуальной машины без графического окна:
# грузим образ, ждём загрузку, просим монитор QEMU отдать дамп экрана
# и конвертируем .ppm в .png (ffmpeg).
#
#   ./tools/screenshot.sh build/boot.img screenshots/boot.png [задержка] [floppy|hd]

set -eu

img=${1:?usage: screenshot.sh <image> <png> [delay] [floppy|hd]}
png=${2:?usage: screenshot.sh <image> <png> [delay] [floppy|hd]}
delay=${3:-4}
mode=${4:-floppy}

case $mode in
	floppy) drive="if=floppy"; boot="-boot a" ;;
	hd)     drive="if=ide";    boot="-boot c" ;;
	*)      echo "unknown mode: $mode" >&2; exit 1 ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$(dirname "$png")"

( sleep "$delay"; printf 'screendump %s\nquit\n' "$tmp/shot.ppm" ) |
	qemu-system-i386 -drive file="$img",format=raw,$drive $boot \
		-m 32 -display none -monitor stdio >/dev/null 2>&1 || true

ffmpeg -loglevel error -y -i "$tmp/shot.ppm" "$png"
echo "saved $png"
