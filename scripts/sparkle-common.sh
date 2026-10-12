#!/bin/bash
# Source from build scripts after changing to the repository root.
sparkle_root="$PWD/.build/artifacts/sparkle/Sparkle"
sparkle_account="${SPARKLE_KEY_ACCOUNT:-app.savenest.mac}"

embed_sparkle() {
  local app_path="$1"
  local signing_identity="${2:--}"
  local framework="$app_path/Contents/Frameworks/Sparkle.framework"
  mkdir -p "$app_path/Contents/Frameworks"
  # ditto preserves the versioned framework symlinks and helper permissions.
  rm -rf "$framework"
  ditto "$sparkle_root/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" "$framework"
  local signing_options=(--force --sign "$signing_identity")
  if [[ "$signing_identity" != "-" ]]; then signing_options+=(--options runtime --timestamp); fi
  # Sign from the inside out, preserving Sparkle's helper entitlements.
  local component
  for component in \
    "$framework/Versions/B/XPCServices/Downloader.xpc" \
    "$framework/Versions/B/XPCServices/Installer.xpc" \
    "$framework/Versions/B/Autoupdate" \
    "$framework/Versions/B/Updater.app" \
    "$framework"; do
    codesign "${signing_options[@]}" --preserve-metadata=entitlements "$component"
  done
}

check_sparkle_key() {
  local expected actual
  expected=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' Resources/Info.plist)
  actual=$("$sparkle_root/bin/generate_keys" --account "$sparkle_account" -p)
  if [[ -z "$expected" || "$expected" != "$actual" ]]; then
    echo "The Sparkle signing key does not match SUPublicEDKey. Restore the release key before packaging." >&2
    return 1
  fi
}
