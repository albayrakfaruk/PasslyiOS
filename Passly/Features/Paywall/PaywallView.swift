import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: PasslyProduct = .lifetime
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 780

            ZStack {
                PremiumBackground()
                VStack(spacing: compact ? 10 : 12) {
                    hero(compact: compact)
                    headline(compact: compact)
                    featureGrid(compact: compact)
                    productPicker(compact: compact)
                    purchaseButton
                    complianceLinks(compact: compact)
                }
                .padding(.horizontal, 18)
                .padding(.top, compact ? 10 : 18)
                .padding(.bottom, compact ? 8 : 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Passly", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func hero(compact: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            OnboardingVisual(type: .premiumUnlock, reduceMotion: false)
                .scaleEffect(compact ? 0.54 : 0.62)
                .frame(height: compact ? 170 : 190)
                .clipped()
            Text("Lifetime")
                .font(.caption2.weight(.heavy))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(PasslyTheme.amber)
                .foregroundStyle(.black)
                .clipShape(Capsule())
                .padding(.trailing, compact ? 58 : 48)
                .padding(.bottom, compact ? 20 : 24)
        }
    }

    private func headline(compact: Bool) -> some View {
        VStack(spacing: compact ? 5 : 7) {
            Text("Unlock Passly")
                .font((compact ? Font.title : Font.largeTitle).weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(PasslyTheme.textPrimary)
            Text("Create Apple Wallet passes from cards, tickets, PDFs, photos, NFC tags, and links.")
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(PasslyTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
        }
    }

    private func featureGrid(compact: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            PaywallFeature(title: "Wallet export", symbol: "wallet.pass", compact: compact)
            PaywallFeature(title: "Scan & import", symbol: "qrcode.viewfinder", compact: compact)
            PaywallFeature(title: "Photo & PDF", symbol: "photo", compact: compact)
            PaywallFeature(title: "Premium design", symbol: "sparkles", compact: compact)
        }
    }

    private func productPicker(compact: Bool) -> some View {
        HStack(spacing: 12) {
            PlanButton(product: .lifetime, highlighted: selectedProduct == .lifetime, compact: compact) {
                selectedProduct = .lifetime
            }
            PlanButton(product: .monthly, highlighted: selectedProduct == .monthly, compact: compact) {
                selectedProduct = .monthly
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            Task { await purchaseSelectedProduct() }
        } label: {
            Text(isPurchasing ? "Working..." : "Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [PasslyTheme.vividAccent, Color(red: 0.48, green: 0.72, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: PasslyTheme.vividAccent.opacity(0.34), radius: 18, x: 0, y: 10)
        }
        .disabled(isPurchasing)
    }

    private func complianceLinks(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 9) {
            Text("Monthly renews automatically at \(PasslyProduct.monthly.displayPrice)/month until cancelled. Lifetime is a one-time purchase. Purchases are managed by your Apple ID.")
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(PasslyTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.86)
            HStack {
                Button("Restore Purchases") {
                    Task { await restore() }
                }
                Spacer()
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy", destination: URL(string: "https://passly.app/privacy")!)
            }
            .font((compact ? Font.caption : Font.footnote).weight(.medium))
            .foregroundStyle(PasslyTheme.textSecondary)
        }
    }

    private func purchaseSelectedProduct() async {
        isPurchasing = true
        do {
            try await container.entitlementService.purchase(selectedProduct)
            if container.entitlementService.isProUnlocked {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isPurchasing = false
    }

    private func restore() async {
        isPurchasing = true
        await container.entitlementService.restorePurchases()
        if container.entitlementService.isProUnlocked {
            dismiss()
        } else {
            errorMessage = "No active Passly purchase was found for this Apple ID."
        }
        isPurchasing = false
    }
}

private struct PlanButton: View {
    let product: PasslyProduct
    var highlighted = false
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: compact ? 5 : 6) {
                if let badge = product.badge {
                    Text(badge)
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PasslyTheme.mint)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
                Text(product.title).font(compact ? .subheadline.weight(.bold) : .headline)
                Text(product.displayPrice).font((compact ? Font.title3 : Font.title2).weight(.bold))
                Text(product.detail)
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(PasslyTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(PasslyTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: compact ? 104 : 116)
            .padding(compact ? 12 : 14)
            .background(
                highlighted
                ? LinearGradient(
                    colors: [PasslyTheme.vividAccent.opacity(0.42), PasslyTheme.accent.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [.white.opacity(0.08), .white.opacity(0.055)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(highlighted ? PasslyTheme.vividAccent : PasslyTheme.border, lineWidth: highlighted ? 2 : 1))
            .shadow(color: highlighted ? PasslyTheme.vividAccent.opacity(0.22) : .clear, radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct PaywallFeature: View {
    let title: String
    let symbol: String
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            Image(systemName: symbol)
                .font(compact ? .subheadline : .headline)
                .foregroundStyle(PasslyTheme.accent)
                .frame(width: compact ? 24 : 28)
            Text(title)
                .font((compact ? Font.caption : Font.subheadline).weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
        .foregroundStyle(PasslyTheme.textPrimary)
        .padding(compact ? 9 : 11)
        .frame(minHeight: compact ? 46 : 52)
        .glassPanel()
    }
}

struct LockedFeatureView: View {
    let title: String
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            OnboardingVisual(type: .premiumUnlock, reduceMotion: true)
                .frame(height: 250)
            VStack(spacing: 8) {
                Text(title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(PasslyTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(PasslyTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: action) {
                Label("Unlock Passly", systemImage: "lock.open.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(PasslyTheme.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding()
    }
}
