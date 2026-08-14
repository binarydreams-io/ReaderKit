import Foundation

public struct ArticleImage: Sendable, Equatable {
  public let url: URL
  public let alt: String?
  public let caption: String?

  public init(url: URL, alt: String? = nil, caption: String? = nil) {
    self.url = url
    self.alt = alt
    self.caption = caption
  }
}
