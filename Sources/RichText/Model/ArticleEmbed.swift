import Foundation

public struct ArticleEmbed: Sendable, Equatable {
  public enum Kind: Sendable, Equatable {
    case video(posterURL: URL?)
    case link
  }

  public let url: URL
  public let kind: Kind
  public let title: String?

  public init(url: URL, kind: Kind, title: String? = nil) {
    self.url = url
    self.kind = kind
    self.title = title
  }
}
