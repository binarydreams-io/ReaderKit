// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import Foundation

/// A table in an article.
public struct ArticleTable: Sendable, Equatable {
  /// The table cells, row by row.
  public let rows: [[AttributedString]]
  /// Whether the first row contains header cells.
  public let hasHeaderRow: Bool

  /// Creates a table from rows of cells.
  public init(rows: [[AttributedString]], hasHeaderRow: Bool) {
    self.rows = rows
    self.hasHeaderRow = hasHeaderRow
  }
}
