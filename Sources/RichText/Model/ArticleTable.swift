import Foundation

public struct ArticleTable: Sendable, Equatable {
  public let rows: [[AttributedString]]
  public let hasHeaderRow: Bool

  public init(rows: [[AttributedString]], hasHeaderRow: Bool) {
    self.rows = rows
    self.hasHeaderRow = hasHeaderRow
  }
}
