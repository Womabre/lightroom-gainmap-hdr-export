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

The resulting plugin archive is written to `build/GainMap HDR Heic Export.lrdevplugin.zip`.

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

## License

See [LICENSE](LICENSE) and the notices in the archived release sources. The gain-map implementation is based on [PQ_HDR_to_Gain_Map_HDR](https://github.com/chemharuka/PQ_HDR_to_Gain_Map_HDR).
