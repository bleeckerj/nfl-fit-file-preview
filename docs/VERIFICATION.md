# Verification record

Verified October 1, 2026, on macOS 27.0.1 with Xcode 27 and Apple Swift 6.4.

- Native host app and embedded Quick Look extension built successfully.
- 23 tests passed, including compressed timestamps, CRC rejection, GPS gaps, summary semantics, cancellation, large recordings, and date-line polyline geometry.
- The real OMATA sample from FitFileMapMaker decoded 6,491 GPS points in approximately one second. The sample remains outside Git; the integration copy lives under ignored `.build/Verification`.
- The installed app at `~/Applications/FIT Preview.app` passed strict code-signature verification.
- The extension is registered and enabled in PlugInKit.
- Live Launch Services resolves `fit`, `FIT`, and the sample file's resource content type to `com.garmin.fit`. Spotlight's older cached metadata initially reported a dynamic identifier.
- A `qlmanage -p` request launched the installed FITQuickLook extension process; runtime logs showed its remote view hosted.
- Property lists, entitlements, shell syntax, documentation prose checks, and staged whitespace checks passed.

## GPX support verification — October 25, 2026

- The host app, extension, and test bundle built successfully with GPX support.
- All 38 tests passed, including 15 GPX tests and the existing real FIT integration sample with 6,491 GPS points.
- GPX tests cover tracks and routes, GPX 1.0 and 1.1 namespaces, uppercase file dispatch, track preference, segment boundaries, missing or invalid coordinates and timestamps, date-line distance, approximate distance formatting, elapsed duration, empty and waypoint-only files, malformed XML, external entity isolation, cancellation, the 100 MB limit, and 25,000 points.
- The updated app was installed at `/Users/julian/Applications/FIT Preview.app`; the previous build was backed up by the installer.
- Strict signature verification passed for the installed app and embedded extension. PlugInKit lists the updated extension as enabled.
- Live Launch Services resolves `fit` and `FIT` to `com.garmin.fit`, and `gpx` and `GPX` to `com.topografix.gpx`.
- The GPX Finder space-bar preview and visible map interactions have not been checked. The visual acceptance items below remain open for both formats.

## Rebuild verification — October 25, 2026

- `bash scripts/build.sh` completed successfully after the GPX and distribution changes.
- `bash scripts/test.sh` passed all 38 tests, including the real FIT integration sample and 15 GPX tests.
- The published `v1.0.0-preview.1` DMG uses the earlier FIT-only source revision `8217a7cc49f09671ac4514cf188a96f52209773f`. The next GPX-enabled package is `v1.0.0-preview.2`; its exact source revision and checksum accompany the download.
- Visible Finder preview behavior remains on the acceptance checklist below.

## Remaining visual acceptance

The desktop was initially locked. After it became available, concurrent Finder activity prevented completing a controlled Finder space-bar check. The separate CLI preview window also timed out in the accessibility tool. No rendered map screenshot was accepted as verification.

Map imagery, visible route framing and labels, marker placement, pan/zoom, Fit Route, window resizing, rapid file switching, and offline presentation still need hands-on checks in the installed extension. Automated decoding and geometry tests cover the underlying calculations, but they do not establish these visible behaviors.

This is a locally signed development build. Public distribution and independent verification on macOS 15 remain outside the completed checks.
