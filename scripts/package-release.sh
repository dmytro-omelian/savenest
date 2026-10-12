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
source scripts/sparkle-common.sh
release_dir="$PWD/build/releases/updates"
if [[ -z "$identity" ]]; then release_dir="$PWD/build/releases/previews"; fi
mkdir -p "$release_dir"
archive="$release_dir/SaveNest-$version-macOS.zip"
if [[ -e "$archive" ]]; then
  echo "Release archive already exists: $archive. Use a new version and build number." >&2
  exit 1
fi
notes="$PWD/Resources/ReleaseNotes/$version.html"
if [[ -n "$identity" && ! -f "$notes" ]]; then
  echo "Add release notes at $notes before packaging a public update." >&2
  exit 1
fi
swift package resolve
if [[ -n "$identity" ]]; then
  check_sparkle_key
  # Fail before building if the notarization profile is missing or invalid.
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null
fi
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
if [[ -z "$identity" ]]; then
  /usr/libexec/PlistBuddy -c 'Set :SaveNestUpdatesEnabled false' "$app/Contents/Info.plist"
fi
swift scripts/make-icon.swift
cp build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
embed_sparkle "$app" "${identity:--}"
signing_options=(--force --entitlements Resources/SaveNest.entitlements --sign "${identity:--}")
if [[ -n "$identity" ]]; then signing_options+=(--options runtime --timestamp); fi
codesign "${signing_options[@]}" "$app"
codesign --verify --deep --strict "$app"

# Keep failed notarization attempts out of the public updates directory.
staged_archive="$stage/SaveNest-$version-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$staged_archive"
notarized=false
if [[ -n "$identity" ]]; then
  xcrun notarytool submit "$staged_archive" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose "$app"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$staged_archive"
  notarized=true
fi
mv "$staged_archive" "$archive"
if [[ "$notarized" == true ]]; then
  cp "$notes" "${archive%.zip}.html"
  feed_url=$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' Resources/Info.plist)
  "$sparkle_root/bin/generate_appcast" --account "$sparkle_account" \
    --download-url-prefix "${feed_url%/*}/" --link https://savenest.app \
    --maximum-deltas 0 --versions "$build_number" "$release_dir"
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
if [[ "$notarized" == true ]]; then
  echo "Upload the ZIP and release notes, then appcast.xml and release.json to https://savenest.app/downloads/."
  echo "Keep previous published archives available. The website's /download/macos redirect reads release.json."
else
  echo "Developer preview only. No update feed was generated."
fi
