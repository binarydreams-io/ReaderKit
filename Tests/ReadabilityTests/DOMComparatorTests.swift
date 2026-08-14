@testable import Readability
import Testing

@Suite("DOM Comparator Tests")
struct DOMComparatorTests {
  @Test
  func `normal text comparison collapses HTML whitespace`() {
    let comparison = DOMComparator.compare(
      "<article><p>Hello    world</p></article>",
      "<article><p>Hello world</p></article>"
    )
    #expect(comparison.isEqual)
  }

  @Test
  func `boolean attributes compare by presence`() {
    let comparison = DOMComparator.compare(
      "<article><iframe allowfullscreen></iframe></article>",
      "<article><iframe allowfullscreen=\"allowfullscreen\"></iframe></article>"
    )
    #expect(comparison.isEqual)
  }

  @Test
  func `pre text comparison preserves indentation`() {
    let comparison = DOMComparator.compare(
      "<article><pre><code><span> return value;</span></code></pre></article>",
      "<article><pre><code><span>    return value;</span></code></pre></article>"
    )
    #expect(!comparison.isEqual)
    #expect(comparison.diff.contains("Text mismatch"))
  }

  @Test
  func `pre text comparison preserves blank lines`() {
    let comparison = DOMComparator.compare(
      "<article><pre><code>alpha\nbeta</code></pre></article>",
      "<article><pre><code>alpha\n\nbeta</code></pre></article>"
    )
    #expect(!comparison.isEqual)
    #expect(comparison.diff.contains("Text mismatch"))
  }
}
