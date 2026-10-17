#!/bin/bash
# Generate app icon PNGs from harbour-sailcat.svg.
# Sizes must match SAILFISHAPP_ICONS in harbour-sailcat.pro.
set -euo pipefail

cd "$(dirname "$0")/.."

SVG="harbour-sailcat.svg"
SIZES="86 108 128 172"

if [ ! -f "$SVG" ]; then
    echo "Error: $SVG not found in repository root" >&2
    exit 1
fi

for size in $SIZES; do
    out="icons/${size}x${size}/harbour-sailcat.png"
    mkdir -p "icons/${size}x${size}"

    if command -v rsvg-convert >/dev/null 2>&1; then
        rsvg-convert -w "$size" -h "$size" -o "$out" "$SVG"
    elif command -v inkscape >/dev/null 2>&1; then
        inkscape "$SVG" -w "$size" -h "$size" -o "$out"
    elif command -v magick >/dev/null 2>&1; then
        magick -background none -density 96 "$SVG" -resize "${size}x${size}" "$out"
    elif command -v convert >/dev/null 2>&1; then
        convert -background none -density 96 "$SVG" -resize "${size}x${size}" "$out"
    else
        echo "Error: need rsvg-convert, inkscape or ImageMagick" >&2
        exit 1
    fi

    echo "OK  $out"
done
