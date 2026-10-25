#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -gt 0 ]]; then
  mkdir -p .build/Verification
  cp "$1" .build/Verification/activity.fit
fi
printf '[%s] Testing FIT and GPX decoding and route geometry\n' "$(date '+%H:%M:%S')"
xcodebuild test -project FITPreview.xcodeproj -scheme FITPreview \
  -destination 'platform=macOS' -derivedDataPath .build/DerivedData \
  -clonedSourcePackagesDirPath .build/SourcePackages
