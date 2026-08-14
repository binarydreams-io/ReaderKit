import SwiftUI

struct BlockView: View {
  let block: ArticleBlock
  let style: ReaderStyle

  var body: some View {
    switch block {
    case let .heading(level, text): HeadingView(level: level, text: text, style: style)
    case let .paragraph(text): ParagraphView(text: text, style: style)
    case let .image(image): ImageBlockView(image: image, style: style)
    case let .blockquote(inner): BlockquoteView(blocks: inner, style: style)
    case let .list(ordered, items): ListBlockView(ordered: ordered, items: items, style: style)
    case let .codeBlock(code, _): CodeBlockView(code: code, style: style)
    case let .table(table): TableBlockView(table: table, style: style)
    case let .embed(embed): EmbedBlockView(embed: embed, style: style)
    case .thematicBreak: Divider().padding(.vertical, style.baseFontSize / 2)
    }
  }
}
