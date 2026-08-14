//
//  Logger.swift
//  ReaderKit
//
//  Created by Leonid Frolov on 06.12.2025.
//

import OSLog

extension Logger {
  /// Hardcoded subsystem so ReaderKit logs can be filtered independently of the host app
  /// (Bundle.main inside a Swift Package returns the host app's identifier).
  private static let subsystem = "io.binarydreams.ReaderKit"

  /// Logs the view cycles like a view that appeared.
  package static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")

  /// Logs network events.
  package static let network = Logger(subsystem: subsystem, category: "network")

  /// Logs HTML parser events.
  package static let parser = Logger(subsystem: subsystem, category: "parser")

  /// All logs related to tracking and analytics.
  package static let statistics = Logger(subsystem: subsystem, category: "statistics")
}
