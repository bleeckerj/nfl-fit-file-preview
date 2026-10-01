#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
printf '[%s] Building FIT Preview\n' "$(date '+%H:%M:%S')"
xcodebuild build -project FITPreview.xcodeproj -scheme FITPreview \
  -destination 'platform=macOS' -derivedDataPath .build/DerivedData \
  -clonedSourcePackagesDirPath .build/SourcePackages
printf '[%s] App: %s/.build/DerivedData/Build/Products/Debug/FIT Preview.app\n' "$(date '+%H:%M:%S')" "$PWD"
