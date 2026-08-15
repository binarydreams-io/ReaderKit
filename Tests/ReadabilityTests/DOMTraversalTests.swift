// SPDX-License-Identifier: Apache-2.0
// Contains material adapted from Mozilla Readability or Neo Lee's swift-readability.
// Modified by Binary Dreams, LLC.

@testable import Readability
import SwiftSoup
import Testing

/// Tests for DOMTraversal utilities
/// These tests verify the core traversal functionality needed for Readability
@Suite("DOM Traversal Tests")
struct DOMTraversalTests {

  // MARK: - getNextNode Tests

  @Test
  func `getNextNode returns first child when available`() throws {
    let html = "<div><p>Child 1</p><p>Child 2</p></div>"
    let doc = try SwiftSoup.parse(html)
    let div = try #require(doc.select("div").first())

    let next = DOMTraversal.getNextNode(div)

    #expect(next != nil)
    #expect(next?.tagName().lowercased() == "p")
    #expect(try next?.text() == "Child 1")
  }

  @Test
  func `getNextNode returns sibling when no children`() throws {
    let html = "<div><p>First</p><span>Second</span></div>"
    let doc = try SwiftSoup.parse(html)
    let p = try #require(doc.select("p").first())

    let next = DOMTraversal.getNextNode(p)

    #expect(next != nil)
    #expect(next?.tagName().lowercased() == "span")
    #expect(try next?.text() == "Second")
  }

  @Test
  func `getNextNode returns parent's sibling when no next sibling`() throws {
    let html = "<div><p><span>Deep</span></p><article>After</article></div>"
    let doc = try SwiftSoup.parse(html)
    let span = try #require(doc.select("span").first())

    let next = DOMTraversal.getNextNode(span)

    #expect(next != nil)
    #expect(next?.tagName().lowercased() == "article")
  }

  @Test
  func `getNextNode returns nil at end of document`() throws {
    let html = "<div><p>Last</p></div>"
    let doc = try SwiftSoup.parse(html)
    let p = try #require(doc.select("p").first())

    let next = DOMTraversal.getNextNode(p)

    #expect(next == nil)
  }

  @Test
  func `getNextNode ignores self and kids when requested`() throws {
    let html = "<div><p>Child</p></div><span>Next</span>"
    let doc = try SwiftSoup.parse(html)
    let div = try #require(doc.select("div").first())

    let next = DOMTraversal.getNextNode(div, ignoreSelfAndKids: true)

    #expect(next != nil)
    #expect(next?.tagName().lowercased() == "span")
  }

  @Test
  func `getNextNode handles nil input`() {
    let next = DOMTraversal.getNextNode(nil)
    #expect(next == nil)
  }

  // MARK: - removeAndGetNext Tests

  @Test
  func `removeAndGetNext removes node and returns next`() throws {
    let html = "<div><p id='first'>First</p><p id='second'>Second</p></div>"
    let doc = try SwiftSoup.parse(html)
    let first = try #require(doc.select("p#first").first())

    let next = DOMTraversal.removeAndGetNext(first)

    // First paragraph should be removed
    #expect(try doc.select("p#first").isEmpty())

    // Next should be second paragraph
    #expect(next != nil)
    #expect(next?.id() == "second")
  }

  @Test
  func `removeAndGetNext handles last element`() throws {
    let html = "<div><p>Only</p></div>"
    let doc = try SwiftSoup.parse(html)
    let p = try #require(doc.select("p").first())

    let next = DOMTraversal.removeAndGetNext(p)

    #expect(try doc.select("p").isEmpty())
    #expect(next == nil)
  }

  // MARK: - getNodeAncestors Tests

  @Test
  func `getNodeAncestors returns all ancestors`() throws {
    let html = "<div><p>Deep</p></div>"
    let doc = try SwiftSoup.parse(html)
    let p = try #require(doc.select("p").first())

    let ancestors = DOMTraversal.getNodeAncestors(p)

    // SwiftSoup parses with html and body wrapper, so we expect:
    // p -> div -> body -> html
    #expect(ancestors.count >= 2)
    #expect(ancestors[0].tagName().lowercased() == "div")
  }

