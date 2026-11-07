import Foundation
import ImageIO
import CoreGraphics

@main struct AppleArtworkTests {
    static func main() {
        let context = CGContext(data: nil, width: 3000, height: 2000, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let data = NSMutableData()
        let output = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(output, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(output))
        let image = AppleArtwork.decode(data as Data, maxPixelSize: 512)!
        precondition(image.width <= 512 && image.height <= 512, "Large covers must be downsampled before decoding")
        precondition(abs(Double(image.width) / Double(image.height) - 1.5) < 0.01, "Preserve aspect ratio")
        precondition(AppleArtwork.decode(Data("not an image".utf8), maxPixelSize: 512) == nil)
        print("AppleArtworkTests passed")
    }
}
