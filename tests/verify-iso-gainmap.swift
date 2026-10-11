import Foundation
import ImageIO

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: verify-iso-gainmap <image>\n", stderr)
    exit(2)
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
    fputs("Could not read image: \(url.path)\n", stderr)
    exit(1)
}

guard CGImageSourceCopyAuxiliaryDataInfoAtIndex(
    source,
    0,
    kCGImageAuxiliaryDataTypeISOGainMap
) != nil else {
    fputs("Image does not contain an ISO gain map: \(url.path)\n", stderr)
    exit(1)
}
