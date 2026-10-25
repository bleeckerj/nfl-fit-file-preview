#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# != 2 ]]; then
  printf 'Usage: bash scripts/export-route-example.sh INPUT.fit OUTPUT.png\n' >&2
  exit 2
fi
products="$PWD/.build/DerivedData/Build/Products/Debug"
if [[ ! -f "$products/FITSwiftSDK.o" ]]; then
  bash scripts/build.sh
fi
mkdir -p .build/Tools
printf '[%s] Building native route snapshot exporter\n' "$(date '+%H:%M:%S')"
xcrun swiftc -target "$(uname -m)-apple-macosx15.0" -I "$products" -module-cache-path .build/ModuleCache \
  Sources/Core/*.swift Sources/Preview/SummaryFormatter.swift Tools/RouteExamples/*.swift \
  "$products/FITSwiftSDK.o" "$products/OrderedCollections.o" "$products/InternalCollectionsUtilities.o" \
  -o .build/Tools/export-route-example
.build/Tools/export-route-example "$1" "$2"
