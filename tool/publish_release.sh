#!/bin/bash
# Builds the signed release APK and publishes it as GitHub release
# v<pubspec version> (e.g. v1.1.0+2) - tablets with HA Display install it
# on their next update check. Bump `version:` in pubspec.yaml first; the
# number after "+" must grow with every release.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
tag="v$version"
if gh release view "$tag" >/dev/null 2>&1; then
  echo "Release $tag exists already - bump the version in pubspec.yaml." >&2
  exit 1
fi
if [ ! -f android/key.properties ]; then
  echo "android/key.properties missing - the APK would be signed with the debug key." >&2
  exit 1
fi

# Only ARM: stock Android on the SM-T585 is 32-bit, LineageOS 64-bit. Without
# x86 the APK is much smaller - the tablets download it over Wi-Fi.
flutter build apk --release --target-platform android-arm,android-arm64
cp build/app/outputs/flutter-apk/app-release.apk build/PhotoFrame.apk
gh release create "$tag" build/PhotoFrame.apk --title "$tag" --generate-notes
