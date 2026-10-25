# Downloadable builds

The DMG packager builds an immutable Git commit, signs the app and disk image with the Developer ID configured in `Configuration/Distribution.xcconfig`, and verifies both Apple silicon and Intel executables. Signing credentials stay in the macOS keychain.

```sh
bash scripts/package-dmg.sh 1.0.0-preview.1 SOURCE_COMMIT
```

Use the full SHA of a commit already published on GitHub for a public release. The source snapshot lives under ignored `.build/DistributionSources`; the signed Release build uses `.build/DistributionDerivedData`. Concurrent edits to the working tree are excluded from the app being packaged.

The durable output folder is `releases/VERSION/`. It contains the DMG, installation instructions, `SourceRevision.txt`, and `SHA256SUMS.txt`. Existing DMGs are never overwritten. Keep the checksum file with the exact final DMG; regenerate it after any notarization stapling step.

Before publishing, run the source snapshot's test script, inspect the mounted disk image, and verify its app and extension signatures and architecture slices. Treat successful packaging separately from a clean installation on another Mac and visible Finder interaction checks.

## Notarization

Developer ID signing and Apple notarization are separate steps. Use an explicitly selected, existing `notarytool` keychain profile to submit the DMG to Apple. Record Apple's submission ID and accepted result, staple the ticket to the DMG, and validate it before describing the download as notarized. Without that result, label the release as a development prerelease that is Developer ID-signed and not notarized.

See [Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Route examples

`Tools/RouteExamples` renders a complete FIT route using the same decoder and summary formatter as the app. It writes a 1024 × 1280 PNG with Apple Maps attribution, route segments, start and finish markers, and the source filename and summary.

```sh
bash scripts/export-route-example.sh INPUT.fit OUTPUT.png
```

Rendering requests geographic imagery from Apple Maps. Obtain authorization for that destination before using private activity files. The following inspection mode decodes the file locally and exits before requesting any map imagery:

```sh
bash scripts/export-route-example.sh --inspect INPUT.fit
```

The output image belongs in Photarium with its source-file hash and rendering provenance.
