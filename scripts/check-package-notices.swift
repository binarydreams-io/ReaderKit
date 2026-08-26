// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: Apache-2.0

import Darwin
import Foundation

private struct ResolvedPackage: Decodable {
  struct Pin: Decodable {
    struct State: Decodable {
      let revision: String?
      let version: String?
      let branch: String?
    }

    let identity: String
    let location: String
    let state: State
  }

  let pins: [Pin]
}

private func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("License error: \(message)\n".utf8))
  exit(EXIT_FAILURE)
}

/// Line endings and trailing whitespace differ between editors and checkouts;
/// the words of a license must not.
private func normalizedLicenseText(_ text: String) -> String {
  text.replacingOccurrences(of: "\r\n", with: "\n")
    .split(separator: "\n", omittingEmptySubsequences: false)
    .map { String($0).replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
    .joined(separator: "\n")
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func repositoryName(of pin: ResolvedPackage.Pin) -> String {
  var name = URL(string: pin.location)?.lastPathComponent ?? pin.identity
  if name.hasSuffix(".git") {
    name.removeLast(4)
  }
  return name
}

/// The license shipped in the resolved checkout of `pin`, or nil when the
/// checkout is absent or carries no recognizable license file.
private func checkoutLicense(of pin: ResolvedPackage.Pin, in checkoutsDirectory: URL) -> (path: String, text: String)? {
  let repository = repositoryName(of: pin)
  let checkout = checkoutsDirectory.appendingPathComponent(repository)
  for candidate in ["LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING"] {
    let url = checkout.appendingPathComponent(candidate)
    if let text = try? String(contentsOf: url, encoding: .utf8) {
      return ("\(repository)/\(candidate)", text)
    }
  }
  return nil
}

guard CommandLine.arguments.count == 5 else {
  fail("usage: check-package-notices.swift PACKAGE_RESOLVED MANIFEST LICENSE_DIRECTORY CHECKOUTS_DIRECTORY")
}

let resolvedURL = URL(fileURLWithPath: CommandLine.arguments[1])
let manifestURL = URL(fileURLWithPath: CommandLine.arguments[2])
let licenseDirectoryURL = URL(fileURLWithPath: CommandLine.arguments[3])
let checkoutsDirectoryURL = URL(fileURLWithPath: CommandLine.arguments[4])

do {
  let resolved = try JSONDecoder().decode(
    ResolvedPackage.self,
    from: Data(contentsOf: resolvedURL)
  )
  let manifest = try String(contentsOf: manifestURL, encoding: .utf8)
  var noticeFiles: [String: String] = [:]

  for (index, line) in manifest.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
    if line.isEmpty || line.hasPrefix("#") {
      continue
    }

    let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
    guard fields.count == 2 else {
      fail("invalid manifest entry at line \(index + 1); expected `identity<TAB>license file`")
    }

    let identity = String(fields[0])
    let licenseFile = String(fields[1])
    guard noticeFiles.updateValue(licenseFile, forKey: identity) == nil else {
      fail("duplicate manifest identity: \(identity)")
    }
  }

  var pins: [String: ResolvedPackage.Pin] = [:]
  for pin in resolved.pins {
    guard pin.state.version != nil else {
      let reference = pin.state.branch ?? pin.state.revision ?? "unknown"
      fail("non-version package pin is not supported: \(pin.identity)@\(reference)")
    }
    guard pins.updateValue(pin, forKey: pin.identity) == nil else {
      fail("duplicate resolved package identity: \(pin.identity)")
    }
  }

  guard Set(noticeFiles.keys) == Set(pins.keys) else {
    let expected = noticeFiles.keys.sorted().joined(separator: ", ")
    let actual = pins.keys.sorted().joined(separator: ", ")
    fail("package notice manifest mismatch; manifest [\(expected)], resolved [\(actual)]")
  }

  // A version bump needs no manifest edit: what must stay in step is the
  // notice text, so each notice is held against the license the resolved
  // checkout actually ships.
  for (identity, licenseFile) in noticeFiles.sorted(by: { $0.key < $1.key }) {
    guard let pin = pins[identity], let version = pin.state.version else {
      fail("unresolved package: \(identity)")
    }
    let noticeURL = licenseDirectoryURL.appendingPathComponent(licenseFile)
    guard let notice = try? String(contentsOf: noticeURL, encoding: .utf8) else {
      fail("package notice missing: \(licenseFile)")
    }
    guard let license = checkoutLicense(of: pin, in: checkoutsDirectoryURL) else {
      fail("no license file in the checkout of \(identity)@\(version); run `swift package resolve` first")
    }
    guard normalizedLicenseText(notice) == normalizedLicenseText(license.text) else {
      fail("package notice \(licenseFile) differs from \(license.path) at \(identity)@\(version); update the notice and NOTICE.md")
    }
  }
} catch {
  fail(error.localizedDescription)
}
