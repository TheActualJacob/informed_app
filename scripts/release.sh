#!/bin/zsh
# Archive, upload to App Store Connect, wait for processing, set TestFlight notes.
#
#   scripts/release.sh [--notes "What to test…"] [--skip-archive]
#
# Auth uses the App Store Connect API key (see docs/RELEASE.md), so Xcode does
# not need to be signed in. Run it alone — archive + upload + simulators at once
# have pushed this Mac into memory pressure before.
set -o pipefail
cd "$(dirname "$0")/.." || exit 1

NOTES=""; SKIP_ARCHIVE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --notes) NOTES="$2"; shift 2 ;;
    --skip-archive) SKIP_ARCHIVE=1; shift ;;
    *) echo "unknown arg $1"; exit 2 ;;
  esac
done

KEY_ID="${ASC_KEY_ID:-32P8X6989C}"
ISSUER_ID="${ASC_ISSUER_ID:-9a14060e-f8f2-4beb-9b5e-951ad8dda6e2}"
KEY_PATH="${ASC_KEY_PATH:-$HOME/Documents/Personal/AuthKey_${KEY_ID}.p8}"
[ -f "$KEY_PATH" ] || { echo "ASC private key not found at $KEY_PATH (set ASC_KEY_PATH)"; exit 1; }

VERSION=$(grep -m1 'MARKETING_VERSION = ' informed.xcodeproj/project.pbxproj | sed -E 's/.*= ([0-9.]+);/\1/')
OUT="${RELEASE_OUT:-$HOME/Library/Developer/Xcode/Archives/informed-cli}"
# DerivedData must live OUTSIDE ~/Library/Developer/Xcode/Archives: at the end of an
# archive, xcodebuild recursively scans that whole folder for .xcarchive bundles and
# follows symlinks, and the RevenueCat SwiftPM checkout contains a symlink cycle —
# with DerivedData inside Archives the 1.1.6 archive spun at 100% CPU forever.
DERIVED="${RELEASE_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/informed-cli}"
mkdir -p "$OUT" "$DERIVED"
ARCHIVE="$OUT/informed-$VERSION.xcarchive"
echo "### version $VERSION → $ARCHIVE"

if [ $SKIP_ARCHIVE -eq 0 ]; then
  rm -rf "$ARCHIVE"
  xcodebuild -project informed.xcodeproj -scheme informed -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
    -derivedDataPath "$DERIVED" -allowProvisioningUpdates archive > "$OUT/archive-$VERSION.log" 2>&1 \
    || { echo "ARCHIVE FAILED — see $OUT/archive-$VERSION.log"; grep -E "error:" "$OUT/archive-$VERSION.log" | sort -u | head; exit 1; }
  echo "archive ok"
  plutil -p "$ARCHIVE/Products/Applications/informed.app/Info.plist" | grep -E 'CFBundleShortVersionString|CFBundleVersion"'
fi

rm -rf "$OUT/export-$VERSION"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist scripts/exportOptions.plist \
  -exportPath "$OUT/export-$VERSION" -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER_ID" \
  > "$OUT/upload-$VERSION.log" 2>&1 \
  || { echo "UPLOAD FAILED — see $OUT/upload-$VERSION.log"; grep -iE "error" "$OUT/upload-$VERSION.log" | sort -u | head; exit 1; }
grep -q "Upload succeeded" "$OUT/upload-$VERSION.log" && echo "upload ok"

PY="${PYTHON:-python3}"
[ -x .venv/bin/python ] && PY=.venv/bin/python
if [ -n "$NOTES" ]; then
  "$PY" scripts/asc_testflight.py wait --version "$VERSION" --notes "$NOTES"
else
  "$PY" scripts/asc_testflight.py wait --version "$VERSION"
fi