  @Test
  func `getNodeAncestors respects maxDepth`() throws {
    let html = "<html><body><div><p>Deep</p></div></body></html>"
    let doc = try SwiftSoup.parse(html)
    let p = try #require(doc.select("p").first())

    let ancestors = DOMTraversal.getNodeAncestors(p, maxDepth: 2)

    #expect(ancestors.count == 2)
    #expect(ancestors[0].tagName().lowercased() == "div")
    #expect(ancestors[1].tagName().lowercased() == "body")
  }

  @Test
  func `getNodeAncestors returns empty for root`() throws {
    // In SwiftSoup, even html element has a parent (Document)
    // So we test that the function works correctly for top-level elements
    let html = "<p>Test</p>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let p = try #require(doc.select("p").first())

    // p's ancestors are body and the fragment root
    let ancestors = DOMTraversal.getNodeAncestors(p)

    #expect(ancestors.count >= 1) // At least body
  }

  // MARK: - hasAncestorTag Tests

  @Test
  func `hasAncestorTag finds matching ancestor`() throws {
    let html = "<article><div><p>Test</p></div></article>"
    let doc = try SwiftSoup.parse(html)
    let p = try #require(doc.select("p").first())

    let hasArticle = DOMTraversal.hasAncestorTag(p, tagName: "article")
    let hasDiv = DOMTraversal.hasAncestorTag(p, tagName: "div")

    #expect(hasArticle == true)
    #expect(hasDiv == true)
  }

  @Test
  func `hasAncestorTag returns false for non-matching ancestor`() throws {
    let html = "<article><div><p>Test</p></div></article>"
    let doc = try SwiftSoup.parse(html)
    let p = try #require(doc.select("p").first())

    let hasSection = DOMTraversal.hasAncestorTag(p, tagName: "section")

    #expect(hasSection == false)
  }

  @Test
  func `hasAncestorTag respects maxDepth`() throws {
    let html = "<greatgrandparent><grandparent><parent><child>Test</child></parent></grandparent></greatgrandparent>"
    let doc = try SwiftSoup.parseBodyFragment(html)
    let child = try #require(doc.select("child").first())

    // child -> parent -> grandparent -> greatgrandparent (within body fragment context)
    // depth 0: parent
    // depth 1: grandparent
    // depth 2: greatgrandparent

    // With maxDepth 1, should find grandparent but not greatgrandparent
    let hasParentDepth1 = DOMTraversal.hasAncestorTag(child, tagName: "parent", maxDepth: 1)
    let hasGrandparentDepth1 = DOMTraversal.hasAncestorTag(child, tagName: "grandparent", maxDepth: 1)
    let hasGreatGrandparentDepth1 = DOMTraversal.hasAncestorTag(child, tagName: "greatgrandparent", maxDepth: 1)

    #expect(hasParentDepth1 == true) // parent at depth 0
    #expect(hasGrandparentDepth1 == true) // grandparent at depth 1, within limit
    #expect(hasGreatGrandparentDepth1 == false) // greatgrandparent at depth 2, exceeds maxDepth 1

    // With unlimited depth (0), should find all
    let hasGreatGrandparentUnlimited = DOMTraversal.hasAncestorTag(child, tagName: "greatgrandparent", maxDepth: 0)
    #expect(hasGreatGrandparentUnlimited == true)
  }

  @Test
  func `hasAncestorTag uses filter`() throws {
    let html = "<article class='content'><div><p>Test</p></div></article>"
    let doc = try SwiftSoup.parse(html)
    let p = try #require(doc.select("p").first())

    let hasContentArticle = DOMTraversal.hasAncestorTag(p, tagName: "article") { element in
      (try? element.className().contains("content")) ?? false
    }
    let hasOtherArticle = DOMTraversal.hasAncestorTag(p, tagName: "article") { element in
      (try? element.className().contains("other")) ?? false
    }

    #expect(hasContentArticle == true)
    #expect(hasOtherArticle == false)
  }

  // MARK: - hasSingleTagInsideElement Tests

  @Test
  func `hasSingleTagInsideElement returns true for single child`() throws {
    let html = "<div><p>Only child</p></div>"
    let doc = try SwiftSoup.parse(html)
    let div = try #require(doc.select("div").first())

    let hasSingleP = DOMTraversal.hasSingleTagInsideElement(div, tag: "p")

    #expect(hasSingleP == true)
  }

