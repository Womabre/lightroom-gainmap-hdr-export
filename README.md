# Lightroom Gain Map HDR Export

A Lightroom Classic export plugin that converts rendered HDR TIFFs to HEIC or JPEG with gain-map metadata. The converter also supports SDR, PQ, and HLG HEIC output.

## Requirements

- macOS 26 or later
- Lightroom Classic 14 or later
- Xcode with the macOS SDK and Metal compiler to build from source

The current converter uses Core Image HDR gain-map APIs. The included Xcode project and command-line build target version 3.3.2.

## Build

From the repository root, run:

```sh
make
```

This compiles the Core Image Metal kernels and Swift converter into the Lightroom plugin folder. To create a zip for distribution, run:

```sh
make package
```

The resulting plugin archive is written to `build/GainMap HDR Heic Export.lrdevplugin.zip`. The archive includes the plugin folder, converter, and compiled Metal kernels, without extra macOS resource-fork entries.

To run the converter integration checks and build the package:

```sh
make test package
```

These checks use the included HEIC sample and verify successful HEIC/JPEG exports, ISO gain-map metadata, filename suffix handling, subsampled monochrome JPEG output, and rejection of invalid options. They require macOS, Xcode, and the Metal toolchain.

## Install

1. Build the plugin, or download a packaged release.
2. Unzip the `.lrdevplugin.zip` archive if you downloaded a release.
3. In Lightroom Classic, open **File → Plug-in Manager**, choose **Add**, and select `plugin/GainMap HDR Heic Export.lrdevplugin` (or the unzipped release folder).
4. In Export, select **Export to HEIC / HDR Gain Map**. Render as TIFF and enable Lightroom HDR output.

JPEG output supports SDR and gain-map modes. PQ and HLG output require HEIC.

## Repository layout

- `toGainMapHDR/` — Swift command-line converter, Metal kernels, and Xcode project.
- `plugin/` — Lightroom plugin source and generated build outputs.
- `archive/` — older releases retained for reference; the root Makefile builds the current source only.
- `tests/` — macOS converter integration checks using the included sample image.
- `.github/workflows/release.yml` — pull-request and branch builds; version tags publish a GitHub release with the plugin zip and SHA-256 checksum.

## Releases

Push a version tag matching the version in `plugin/GainMap HDR Heic Export.lrdevplugin/Info.lua` (for example, `v3.3.2`) to build and publish a GitHub release. Review the workflow result and download the zip and checksum from the release page. Keep both files together and verify the download with `shasum -a 256 -c SHA256SUMS.txt`.

Before announcing a release, install the packaged plugin in Lightroom Classic and complete the [release checklist](docs/release-checklist.md). Automated checks cannot verify Lightroom's UI or the appearance of the exported images.

## License

See [LICENSE](LICENSE) and the notices in the archived release sources. The gain-map implementation is based on [PQ_HDR_to_Gain_Map_HDR](https://github.com/chemharuka/PQ_HDR_to_Gain_Map_HDR).
