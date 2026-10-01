#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_app="$PWD/.build/DerivedData/Build/Products/Debug/FIT Preview.app"
target_app="$HOME/Applications/FIT Preview.app"
if [[ ! -d "$source_app" ]]; then
  printf 'Build first with bash scripts/build.sh\n' >&2
  exit 1
fi
if [[ -e "$target_app" ]]; then
  if [[ "${1:-}" != '--update' ]]; then
    printf 'An app already exists at %s. Use --update to back up and replace FIT Preview.\n' "$target_app" >&2
    exit 1
  fi
  current_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$target_app/Contents/Info.plist")
  if [[ "$current_id" != 'com.nearfuturelaboratory.fitpreview' ]]; then
    printf 'The existing app has a different bundle identifier; installation stopped.\n' >&2
    exit 1
  fi
fi
codesign --verify --deep --strict "$source_app"
mkdir -p "$HOME/Applications"
staging=$(mktemp -d "$HOME/Applications/.fit-preview-install.XXXXXX")
ditto "$source_app" "$staging/FIT Preview.app"
codesign --verify --deep --strict "$staging/FIT Preview.app"
if [[ -e "$target_app" ]]; then
  mkdir -p .build/PreviousInstalls
  backup=$(mktemp -d "$PWD/.build/PreviousInstalls/install.XXXXXX")
  mv "$target_app" "$backup/FIT Preview.app"
  printf 'Previous build saved at %s/FIT Preview.app\n' "$backup"
fi
mv "$staging/FIT Preview.app" "$target_app"
rmdir "$staging"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$target_app"
pluginkit -a "$target_app/Contents/PlugIns/FITQuickLook.appex"
pluginkit -e use -i com.nearfuturelaboratory.fitpreview.quicklook
printf '[%s] Installed %s\nSelect a FIT file in Finder and press the space bar.\n' "$(date '+%H:%M:%S')" "$target_app"
