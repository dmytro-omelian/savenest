#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Public releases must be signed and notarized. ALLOW_ADHOC=1 builds a labelled
# developer preview for sandbox testing without changing macOS security settings.
identity="${SIGNING_IDENTITY:-}"
if [[ -z "$identity" && "${ALLOW_ADHOC:-0}" != "1" ]]; then
  echo "Set SIGNING_IDENTITY and NOTARY_PROFILE for distribution, or ALLOW_ADHOC=1 for a developer preview." >&2
  exit 1
fi
if [[ -n "$identity" && -z "${NOTARY_PROFILE:-}" ]]; then
  echo "Set NOTARY_PROFILE to a Keychain profile configured with xcrun notarytool store-credentials." >&2
  exit 1
fi

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
build_number=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)
release_dir="$PWD/build/releases"
mkdir -p "$release_dir"
stage=$(mktemp -d "$release_dir/stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
app="$stage/SaveNest.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

for architecture in arm64 x86_64; do
  swift build -c release --product SaveNest --triple "${architecture}-apple-macosx14.0"
  binary_dir=$(swift build -c release --triple "${architecture}-apple-macosx14.0" --show-bin-path)
  cp "$binary_dir/SaveNest" "$stage/SaveNest-$architecture"
done
lipo -create "$stage/SaveNest-arm64" "$stage/SaveNest-x86_64" -output "$app/Contents/MacOS/SaveNest"
cp Resources/Info.plist "$app/Contents/Info.plist"
swift scripts/make-icon.swift
cp build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --options runtime --entitlements Resources/SaveNest.entitlements --sign "${identity:--}" "$app"
codesign --verify --strict "$app"

archive="$release_dir/SaveNest-$version-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
notarized=false
if [[ -n "$identity" ]]; then
  xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose "$app"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
  notarized=true
fi
checksum=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
cat > "$release_dir/release.json" <<EOF
{
  "version": "$version",
  "build": "$build_number",
  "file": "SaveNest-$version-macOS.zip",
  "architectures": ["arm64", "x86_64"],
  "minimumMacOS": "14.0",
  "notarized": $notarized,
  "sha256": "$checksum"
}
EOF
echo "Packaged $archive"
echo "SHA-256: $checksum"
