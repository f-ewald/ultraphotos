#!/bin/bash
set -euo pipefail

# Generate all macOS app icon PNGs from the master SVG using rsvg-convert.
# Requires: librsvg (brew install librsvg)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON_DIR="$SCRIPT_DIR/../ultraphotos/Assets.xcassets/AppIcon.appiconset"
SVG="$SCRIPT_DIR/AppIcon.svg"

if [ ! -f "$SVG" ]; then
  echo "Error: $SVG not found" >&2
  exit 1
fi

if ! command -v rsvg-convert &>/dev/null; then
  echo "Error: rsvg-convert not found. Install with: brew install librsvg" >&2
  exit 1
fi

# Format: "point_size scale pixel_size"
SIZES=(
  "16 1 16"
  "16 2 32"
  "32 1 32"
  "32 2 64"
  "128 1 128"
  "128 2 256"
  "256 1 256"
  "256 2 512"
  "512 1 512"
  "512 2 1024"
)

for entry in "${SIZES[@]}"; do
  read -r pt scale px <<< "$entry"
  out="$ICON_DIR/AppIcon-${pt}x${pt}@${scale}x.png"
  echo "Generating ${pt}x${pt}@${scale}x (${px}px)..."
  rsvg-convert -w "$px" -h "$px" "$SVG" -o "$out"
  # Assign sRGB color profile for Xcode asset catalog compatibility
  sips -m "/System/Library/ColorSync/Profiles/sRGB Profile.icc" "$out" --out "$out" >/dev/null 2>&1
done

echo "Done. Generated ${#SIZES[@]} icon files."
