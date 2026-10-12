#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
swift build -c "$configuration"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
source scripts/sparkle-common.sh
app="build/SaveNest.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/SaveNest" "$app/Contents/MacOS/SaveNest"
cp Resources/Info.plist "$app/Contents/Info.plist"
# Local builds do not replace themselves with a public release.
/usr/libexec/PlistBuddy -c 'Set :SaveNestUpdatesEnabled false' "$app/Contents/Info.plist"
swift scripts/make-icon.swift
cp build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
# Use a Developer ID identity for distribution; ad-hoc signing is for local use.
embed_sparkle "$app" "${SIGNING_IDENTITY:--}"
signing_options=(--force --entitlements Resources/SaveNest.entitlements --sign "${SIGNING_IDENTITY:--}")
# Ad-hoc local builds have no Team ID for hardened runtime library validation.
if [[ -n "${SIGNING_IDENTITY:-}" && "$SIGNING_IDENTITY" != "-" ]]; then signing_options+=(--options runtime --timestamp); fi
codesign "${signing_options[@]}" "$app"
codesign --verify --deep --strict "$app"
echo "Built $PWD/$app"