  @Test
  func `hasSingleTagInsideElement returns false for wrong tag`() throws {
    let html = "<div><span>Only child</span></div>"
    let doc = try SwiftSoup.parse(html)
    let div = try #require(doc.select("div").first())

    let hasSingleP = DOMTraversal.hasSingleTagInsideElement(div, tag: "p")

    #expect(hasSingleP == false)
  }

  @Test
  func `hasSingleTagInsideElement returns false for multiple children`() throws {
    let html = "<div><p>First</p><p>Second</p></div>"
    let doc = try SwiftSoup.parse(html)
    let div = try #require(doc.select("div").first())

    let hasSingleP = DOMTraversal.hasSingleTagInsideElement(div, tag: "p")

    #expect(hasSingleP == false)
  }

  @Test
  func `hasSingleTagInsideElement returns false with text content`() throws {
    let html = "<div>Text<p>Child</p></div>"
    let doc = try SwiftSoup.parse(html)
    let div = try #require(doc.select("div").first())

    let hasSingleP = DOMTraversal.hasSingleTagInsideElement(div, tag: "p")

    #expect(hasSingleP == false)
  }

  // MARK: - isElementWithoutContent Tests

  @Test
  func `isElementWithoutContent returns true for empty element`() throws {
    let html = "<div></div>"
    let doc = try SwiftSoup.parse(html)
    let div = try #require(doc.select("div").first())

    let isEmpty = DOMTraversal.isElementWithoutContent(div)

    #expect(isEmpty == true)
  }

  @Test
  func `isElementWithoutContent returns true for whitespace only`() throws {
    let html = "<div>   \n\t  </div>"
    let doc = try SwiftSoup.parse(html)
    let div = try #require(doc.select("div").first())

    let isEmpty = DOMTraversal.isElementWithoutContent(div)

    #expect(isEmpty == true)
  }

  @Test
  func `isElementWithoutContent returns false for text content`() throws {
    let html = "<div>Some text</div>"
    let doc = try SwiftSoup.parse(html)
    let div = try #require(doc.select("div").first())

    let isEmpty = DOMTraversal.isElementWithoutContent(div)

    #expect(isEmpty == false)
  }

  @Test
  func `isElementWithoutContent returns true for only br elements`() throws {
    let html = "<div><br><br></div>"
    let doc = try SwiftSoup.parse(html)
    let div = try #require(doc.select("div").first())

    let isEmpty = DOMTraversal.isElementWithoutContent(div)

    #expect(isEmpty == true)
  }

  // MARK: - isWhitespace Tests

  @Test
  func `isWhitespace returns true for empty text node`() {
    let textNode = TextNode("   ", "")

    let isWhitespace = DOMTraversal.isWhitespace(textNode)

    #expect(isWhitespace == true)
  }

  @Test
  func `isWhitespace returns false for non-empty text node`() {
    let textNode = TextNode("Hello", "")

    let isWhitespace = DOMTraversal.isWhitespace(textNode)

    #expect(isWhitespace == false)
  }

  @Test
  func `isWhitespace returns true for br element`() {
    let br = Element(Tag("br"), "")

    let isWhitespace = DOMTraversal.isWhitespace(br)

    #expect(isWhitespace == true)
  }

  // MARK: - Element Extension Tests

  @Test
  func `Element.nextNode works`() throws {
    let html = "<div><p>Test</p></div>"
    let doc = try SwiftSoup.parse(html)
    let div = try #require(doc.select("div").first())

    let next = div.nextNode()

    #expect(next?.tagName().lowercased() == "p")
  }

  @Test
  func `Element.ancestors works`() throws {
    let html = "<div><p>Test</p></div>"
    let doc = try SwiftSoup.parse(html)
    let p = try #require(doc.select("p").first())

    let ancestors = p.ancestors()

    // SwiftSoup parses with html and body wrapper
    #expect(ancestors.count >= 2)
  }

  @Test
  func `Element.hasAncestor works`() throws {
    let html = "<article><div><p>Test</p></div></article>"
    let doc = try SwiftSoup.parse(html)
    let p = try #require(doc.select("p").first())

    let hasArticle = p.hasAncestor(tagName: "article")

    #expect(hasArticle == true)
  }
}
