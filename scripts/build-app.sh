#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
swift build -c "$configuration"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
app="build/SaveNest.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/SaveNest" "$app/Contents/MacOS/SaveNest"
cp Resources/Info.plist "$app/Contents/Info.plist"
swift scripts/make-icon.swift
cp build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
# Use a Developer ID identity for distribution; ad-hoc signing is for local use.
codesign --force --options runtime --entitlements Resources/SaveNest.entitlements --sign "${SIGNING_IDENTITY:--}" "$app"
codesign --verify --strict "$app"
echo "Built $PWD/$app"
