import Foundation
import SwiftSoup

/// A site rule expressed as data: a host gate plus an ordered list of
/// selector-and-action steps. Covers the rule shapes that are pure DOM
/// selection with a fixed transformation; rules that need real logic
/// (climbing ancestors, building DOM, cross-node conditions) stay bespoke
/// `SiteRule` types.
struct DeclarativeSiteRule {
  enum Action {
    /// Remove every matched element.
    case remove
    /// Replace each matched element with all of its child nodes,
    /// preserving loose text between elements.
    case unwrap
    /// Replace each matched element with its element children only,
    /// discarding loose text between them.
    case unwrapElements
  }

  /// A per-match condition; all guards of a step must pass for the step's
  /// action to run on that match. Text guards compare against the match's
  /// whitespace-collapsed, trimmed, lowercased inner text.
  enum MatchGuard {
    case textEquals(String)
    case textContains(String)
    /// The match contains at least `count` results for `selector`
    /// (evaluated with the match as the scope, so `>`-prefixed selectors work).
    case minMatches(String, count: Int)
  }

  struct Step {
    let selector: String
    let action: Action
    let guards: [MatchGuard]

    init(_ selector: String, _ action: Action, guards: [MatchGuard] = []) {
      self.selector = selector
      self.action = action
      self.guards = guards
    }
  }

  let id: String
  let hosts: [String]?
  /// When set, the rule only runs if the article contains a match for this selector.
  let precondition: String?
  let steps: [Step]

  init(id: String, hosts: [String]?, precondition: String? = nil, steps: [Step]) {
    self.id = id
    self.hosts = hosts
    self.precondition = precondition
    self.steps = steps
  }

  func appliesTo(host: String?) -> Bool {
    SiteRuleHostMatching.matches(hosts, host)
  }

  func apply(to root: Element) throws {
    if let precondition {
      guard try !root.select(precondition).isEmpty() else { return }
    }

    for step in steps {
      // Reversed so removing a match never disturbs the position of a
      // not-yet-visited ancestor match within the same snapshot.
      for element in try root.select(step.selector).array().reversed() {
        guard element.parent() != nil else { continue }
        guard try step.guards.allSatisfy({ try matches($0, element) }) else { continue }
        try perform(step.action, on: element)
      }
    }
  }

  private func matches(_ matchGuard: MatchGuard, _ element: Element) throws -> Bool {
    switch matchGuard {
    case let .textEquals(value):
      try normalizedText(of: element) == value.lowercased()
    case let .textContains(fragment):
      try normalizedText(of: element).contains(fragment.lowercased())
    case let .minMatches(selector, count):
      try element.select(selector).count >= count
    }
  }

  private func normalizedText(of element: Element) throws -> String {
    try DOMHelpers.getInnerText(element)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  private func perform(_ action: Action, on element: Element) throws {
    switch action {
    case .remove:
      try element.remove()
    case .unwrap:
      while let node = element.getChildNodes().first {
        try element.before(node)
      }
      try element.remove()
    case .unwrapElements:
      for child in element.children().array() {
        try element.before(child)
      }
      try element.remove()
    }
  }
}
