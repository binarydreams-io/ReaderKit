import Foundation
import ReaderKit

let url = URL(string: "https://example.com/article")!
let style = ReaderStyle(baseFontSize: 19)
let view = ReaderView(link: url, style: style)

print("ReaderKit consumer: \(String(describing: type(of: view)))")
