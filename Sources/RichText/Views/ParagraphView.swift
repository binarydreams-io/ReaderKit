import SwiftUI

struct ParagraphView: View {
  let text: AttributedString
  let style: ReaderStyle

  var body: some View {
    Text(text)
      .font(.system(size: style.baseFontSize, design: style.fontDesign))
      .lineSpacing(style.lineSpacing)
      .textSelection(.enabled)
      .fixedSize(horizontal: false, vertical: true)
  }
}
