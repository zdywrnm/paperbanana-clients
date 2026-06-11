import SwiftUI

struct AppBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    LinearGradient(
      colors: colorScheme == .dark ? darkColors : lightColors,
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
  }

  private var lightColors: [Color] {
    [
      Color(.systemBackground),
      Color(red: 0.95, green: 0.98, blue: 0.98),
      Color(red: 1.00, green: 0.97, blue: 0.88)
    ]
  }

  private var darkColors: [Color] {
    [
      Color(red: 0.04, green: 0.05, blue: 0.05),
      Color(red: 0.10, green: 0.15, blue: 0.14),
      Color(red: 0.15, green: 0.13, blue: 0.08)
    ]
  }
}
