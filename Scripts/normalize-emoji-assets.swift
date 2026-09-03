import AppKit
import Foundation

let canvasSize = 96
let contentSize: CGFloat = 82

func normalizedImage(at url: URL) -> Data? {
    guard let source = NSImage(contentsOf: url),
          let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 256,
            pixelsHigh: 256,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
          ),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        return nil
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    source.draw(
        in: NSRect(x: 0, y: 0, width: 256, height: 256),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let pixels = bitmap.bitmapData else { return nil }
    var minX = 256
    var minY = 256
    var maxX = -1
    var maxY = -1
    for y in 0..<256 {
        let row = pixels.advanced(by: y * bitmap.bytesPerRow)
        for x in 0..<256 where row[x * 4 + 3] > 4 {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY,
          let cropped = bitmap.cgImage?.cropping(to: CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
          )) else {
        return nil
    }
    let sourceSize = NSSize(width: cropped.width, height: cropped.height)
    let scale = min(contentSize / sourceSize.width, contentSize / sourceSize.height)
    let targetSize = NSSize(
        width: sourceSize.width * scale,
        height: sourceSize.height * scale
    )
    guard let output = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: canvasSize,
        pixelsHigh: canvasSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let outputContext = NSGraphicsContext(bitmapImageRep: output) else {
        return nil
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = outputContext
    NSImage(cgImage: cropped, size: sourceSize).draw(
        in: NSRect(
            x: (CGFloat(canvasSize) - targetSize.width) / 2,
            y: (CGFloat(canvasSize) - targetSize.height) / 2,
            width: targetSize.width,
            height: targetSize.height
        ),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    outputContext.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return output.representation(using: .png, properties: [:])
}

for argument in CommandLine.arguments.dropFirst() {
    let directory = URL(fileURLWithPath: argument, isDirectory: true)
    let files = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "png" }
    for (index, url) in files.enumerated() {
        guard let data = normalizedImage(at: url) else {
            fatalError("Failed to normalize \(url.path)")
        }
        try data.write(to: url, options: .atomic)
        if (index + 1) % 250 == 0 {
            print("\(directory.lastPathComponent): \(index + 1)/\(files.count)")
        }
    }
}
