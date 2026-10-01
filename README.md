# FIT Preview

A native macOS Quick Look extension for FIT activity and course files. Select a `.fit` file in Finder and press the space bar to see its route on a labeled, interactive Apple Maps map.

The preview fits the complete route, marks the start and finish, and shows recorded date, distance, and activity time when available. GPS gaps, timer stops, and session boundaries remain separate. Files without GPS show an explanatory message and any available summary.

## Build and install

Requires macOS 15 or later and Xcode with Swift 6 package support. Open `FITPreview.xcodeproj` or run:

```sh
bash scripts/build.sh
bash scripts/install.sh
```

The installer puts the app in `~/Applications`, registers the embedded extension, and enables it for the current user. It refuses to overwrite an existing app. After rebuilding, use `bash scripts/install.sh --update` to save the previous FIT Preview build under `.build/PreviousInstalls` and install the new one. Keep the app installed; it contains the extension Finder uses. The host app provides setup guidance.

If Finder shows a generic file preview, check System Settings → General → Login Items & Extensions → Quick Look and enable **FIT Route Preview**. Close the preview and reopen it after enabling. Inspect registration with:

```sh
pluginkit -m -v -i com.nearfuturelaboratory.fitpreview.quicklook
mdls -name kMDItemContentType /path/to/activity.fit
```

The imported file type is `com.garmin.fit`. Files associated with another application's unrelated FIT identifier may require a matching supported-type declaration.

## Verification

```sh
bash scripts/test.sh
bash scripts/test.sh /path/to/real-recording.fit
```

The second command copies the recording into the ignored `.build/Verification` folder for a local integration test. No activity recording is committed. Tests cover binary decoding, CRC failures, malformed definitions, compressed timestamps, byte order, GPS gaps, session totals, pause gaps, date-line bounds, cancellation, and a 25,000-point recording.

For visual acceptance, select a real recording in Finder and press space. Check geographic labels, route framing, markers, summary, pan/zoom, Fit Route, window resizing, and switching between files. Repeat with an indoor activity and an invalid file. Test unavailable map imagery separately from FIT decoding.

## Architecture and data

- `Sources/Core`: FIT decoding, timestamp expansion, summary model, and route bounds.
- `Sources/Preview`: AppKit presentation and MapKit rendering.
- `Sources/Extension`: asynchronous Quick Look request lifecycle.
- `Sources/App`: setup window and extension guidance.

Garmin's official FIT Swift SDK is pinned to 21.217.0. That version rejects compressed timestamp headers, so a focused preprocessing module validates the file envelope, CRCs, and record boundaries, then expands those timestamps in memory. The implementation follows Garmin's FIT protocol specification; OMATA Utility App's parser informed the review of timestamp and session semantics. Original recordings remain unchanged.

Activity time uses complete session timer totals. If unavailable, complete session elapsed totals appear explicitly as **Elapsed**. Record timestamp spans are never presented as activity duration. Missing stats remain absent. Course files without sessions can use their recorded distance field.

Files are decoded locally. MapKit requests geographic imagery from Apple; its map-service requests can identify the area being viewed. The FIT file itself is not uploaded. There is no account, backend, API key, or request for the Mac's current location. Source files over 100 MB are rejected to bound preview resource use.

The app and extension are sandboxed and signed locally with an ad hoc signature. Public distribution would require Developer ID signing and notarization. Charts, playback, GPX, and Finder thumbnails are outside this version.

`project.yml` is the XcodeGen source. After changing target configuration, run `xcodegen generate` and retain the generated project, property lists, entitlements, and package lockfile together.
