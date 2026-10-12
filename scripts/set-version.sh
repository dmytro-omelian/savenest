#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:-}"
build_number="${2:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$build_number" =~ ^[1-9][0-9]{0,8}$ ]]; then
  echo "Usage: $0 VERSION BUILD (for example: $0 0.9.4 27)" >&2
  exit 1
fi
current_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)
if (( build_number <= current_build )); then
  echo "Build must be greater than $current_build. Sparkle compares build numbers." >&2
  exit 1
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" Resources/Info.plist
echo "SaveNest $version ($build_number). Add Resources/ReleaseNotes/$version.html before packaging."
