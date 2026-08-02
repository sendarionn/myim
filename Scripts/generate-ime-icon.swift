import CoreGraphics
import CoreText
import Foundation

guard [2, 5, 6].contains(CommandLine.arguments.count) else {
    FileHandle.standardError.write(
        Data("出力先を指定してください\n".utf8)
    )
    exit(EXIT_FAILURE)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let width = CommandLine.arguments.count >= 5
    ? CGFloat(Double(CommandLine.arguments[2]) ?? 16)
    : 16
let height = CommandLine.arguments.count >= 5
    ? CGFloat(Double(CommandLine.arguments[3]) ?? 16)
    : 16
let fontSize = CommandLine.arguments.count >= 5
    ? CGFloat(Double(CommandLine.arguments[4]) ?? 13)
    : 13
var mediaBox = CGRect(x: 0, y: 0, width: width, height: height)

guard
    let consumer = CGDataConsumer(url: outputURL as CFURL),
    let context = CGContext(
        consumer: consumer,
        mediaBox: &mediaBox,
        nil
    )
else {
    FileHandle.standardError.write(
        Data("アイコンを生成できません\n".utf8)
    )
    exit(EXIT_FAILURE)
}

context.beginPDFPage(nil)

let isApplicationIcon = CommandLine.arguments.count == 6
if isApplicationIcon {
    let inset = width * 0.06
    let backgroundRect = CGRect(
        x: inset,
        y: inset,
        width: width - inset * 2,
        height: height - inset * 2
    )
    let backgroundPath = CGPath(
        roundedRect: backgroundRect,
        cornerWidth: width * 0.21,
        cornerHeight: height * 0.21,
        transform: nil
    )
    context.addPath(backgroundPath)
    context.setFillColor(CGColor(red: 0.12, green: 0.45, blue: 0.86, alpha: 1))
    context.fillPath()
}

let font = CTFontCreateWithName(
    "HelveticaNeue-Medium" as CFString,
    fontSize,
    nil
)
let text = NSAttributedString(
    string: "m",
    attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String):
            isApplicationIcon
                ? CGColor(gray: 1, alpha: 1)
                : CGColor(gray: 0, alpha: 1)
    ]
)
let line = CTLineCreateWithAttributedString(text)
let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
context.textPosition = CGPoint(
    x: (mediaBox.width - bounds.width) / 2 - bounds.minX,
    y: (mediaBox.height - bounds.height) / 2 - bounds.minY
)
CTLineDraw(line, context)

context.endPDFPage()
context.closePDF()
