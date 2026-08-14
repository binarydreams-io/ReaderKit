# ReaderKit Demo

This Xcode project demonstrates the complete `ReaderView` integration on iOS and macOS.

## Run The Demo

1. Open `ReaderKitDemo.xcodeproj` in Xcode 26 or later.
2. Select the shared `ReaderKitDemo` scheme.
3. Select an iOS 26 or macOS 26 destination.
4. Run the app.
5. Enter an HTTPS article URL and select **Read**.

The project uses the local ReaderKit package at `../..`.

On iOS, the app presents the reader as a full-screen cover.
On macOS, the app opens each request in a new reader window.

The demo stores theme, font, and text-size settings in `UserDefaults`.
It uses Liquid Glass controls and a green Binary Dreams tint.
