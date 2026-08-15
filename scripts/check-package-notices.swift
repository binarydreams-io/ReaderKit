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
    let state: State
  }

  let pins: [Pin]
}

private func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("License error: \(message)\n".utf8))
  exit(EXIT_FAILURE)
}

guard CommandLine.arguments.count == 4 else {
  fail("usage: check-package-notices.swift PACKAGE_RESOLVED MANIFEST LICENSE_DIRECTORY")
}

let resolvedURL = URL(fileURLWithPath: CommandLine.arguments[1])
let manifestURL = URL(fileURLWithPath: CommandLine.arguments[2])
let licenseDirectoryURL = URL(fileURLWithPath: CommandLine.arguments[3])

do {
  let resolved = try JSONDecoder().decode(
    ResolvedPackage.self,
    from: Data(contentsOf: resolvedURL)
  )
  let manifest = try String(contentsOf: manifestURL, encoding: .utf8)
  var expectedVersions: [String: String] = [:]

  for (index, line) in manifest.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
    if line.isEmpty || line.hasPrefix("#") {
      continue
    }

    let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
    guard fields.count == 3 else {
      fail("invalid manifest entry at line \(index + 1)")
    }

    let identity = String(fields[0])
    let version = String(fields[1])
    let licenseFile = String(fields[2])
    guard expectedVersions.updateValue(version, forKey: identity) == nil else {
      fail("duplicate manifest identity: \(identity)")
    }
    guard FileManager.default.fileExists(
      atPath: licenseDirectoryURL.appendingPathComponent(licenseFile).path
    ) else {
      fail("package notice missing: \(licenseFile)")
    }
  }

  var actualVersions: [String: String] = [:]
  for pin in resolved.pins {
    guard let version = pin.state.version else {
      let reference = pin.state.branch ?? pin.state.revision ?? "unknown"
      fail("non-version package pin is not supported: \(pin.identity)@\(reference)")
    }
    guard actualVersions.updateValue(version, forKey: pin.identity) == nil else {
      fail("duplicate resolved package identity: \(pin.identity)")
    }
  }

  guard actualVersions == expectedVersions else {
    let expected = expectedVersions.sorted { $0.key < $1.key }
      .map { "\($0.key)@\($0.value)" }
      .joined(separator: ", ")
    let actual = actualVersions.sorted { $0.key < $1.key }
      .map { "\($0.key)@\($0.value)" }
      .joined(separator: ", ")
    fail("package notice manifest mismatch; expected [\(expected)], resolved [\(actual)]")
  }
} catch {
  fail(error.localizedDescription)
}
