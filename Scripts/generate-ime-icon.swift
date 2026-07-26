import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(
        Data("出力先を指定してください\n".utf8)
    )
    exit(EXIT_FAILURE)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
var mediaBox = CGRect(x: 0, y: 0, width: 128, height: 128)

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

context.setFillColor(
    CGColor(red: 0.12, green: 0.35, blue: 0.72, alpha: 1)
)
context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))

context.setStrokeColor(
    CGColor(red: 1, green: 1, blue: 1, alpha: 1)
)
context.setLineWidth(10)
context.setLineCap(.round)

context.move(to: CGPoint(x: 34, y: 34))
context.addLine(to: CGPoint(x: 34, y: 94))
context.move(to: CGPoint(x: 34, y: 64))
context.addLine(to: CGPoint(x: 78, y: 64))
context.move(to: CGPoint(x: 78, y: 40))
context.addLine(to: CGPoint(x: 78, y: 88))
context.strokePath()

context.setFillColor(
    CGColor(red: 1, green: 1, blue: 1, alpha: 1)
)
context.fillEllipse(in: CGRect(x: 90, y: 82, width: 10, height: 10))

context.endPDFPage()
context.closePDF()
