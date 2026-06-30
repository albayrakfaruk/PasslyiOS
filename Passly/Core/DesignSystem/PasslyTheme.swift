import SwiftUI

enum PasslyTheme {
    static let background = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
        ? UIColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 1)
        : UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1)
    })
    static let panel = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
        ? UIColor.white.withAlphaComponent(0.08)
        : UIColor.white.withAlphaComponent(0.78)
    })
    static let border = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
        ? UIColor.white.withAlphaComponent(0.16)
        : UIColor.black.withAlphaComponent(0.10)
    })
    static let textPrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
        ? UIColor.white
        : UIColor(red: 0.08, green: 0.10, blue: 0.13, alpha: 1)
    })
    static let textSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
        ? UIColor.white.withAlphaComponent(0.68)
        : UIColor(red: 0.30, green: 0.34, blue: 0.40, alpha: 1)
    })
    static let controlFill = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
        ? UIColor.white.withAlphaComponent(0.065)
        : UIColor.white.withAlphaComponent(0.82)
    })
    static let quietFill = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
        ? UIColor.white.withAlphaComponent(0.14)
        : UIColor.black.withAlphaComponent(0.18)
    })
    static let accent = Color(red: 0.46, green: 0.65, blue: 1.0)
    static let vividAccent = Color(red: 0.22, green: 0.52, blue: 1.0)
    static let mint = Color(red: 0.42, green: 0.88, blue: 0.68)
    static let amber = Color(red: 0.98, green: 0.68, blue: 0.34)
    static let rose = Color(red: 0.96, green: 0.46, blue: 0.62)

    static func color(hex: String) -> Color {
        let clean = hex.replacingOccurrences(of: "#", with: "")
        guard let value = Int(clean, radix: 16) else { return .black }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return Color(red: red, green: green, blue: blue)
    }
}

struct PremiumBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            PasslyTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: topGlowColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: max(220, proxy.size.height * 0.34))
                    Spacer()
                    LinearGradient(
                        colors: bottomGlowColors,
                        startPoint: .top,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: max(180, proxy.size.height * 0.28))
                }
                .blur(radius: 28)
                .ignoresSafeArea()
            }
            VStack(spacing: 18) {
                ForEach(0..<6, id: \.self) { index in
                    Rectangle()
                        .fill(gridLineColor(index: index))
                        .frame(height: 1)
                }
                Spacer()
            }
            .padding(.top, 64)
            .ignoresSafeArea()
        }
    }

    private var backgroundGradient: [Color] {
        if colorScheme == .dark {
            [
                Color(red: 0.10, green: 0.12, blue: 0.16),
                Color(red: 0.05, green: 0.06, blue: 0.09),
                Color(red: 0.08, green: 0.10, blue: 0.11)
            ]
        } else {
            [
                Color(red: 0.97, green: 0.98, blue: 1.00),
                Color(red: 0.91, green: 0.94, blue: 0.98),
                Color(red: 0.94, green: 0.97, blue: 0.95)
            ]
        }
    }

    private var topGlowColors: [Color] {
        colorScheme == .dark
        ? [.white.opacity(0.14), PasslyTheme.accent.opacity(0.09), .clear]
        : [.white.opacity(0.80), PasslyTheme.accent.opacity(0.12), .clear]
    }

    private var bottomGlowColors: [Color] {
        colorScheme == .dark
        ? [.clear, PasslyTheme.mint.opacity(0.07), PasslyTheme.amber.opacity(0.05)]
        : [.clear, PasslyTheme.mint.opacity(0.12), PasslyTheme.amber.opacity(0.10)]
    }

    private func gridLineColor(index: Int) -> Color {
        colorScheme == .dark
        ? .white.opacity(index.isMultiple(of: 2) ? 0.035 : 0.018)
        : .black.opacity(index.isMultiple(of: 2) ? 0.035 : 0.018)
    }
}

struct GlassPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PasslyTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func glassPanel() -> some View {
        modifier(GlassPanelModifier())
    }
}
