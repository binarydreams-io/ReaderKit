import SwiftUI

struct ReaderSettingsView: View {
  @Binding var theme: ReadingTheme
  @Binding var readerFont: ReadingFont
  @Binding var textScale: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      sectionLabel("Theme")
      themePicker

      sectionLabel("Font")
      Picker("Font", selection: $readerFont) {
        ForEach(ReadingFont.allCases) { font in
          Text(font.displayName).tag(font)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)

      sectionLabel("Text Size")
      textSizeControls
    }
    .padding(20)
    .frame(width: 280)
    .tint(.readerGreen)
  }

  private var themePicker: some View {
    GlassEffectContainer(spacing: 10) {
      HStack(spacing: 10) {
        ForEach(ReadingTheme.allCases) { option in
          Button {
            theme = option
          } label: {
            Circle()
              .fill(option.backgroundColor)
              .stroke(option.textColor.opacity(0.28), lineWidth: 1)
              .overlay {
                if theme == option {
                  Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(option.textColor)
                }
              }
              .frame(width: 36, height: 36)
          }
          .buttonStyle(.glass)
          .accessibilityLabel(option.displayName)
          .accessibilityAddTraits(theme == option ? .isSelected : [])
        }
      }
    }
  }

  private var textSizeControls: some View {
    HStack {
      Button {
        textScale = max(0.8, ((textScale - 0.1) * 10).rounded() / 10)
      } label: {
        Text("A")
          .font(.system(size: 13))
          .frame(width: 28, height: 24)
      }
      .buttonStyle(.glass)
      .disabled(textScale <= 0.8)
      .accessibilityLabel("Decrease text size")

      Spacer()

      Text("\(Int((textScale * 100).rounded()))%")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)

      Spacer()

      Button {
        textScale = min(1.6, ((textScale + 0.1) * 10).rounded() / 10)
      } label: {
        Text("A")
          .font(.system(size: 19))
          .frame(width: 28, height: 24)
      }
      .buttonStyle(.glass)
      .disabled(textScale >= 1.6)
      .accessibilityLabel("Increase text size")
    }
  }

  private func sectionLabel(_ title: LocalizedStringKey) -> some View {
    Text(title)
      .font(.caption.weight(.semibold))
      .textCase(.uppercase)
      .foregroundStyle(.secondary)
  }
}
