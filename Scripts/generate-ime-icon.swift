import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(
        Data("出力先を指定してください\n".utf8)
    )
    exit(EXIT_FAILURE)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
var mediaBox = CGRect(x: 0, y: 0, width: 16, height: 16)

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

context.setStrokeColor(
    CGColor(gray: 0, alpha: 1)
)
context.setLineWidth(1.5)
context.setLineCap(.round)
context.setLineJoin(.round)

context.move(to: CGPoint(x: 3.5, y: 3.5))
context.addLine(to: CGPoint(x: 3.5, y: 12.5))
context.move(to: CGPoint(x: 3.5, y: 8))
context.addLine(to: CGPoint(x: 9.5, y: 8))
context.move(to: CGPoint(x: 9.5, y: 4.5))
context.addLine(to: CGPoint(x: 9.5, y: 11.5))
context.strokePath()

context.setFillColor(
    CGColor(gray: 0, alpha: 1)
)
context.fillEllipse(in: CGRect(x: 12, y: 10.5, width: 1.5, height: 1.5))

context.endPDFPage()
context.closePDF()
