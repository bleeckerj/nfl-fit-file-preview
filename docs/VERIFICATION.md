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

## Remaining visual acceptance

The desktop was initially locked. After it became available, concurrent Finder activity prevented completing a controlled Finder space-bar check. The separate CLI preview window also timed out in the accessibility tool. No rendered map screenshot was accepted as verification.

Map imagery, visible route framing and labels, marker placement, pan/zoom, Fit Route, window resizing, rapid file switching, and offline presentation still need hands-on checks in the installed extension. Automated decoding and geometry tests cover the underlying calculations, but they do not establish these visible behaviors.

This is a locally signed development build. Public distribution and independent verification on macOS 15 remain outside the completed checks.
