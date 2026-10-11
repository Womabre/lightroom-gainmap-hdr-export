# toGainMapHDR converter

This directory contains the Swift and Core Image Metal source for the converter used by the Lightroom plugin. Build the plugin and its converter from the repository root with `make`; see the root [README](../README.md) for requirements and installation.

The converter writes HEIC by default. Use `-j` for 8-bit JPEG output in SDR or gain-map modes. JPEG cannot be combined with `-p` (PQ) or `-h` (HLG). Unknown command-line options and failed image finalization return a nonzero exit status.
