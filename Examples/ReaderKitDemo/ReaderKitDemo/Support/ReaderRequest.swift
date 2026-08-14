import Foundation

struct ReaderRequest: Codable, Hashable, Identifiable, Sendable {
  let id: UUID
  let url: URL

  init(id: UUID = UUID(), url: URL) {
    self.id = id
    self.url = url
  }
}
