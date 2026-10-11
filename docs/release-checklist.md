# Release checklist

## Automated checks

- Confirm the version in `plugin/GainMap HDR Heic Export.lrdevplugin/Info.lua` is the version you intend to release.
- Run `make test package` on macOS with Xcode and the Metal toolchain installed.
- Inspect the generated zip and confirm it contains one `.lrdevplugin` folder with `Info.lua`, `ExportServiceProvider.lua`, `toGainMapHDR`, and both `.ci.metallib` files.
- Confirm the zip does not contain a `__MACOSX` directory.
- Push a matching `v<version>` tag and wait for the **Build and release plugin** workflow to finish successfully.
- Download the zip and `SHA256SUMS.txt` from the GitHub release and verify the checksum before distribution.

## Lightroom Classic smoke test

Use a copy of the release package and representative HDR and SDR photos.

1. Add the unzipped `.lrdevplugin` folder in **File → Plug-in Manager**. Confirm the plugin is enabled and reports no errors.
2. Export an HDR photo as HEIC using the default ISO gain-map mode. Confirm the export finishes, the output opens, and Lightroom does not leave an intermediate TIFF behind.
3. Export the same photo as JPEG in ISO gain-map mode, then as JPEG in SDR mode. Confirm both files open as JPEGs.
4. Export as HEIC in Apple gain-map mode, and as HEIC in PQ and HLG modes. Confirm each completes and the exported images render in a compatible HDR viewer.
5. Try half-size and monochrome gain-map options in ISO mode. Confirm the output opens; compare appearance with the full-size RGB gain-map export.
6. Try a filename suffix containing spaces and punctuation. Confirm the destination filename is correct.
7. Load an export preset saved by an older plugin version. Confirm its options remain usable or migrate to sensible current defaults.
8. Export an SDR source in a gain-map mode. Confirm it completes with the expected SDR fallback behavior.

Record the Lightroom Classic version, macOS version, source image format, selected mode, and any warnings when reporting a failure.
