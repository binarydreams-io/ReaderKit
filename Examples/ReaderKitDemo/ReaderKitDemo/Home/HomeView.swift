// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: MIT

import SwiftUI

struct HomeView: View {
  @State private var input = ""
  @State private var validationMessage: String?
#if os(iOS)
  @State private var presentedReader: ReaderRequest?
#else
  @Environment(\.openWindow) private var openWindow
#endif

  var body: some View {
    ZStack {
      Color.readerCanvas
        .ignoresSafeArea()

      VStack(spacing: 30) {
        Spacer(minLength: 24)
        identity
        launcher
        featureChips
        Spacer(minLength: 24)
      }
      .padding(24)
      .frame(maxWidth: 780)
    }
    .tint(.readerGreen)
#if os(iOS)
    .fullScreenCover(item: $presentedReader) { request in
      ReaderScreen(request: request)
    }
#endif
  }

  private var identity: some View {
    VStack(spacing: 12) {
      Image(systemName: "text.book.closed.fill")
        .font(.system(size: 30, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 68, height: 68)
        .background(Color.readerGreen, in: .rect(cornerRadius: 22))
        .shadow(color: .readerGreen.opacity(0.28), radius: 24, y: 12)
        .accessibilityHidden(true)

      Text("ReaderKit")
        .font(.system(size: 48, weight: .semibold))
        .tracking(-1.4)

      Text("Turn a web page into a native reading surface.")
        .font(.title3)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  private var launcher: some View {
    VStack(alignment: .leading, spacing: 10) {
      GlassEffectContainer(spacing: 12) {
        VStack(spacing: 12) {
          urlField
          readButton
        }
        .frame(maxWidth: .infinity)
      }

      if let validationMessage {
        Label(validationMessage, systemImage: "exclamationmark.circle.fill")
          .font(.caption)
          .foregroundStyle(.red)
          .padding(.horizontal, 6)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .animation(.snappy, value: validationMessage)
    .frame(maxWidth: .infinity)
  }

  private var urlField: some View {
    TextField("https://example.com/article", text: $input)
      .textFieldStyle(.plain)
      .font(.body.monospaced())
      .textContentType(.URL)
      .autocorrectionDisabled()
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity, minHeight: 52)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
      .onSubmit(openReader)
#if os(iOS)
      .textInputAutocapitalization(.never)
      .keyboardType(.URL)
#endif
  }

  private var readButton: some View {
    Button(action: openReader) {
      Label("Read", systemImage: "book.pages")
        .fontWeight(.semibold)
        .padding(.horizontal, 18)
        .frame(minHeight: 32)
    }
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.capsule)
    .tint(.readerGreen)
  }

  private var featureChips: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) {
        chip("Readability engine", systemImage: "text.magnifyingglass")
        chip("Native SwiftUI", systemImage: "swift")
        chip("No WebKit", systemImage: "checkmark.shield")
      }

      VStack(spacing: 10) {
        chip("Readability engine", systemImage: "text.magnifyingglass")
        chip("Native SwiftUI", systemImage: "swift")
        chip("No WebKit", systemImage: "checkmark.shield")
      }
    }
  }

  private func chip(_ title: LocalizedStringKey, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.medium))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 13)
      .padding(.vertical, 8)
      .glassEffect(.regular, in: .capsule)
  }

  private func openReader() {
    guard let url = normalizedURL else {
      validationMessage = "Enter a valid HTTPS URL."
      return
    }

    validationMessage = nil
    let request = ReaderRequest(url: url)
#if os(iOS)
    presentedReader = request
#else
    openWindow(id: "reader", value: request)
#endif
  }

  private var normalizedURL: URL? {
    let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }

    let normalized = value.contains("://") ? value : "https://\(value)"
    guard let components = URLComponents(string: normalized),
          components.scheme?.lowercased() == "https",
          components.host?.isEmpty == false
    else {
      return nil
    }
    return components.url
  }
}
