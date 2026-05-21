import AppKit
import SwiftUI

enum PaperBananaTheme {
  static let accent = Color(red: 0.64, green: 0.31, blue: 0.20)
  static let accentSoft = Color(red: 0.85, green: 0.58, blue: 0.38)
  static let ink = Color(red: 0.19, green: 0.16, blue: 0.13)
  static let sage = Color(red: 0.30, green: 0.41, blue: 0.34)
  static let sand = Color(red: 0.95, green: 0.90, blue: 0.82)
  static let paper = Color(red: 0.98, green: 0.96, blue: 0.91)
}

struct PaperWorkspaceBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      LinearGradient(
        colors: colorScheme == .dark
          ? [
            Color(red: 0.13, green: 0.12, blue: 0.11),
            Color(red: 0.18, green: 0.15, blue: 0.13),
            Color(red: 0.11, green: 0.12, blue: 0.11)
          ]
          : [
            Color(red: 0.99, green: 0.97, blue: 0.92),
            Color(red: 0.96, green: 0.91, blue: 0.84),
            Color(red: 0.93, green: 0.94, blue: 0.90)
          ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      RadialGradient(
        colors: [
          PaperBananaTheme.accentSoft.opacity(colorScheme == .dark ? 0.18 : 0.24),
          .clear
        ],
        center: .topLeading,
        startRadius: 40,
        endRadius: 520
      )

      RadialGradient(
        colors: [
          PaperBananaTheme.sage.opacity(colorScheme == .dark ? 0.14 : 0.18),
          .clear
        ],
        center: .bottomTrailing,
        startRadius: 50,
        endRadius: 560
      )
    }
  }
}

struct PaperGlassModifier: ViewModifier {
  let cornerRadius: CGFloat
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [
                Color.white.opacity(colorScheme == .dark ? 0.16 : 0.56),
                PaperBananaTheme.accent.opacity(colorScheme == .dark ? 0.18 : 0.12)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      }
      .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 18, x: 0, y: 10)
  }
}

extension View {
  func paperGlass(cornerRadius: CGFloat = 18) -> some View {
    modifier(PaperGlassModifier(cornerRadius: cornerRadius))
  }
}

struct AppIconMark: View {
  let size: CGFloat

  var body: some View {
    Group {
      if let image = NSImage(named: NSImage.applicationIconName) {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      } else if let bundled = NSImage(named: "AppIcon") {
        Image(nsImage: bundled)
          .resizable()
          .scaledToFit()
      } else {
        Image(systemName: "graduationcap.fill")
          .resizable()
          .scaledToFit()
          .padding(size * 0.22)
          .foregroundStyle(PaperBananaTheme.accent)
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    .shadow(color: .black.opacity(0.16), radius: size * 0.12, x: 0, y: size * 0.06)
  }
}
