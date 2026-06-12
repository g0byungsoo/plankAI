// Subject cutout via Vision foreground-instance masking.
// Turns editorial photos into true-alpha sticker PNGs.
//
// Build once:  swiftc -O scripts/cutout.swift -o /tmp/cutout
// Run:         /tmp/cutout input.jpg output.png

import CoreImage
import Foundation
import Vision

guard CommandLine.arguments.count == 3 else {
    print("usage: cutout <input> <output.png>")
    exit(1)
}
let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = CIImage(contentsOf: inputURL) else {
    print("cannot read \(inputURL.path)")
    exit(1)
}

let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(ciImage: source)
try handler.perform([request])

guard let result = request.results?.first else {
    print("no foreground instances found in \(inputURL.lastPathComponent)")
    exit(2)
}

let maskBuffer = try result.generateScaledMaskForImage(
    forInstances: result.allInstances,
    from: handler
)
var mask = CIImage(cvPixelBuffer: maskBuffer)

// Erode the mask ~2.5px so no halo of the generation background
// survives at the silhouette edge (founder QA: "weird colors on the
// border"). MorphologyMinimum shrinks the white (subject) region.
if let erode = CIFilter(name: "CIMorphologyMinimum") {
    erode.setValue(mask, forKey: kCIInputImageKey)
    erode.setValue(2.5, forKey: kCIInputRadiusKey)
    mask = erode.outputImage ?? mask
}

let blend = CIFilter(name: "CIBlendWithMask")!
blend.setValue(source, forKey: kCIInputImageKey)
blend.setValue(CIImage(color: .clear).cropped(to: source.extent), forKey: kCIInputBackgroundImageKey)
blend.setValue(mask, forKey: kCIInputMaskImageKey)

let context = CIContext()
guard let output = blend.outputImage,
      let cgImage = context.createCGImage(output, from: source.extent) else {
    print("compositing failed")
    exit(3)
}

let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, cgImage, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outputURL.path)")
