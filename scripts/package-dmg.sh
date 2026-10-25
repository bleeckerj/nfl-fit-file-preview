#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:-1.0.0-preview.1}"
source_ref="${2:-HEAD}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$ ]]; then
  printf 'Use a semantic release version, for example 1.0.0-preview.1.\n' >&2
  exit 2
fi
release_dir="$PWD/releases/$version"
artifact="FIT-Preview-$version-universal.dmg"
source_commit=$(git rev-parse --verify "$source_ref^{commit}")
source_root="$PWD/.build/DistributionSources/$source_commit"
if [[ ! -d "$source_root" ]]; then
  mkdir -p "$PWD/.build/DistributionSources"
  source_staging=$(mktemp -d "$PWD/.build/dist-source.XXXXXX")
  git archive "$source_commit" | tar -x -C "$source_staging"
  mv "$source_staging" "$source_root"
fi
mkdir -p "$release_dir"
if [[ -e "$release_dir/$artifact" ]]; then
  printf 'Release artifact already exists: %s\n' "$release_dir/$artifact" >&2
  exit 1
fi
printf '[%s] Building universal Release app\n' "$(date '+%H:%M:%S')"
xcodebuild build -project "$source_root/FITPreview.xcodeproj" -scheme FITPreview -configuration Release \
  -xcconfig "$PWD/Configuration/Distribution.xcconfig" \
  -destination 'generic/platform=macOS' -derivedDataPath .build/DistributionDerivedData \
  -clonedSourcePackagesDirPath "$PWD/.build/SourcePackages"
source_app="$PWD/.build/DistributionDerivedData/Build/Products/Release/FIT Preview.app"
codesign --verify --deep --strict "$source_app"
for binary in "$source_app/Contents/MacOS/FIT Preview" "$source_app/Contents/PlugIns/FITQuickLook.appex/Contents/MacOS/FITQuickLook"; do
  architectures=$(xcrun lipo -archs "$binary")
  if [[ " $architectures " != *' arm64 '* || " $architectures " != *' x86_64 '* ]]; then
    printf 'Missing universal architecture: %s (%s)\n' "$binary" "$architectures" >&2
    exit 1
  fi
  printf 'Verified architectures: %s\n' "$architectures"
done
staging=$(mktemp -d "$PWD/.build/dmg-stage.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$source_app" "$staging/FIT Preview.app"
ln -s /Applications "$staging/Applications"
cp docs/INSTALL-DOWNLOAD.txt "$staging/Installation.txt"
printf '[%s] Creating %s\n' "$(date '+%H:%M:%S')" "$artifact"
hdiutil create -volname 'FIT Preview' -srcfolder "$staging" -format UDZO "$release_dir/$artifact"
identity=$(sed -n 's/^CODE_SIGN_IDENTITY = //p' Configuration/Distribution.xcconfig)
codesign --sign "$identity" --timestamp "$release_dir/$artifact"
codesign --verify --strict "$release_dir/$artifact"
hdiutil verify "$release_dir/$artifact"
cp docs/INSTALL-DOWNLOAD.txt "$release_dir/Installation.txt"
printf '%s\n' "$source_commit" > "$release_dir/SourceRevision.txt"
(cd "$release_dir" && shasum -a 256 "$artifact" > SHA256SUMS.txt)
printf '[%s] Verified package: %s/%s\n' "$(date '+%H:%M:%S')" "$release_dir" "$artifact"
